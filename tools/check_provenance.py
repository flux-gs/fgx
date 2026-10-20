#!/usr/bin/env python3
"""check_provenance.py - enforce 2.11BSD attribution on derived userland code.

Run by ninja as a build check. Exits non-zero on any violation. The
authoritative registry of derived files + the required header is
docs/PROVENANCE.md.

Four checks:
  1. Every file registered in docs/PROVENANCE.md exists and carries the three
     required header markers (SPDX id, FGX-Provenance tag, UCB copyright).
  2. No *other* src/userland/**/*.c carries 2.11BSD-derivation markers without
     being registered -- catches a new port that forgot its attribution.
  3. Every `vendor/...` path a row NAMES as its upstream actually resolves.
     Checks 1 and 2 are about our side of the claim; until #141 nothing ever
     opened the other side, and a row pointed at a path that did not exist for
     as long as it took someone to look.
  4. Every `name` (upstream.c:NNN) citation is RIGHT about NNN.  Check 3 opened
     the file a row names; nothing ever opened the LINE.  On 2026-08-23 the
     tty.c row was found citing six routines at invented numbers with the gate
     green throughout, because a row existing and its file resolving say
     nothing about whether the number beside the symbol was ever read.
"""
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REGISTRY = os.path.join(ROOT, "docs", "PROVENANCE.md")

# Markers required of a UCB-derived file -- the overwhelming majority, and the
# reason this checker exists: the BSD licence requires the upstream copyright
# notice to survive redistribution.
REQUIRED_MARKERS = [
    "SPDX-License-Identifier: BSD-2-Clause",
    # The provenance TAG must be present; the specific lineage (2.11BSD,
    # NetBSD-0.9, 4.4BSD, ...) is spelled out in the header text + the
    # PROVENANCE.md registry row, so don't pin it to one BSD here.
    "FGX-Provenance:",
    "Regents of the University of California",
]

# Markers required of a THIRD-PARTY file that is not UCB-derived.  Demanding
# the UCB pair of these would be an attribution ERROR, not a formality: it
# would put the Regents' copyright on code they did not write and relicense
# someone else's work as BSD-2-Clause.  What still has to be true is that the
# file names a licence and carries a provenance tag pointing at the row that
# explains where it came from.  The row's own licence string is checked
# against the file, so a row cannot claim one licence while the file declares
# another.
THIRD_PARTY_MARKERS = ["SPDX-License-Identifier:", "FGX-Provenance:"]

# Strong derivation markers: a userland .c with any of these MUST be registered.
# (Deliberately excludes the bare word "BSD" -- FGX comments say "BSD-shaped"
# everywhere; these markers only match actual 2.11BSD provenance.)
# 4.3BSD-Reno IS UCB CODE and was missing from this list, which is how five
# Reno-derived VFS files sat unregistered: they say "Ported from 4.3BSD-Reno"
# and never say "2.11BSD" or "Regents", so nothing matched them.  A
# derivation marker list that names only ONE upstream is a list that finds
# only the ports somebody already thought about.
# An ORIGINAL file may legitimately DISCUSS an upstream -- FGX's own VFS probes
# cite Reno constantly while containing none of its code.  Registering those
# would put the Regents' copyright on code they did not write, which the
# registry's own preamble calls a worse error than the one it prevents.  So
# there is an explicit opt-out, and it is a POSITIVE claim ("I looked, this is
# ours") rather than a silent allowlist in this file, which would drift out of
# sight of the person adding the next probe.
ORIGIN_MARKER = "FGX-Origin: original"

DERIV_MARKERS = re.compile(
    r"2\.11BSD|4\.3BSD|Reno|Regents of the University|Berkeley|\bUCB\b|Bill Joy")

# The explicit opt-out for FGX-ORIGINAL code that merely CITES 2.11BSD.  Some
# files have to name the vendored callers they were written against -- a probe
# for a libc entry point, say, whose whole point is which BSD programs call it
# and how.  Naming 2.11BSD in a comment then reads as derivation and the file
# gets demanded into the registry, where a row claiming UCB copyright over
# original FGX code would be a WORSE attribution error than the one the check
# prevents.  So a file may declare itself original, in the same tag the derived
# files use.  This is deliberately a declaration, not a heuristic: it cannot be
# tripped by accident, which is the failure mode this checker exists to catch.
ORIGINAL_MARKER = "FGX-Provenance: none"


# A third-party row declares its licence in the second column, as
# `SPDX-License-Identifier: X`.  That string must also appear in the file.
THIRD_PARTY_HEADING = "## Registered third-party (non-UCB) sources"
SPDX_IN_ROW = re.compile(r"SPDX-License-Identifier:\s*([A-Za-z0-9.+-]+)")


def load_registry():
    """path -> None for a UCB row, or the row's declared SPDX id for a
    third-party row.  The section a row sits in decides which marker set the
    file must carry."""
    rows = {}
    third_party = False
    with open(REGISTRY, encoding="utf-8") as f:
        for line in f:
            # Section-aware, not a partition: a row belongs to the third-party
            # table only while that heading is the CURRENT one, so the two
            # tables can sit in either order without silently reclassifying
            # every row after the heading.
            if line.startswith("## "):
                third_party = line.strip() == THIRD_PARTY_HEADING
                continue
            # .s and .h as well as .c: a kernel port can be assembly (tty_tty.s
            # is 2.11BSD tty_tty.c) or a header (vfs/uio.h is Reno's sys/uio.h),
            # and a row for one was accepted by the registry while check 1 never
            # looked at the file -- registered but unverified, which is the one
            # state this check exists to prevent.
            #
            # `.h` was added 2026-08-22.  It had been missing since the
            # extension class was written, so every header row -- thirteen of
            # the VFS's -- was in exactly the unverified state the sentence
            # above says this check exists to prevent.  Measured: deleting the
            # SPDX line from src/kernel/vfs/uio.h left the check GREEN, while
            # the same edit to vfs_bio.c failed it.
            # A TABLE ROW, not any line that happens to backtick a path.  The
            # loader was line-based, which was harmless while the class was
            # `.c`/`.s` and became wrong the moment `.h` joined it: the prose
            # above the userland table says curses.h "is installed at
            # `toolchain/include/curses.h` (headers, not registered)", and a
            # line-based scan read that sentence as a registration.
            if not line.lstrip().startswith("|"):
                continue
            fm = re.search(r"`((?:src|toolchain)/[^`]+\.[chs])`", line)
            if not fm:
                continue
            if third_party:
                sm = SPDX_IN_ROW.search(line)
                rows[fm.group(1)] = sm.group(1) if sm else ""
            else:
                rows[fm.group(1)] = None
    return rows


# A `vendor/...` path named inside a registry ROW.  Backticked, because that is
# how every row spells one and because prose would otherwise hand us a path with
# a sentence's punctuation stuck to the end.
VENDOR_IN_ROW = re.compile(r"`(vendor/[^`]+)`")


def load_vendor_claims():
    """[(registry line number, our file, the vendor path it names)] for every
    `vendor/...` a ROW claims as its upstream.

    A row can name more than one and some name none -- the third-party table
    points at GitHub, and the `as above` rows inherit their neighbour's
    upstream.  Both are fine; this only checks the claims that ARE made.
    """
    claims = []
    with open(REGISTRY, encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            if not line.startswith("|"):
                continue
            fm = re.search(r"`((?:src|toolchain)/[^`]+\.[cs])`", line)
            ours = fm.group(1) if fm else "(row %d)" % n
            for vm in VENDOR_IN_ROW.finditer(line):
                claims.append((n, ours, vm.group(1)))
    return claims


def check_vendor_claims(root=ROOT):
    """Every vendor path a row names must RESOLVE (apple/fgx#141).

    The registry's whole purpose is to say where a derived file came from, and
    until now nothing opened the path it said.  `spec_vnops.c` pointed at
    `vendor/4.3BSD-Reno/miscfs/specfs/spec_vnops.c`, which does not exist -- the
    file is vendored under `kern/` -- and the gate was green throughout.  That
    is precisely the class the standing rule ("every VFS port needs a row naming
    its upstream file in vendor/") exists to prevent, and the rule was being
    enforced only on the half that is easy to check.

    Existence, not content: this says the claim POINTS SOMEWHERE REAL.  Whether
    the named file is actually the ancestor of ours is a different and much
    harder question -- apple/fgx#141 measured several rows whose upstream shares
    almost no text with them -- and it is deliberately not answered here.  A
    build-time gate that guessed at that would be noise; the issue records why.
    """
    errors = []
    for n, ours, vpath in load_vendor_claims():
        if not os.path.exists(os.path.join(root, vpath)):
            errors.append(
                "%s (PROVENANCE.md line %d) names an upstream that does not "
                "exist: %s" % (ours, n, vpath))
    return errors


# A row citing a SYMBOL at a LINE of its upstream: `name` (path:NNN), with the
# citation optionally backticked too.  Both spellings are in the registry.
SYMBOL_CITE = re.compile(
    r"`([A-Za-z_]\w*)`\s*\(\s*`?"
    r"([A-Za-z_][A-Za-z0-9_./-]*\.[chs]):(\d+)"
)

# Vendored trees a bare or partial citation path may be rooted at.
VENDOR_ROOTS = ("vendor/2.11BSD", "vendor/4.3BSD-Reno", "vendor/netbsd-0-9")


def load_symbol_cites():
    """[(registry line, symbol, cited path, cited line, [vendor paths in row])].

    Only the `name` (file:NNN) shape -- a claim that upstream DEFINES `name`
    there.  Rows also cite lines as evidence for a code fragment or a claim
    (`the post-pop recheck (ufs_alloc.c:163)`), which name no symbol and are
    counted but not checked; main() reports that count so the skip is visible
    rather than silent.
    """
    cites = []
    with open(REGISTRY, encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            if not line.startswith("|"):
                continue
            vendors = VENDOR_IN_ROW.findall(line)
            for m in SYMBOL_CITE.finditer(line):
                cites.append((n, m.group(1), m.group(2), int(m.group(3)), vendors))
    return cites


def _vendor_index(root=ROOT):
    """basename -> [vendored paths with that basename].  Built once; the trees
    are large and a row may cite a file no row NAMES (`tty_subr.c:418` sits on
    the tty.c row)."""
    if _vendor_index.cache is not None:
        return _vendor_index.cache
    idx = {}
    for base in VENDOR_ROOTS:
        for dirpath, _dirs, files in os.walk(os.path.join(root, base)):
            for fn in files:
                if fn.endswith((".c", ".h", ".s")):
                    rel = os.path.relpath(os.path.join(dirpath, fn), root)
                    idx.setdefault(fn, []).append(rel)
    _vendor_index.cache = idx
    return idx


_vendor_index.cache = None


def resolve_cited_path(cited, vendors, root=ROOT):
    """The vendored file a citation path names, or None.

    Citations are written the short way -- `tty.c:1480`, `ufs/dir.h:56`,
    `tty_subr.c:418` -- so resolution goes cheapest-first: the vendor paths the
    ROW already names, then the path under each vendored tree, then a basename
    lookup across the trees.

    THE BASENAME STEP PREFERS THE ROW'S OWN TREE, and that is not cosmetic:
    `tty_subr.c` exists in BOTH 2.11BSD and 4.3BSD-Reno, at different lengths,
    so resolving it to the wrong one would check a real line number against the
    wrong file and report a defect that is not there.

    A FULL `vendor/...' PATH IS TAKEN AS WRITTEN, before any of that.  A row may
    cite a same-named file from ANOTHER tree -- syslogd.c's row cites
    netbsd-0-9's syslogd.c beside its own 2.11BSD one -- and the basename match
    against the row's own path would otherwise check the line in the wrong file.
    """
    if cited.startswith("vendor/") and os.path.exists(os.path.join(root, cited)):
        return cited
    for v in vendors:
        if v.endswith("/" + cited) or v == cited:
            return v
        if os.path.basename(v) == os.path.basename(cited):
            return v
    for base in VENDOR_ROOTS:
        cand = os.path.join(base, cited)
        if os.path.exists(os.path.join(root, cand)):
            return cand
    hits = _vendor_index(root).get(os.path.basename(cited), [])
    if not hits:
        return None
    trees = {v.split("/")[1] for v in vendors if v.startswith("vendor/")}
    if trees:
        preferred = [h for h in hits if h.split("/")[1] in trees]
        if len(preferred) == 1:
            return preferred[0]
        hits = preferred or hits
    return hits[0] if len(hits) == 1 else None


def _is_definition(line, symbol):
    """A K&R top-level definition of `symbol`: column 0, name then `(` for a
    function, or a data definition naming it (`char partab[] = {`)."""
    if re.match(r"^%s\s*\(" % re.escape(symbol), line):
        return True
    return bool(re.match(r"^(?:\w[\w \t*]*?\b)?%s\s*(\[|\s*=)" % re.escape(symbol),
                         line))


def defines_at(path, symbol, lineno, root=ROOT):
    """Is the row right that `path:lineno` is where `symbol` is?
    -> (ok, what is actually there)

    TWO KINDS OF CITATION, because the registry makes two kinds of claim, and
    conflating them would either miss real errors or invent fake ones:

      DEFINITION -- `ttychars` (tty.c:111).  If the symbol is defined at column
        0 anywhere in the file, the row is claiming WHERE, and the cited line
        must be that definition.  Exact, no tolerance: the defect this exists to
        catch was a number off by 89.
      EVIDENCE -- `d_ino` (ufs/dir.h:56).  A struct field or a fragment is never
        a top-level definition, so the row is pointing at a line as evidence;
        the cited line must CONTAIN the symbol.

    Which kind it is comes from the file, not from guessing at the prose.
    """
    try:
        with open(os.path.join(root, path), encoding="utf-8", errors="replace") as f:
            lines = f.read().split("\n")
    except OSError as e:
        return False, "unreadable: %s" % e
    if not 1 <= lineno <= len(lines):
        return False, "%s has only %d lines" % (path, len(lines))
    text = lines[lineno - 1]

    defs = [i for i, l in enumerate(lines, 1) if _is_definition(l, symbol)]
    if defs:
        if lineno in defs:
            return True, text.strip()
        where = defs[0] if len(defs) == 1 else defs
        return False, "line %d is %r, but %s is defined at line %s" % (
            lineno, text.strip()[:48], symbol, where)

    word = re.compile(r"\b%s\b" % re.escape(symbol))
    if word.search(text):
        return True, text.strip()
    hits = [i for i, l in enumerate(lines, 1) if word.search(l)]
    if hits:
        return False, "line %d is %r, which does not mention %s (it appears at %s)" % (
            lineno, text.strip()[:48], symbol,
            ", ".join(str(h) for h in hits[:4]))
    return False, "line %d is %r; %s does not appear in %s at all" % (
        lineno, text.strip()[:48], symbol, path)


def check_symbol_cites(root=ROOT):
    """A row that cites `name` (upstream.c:NNN) must be RIGHT about NNN.

    Check 3 opened the file a row names.  Nothing ever opened the LINE, and on
    2026-08-23 the `tty.c` row was found citing six routines at numbers that
    were simply invented -- `ttychars` at 200 when it is at 111, `ttstart` at
    1690 when it is at 292.  Every one passed every check the gate had, because
    a row EXISTING and its file RESOLVING say nothing about whether the number
    beside the symbol was ever read.

    That matters more here than a wrong comment usually would: these citations
    are how the next increment finds the upstream it is meant to port from, and
    the standing rule is that a port reads its source rather than working from
    memory.  A citation nobody can follow quietly turns that rule off.
    """
    errors = []
    for n, sym, cited, lineno, vendors in load_symbol_cites():
        path = resolve_cited_path(cited, vendors, root)
        if path is None:
            errors.append(
                "PROVENANCE.md line %d cites `%s` (%s:%d) but %s resolves to no "
                "vendored file" % (n, sym, cited, lineno, cited))
            continue
        ok, what = defines_at(path, sym, lineno, root)
        if not ok:
            errors.append(
                "PROVENANCE.md line %d cites `%s` at %s:%d -- %s"
                % (n, sym, cited, lineno, what))
    return errors


# Ported sources whose COMMENTS cite upstream.  Listed rather than discovered:
# a ported file whose citations this stops seeing must fail loudly here rather
# than quietly dropping out of the check.  A new ported source belongs here the
# moment it cites an upstream line.  (tty_subr.c is NOT listed -- it names its
# upstream in the FGX-Provenance header and cites no line numbers, so there is
# nothing here for this check to open.)
SOURCE_CITE_FILES = [
    "src/kernel/tty/tty.c",
    # Added with the permission model (apple/fgx#416): ufs_chmod1/ufs_chown1
    # are Reno's two functions and their headers cite the lines a porter is
    # sent to read.  The first run of this file through the check caught the
    # citation for chmod1 off by one -- 465 for a line that holds `*/' -- in
    # both the registry row and the source, which is the pair this check
    # exists to keep honest.
    "src/kernel/vfs/ufs_vnops.c",
]

# `/* ttwakeup -- the input side became interesting; ...' -- a block opener
# names the routine the block is about.
BLOCK_OPEN = re.compile(r"^/\*\s+([A-Za-z_]\w*)\s+--")
BARE_CITE = re.compile(r"([A-Za-z_][A-Za-z0-9_./-]*\.[chs]):(\d+)(?!\s*[-\d])")
# `the two-argument nextc (tty_subr.c:407)' -- the same claim SYMBOL_CITE reads
# in the registry, without the backticks.
INLINE_CITE = re.compile(
    r"\b([A-Za-z_]\w*)\s*\(\s*`?([A-Za-z_][A-Za-z0-9_./-]*\.[chs]):(\d+)")
TREE_HINT = re.compile(r"\b(2\.11BSD|4\.3BSD-Reno|netbsd-0-9)\b")
# `2.11BSD usr/sys/sys/tty.c:1683' and the FGX-Provenance header both name the
# tree AND the path.  TAKING THE WHOLE PATH IS NOT TIDINESS: vendor/2.11BSD has
# TWO `tty.c' (usr/sys/sys and usr/usr.bin), so a tree-only hint leaves the
# basename lookup ambiguous, and resolving to the wrong one would check a right
# number against the wrong file and report a defect that is not there.
PROV_PATH = re.compile(
    r"\b(2\.11BSD|4\.3BSD-Reno|netbsd-0-9)[ \t]+([A-Za-z0-9_./-]+\.[chs])")


def path_hints(s):
    """The vendored paths a comment line (or a whole file) names."""
    return ["vendor/%s/%s" % (t, p) for t, p in PROV_PATH.findall(s)]


def source_cites(text):
    """[(line, symbol, path, cited line, hints, kind)], unchecked count.

    TWO CLAIM SHAPES ARE CHECKABLE, and they are told apart the way the source
    actually writes them rather than by guessing at prose:

      HEADER -- `* 2.11BSD usr/sys/sys/tty.c:1683.' at the top of a block whose
        opener named a routine.  NAMING THE TREE IS WHAT MAKES IT A HEADER: an
        evidence line inside the same block cites bare (`ttread at tty.c:1273'),
        so without that test the block's own symbol would be checked against a
        line belonging to a different routine entirely.
      INLINE -- `two-argument nextc (tty_subr.c:407)'.  Checked only when the
        symbol really is defined at column 0 in the cited file; `an UNMASKED
        character (tty.c:1398)' has the same SHAPE and is English prose, so the
        file decides, not the punctuation.

    Everything else -- a range (`tty.c:39-41'), a bare evidence line, a cite in
    a block that opened with no name -- is COUNTED and reported, never skipped
    in silence: a checker that quietly verifies nothing reads exactly like one
    that verified everything.
    """
    cites, unchecked = [], 0
    sym = None
    for n, line in enumerate(text.split("\n"), 1):
        m = BLOCK_OPEN.match(line)
        if m:
            sym = m.group(1)
        elif not line.lstrip().startswith(("*", "/*")):
            sym = None                          # the comment block ended
        hint = path_hints(line)
        named_tree = bool(TREE_HINT.search(line))
        claimed = set()
        for im in INLINE_CITE.finditer(line):
            cites.append((n, im.group(1), im.group(2), int(im.group(3)),
                          hint, "inline"))
            claimed.add((im.group(2), im.group(3)))
        for bm in BARE_CITE.finditer(line):
            if (bm.group(1), bm.group(2)) in claimed:
                continue
            if sym and named_tree:
                cites.append((n, sym, bm.group(1), int(bm.group(2)),
                              hint, "header"))
            else:
                unchecked += 1
    return cites, unchecked


def defined_anywhere(path, symbol, root=ROOT):
    """Is `symbol` defined at column 0 in this file?  The discriminator that
    keeps an English word before a parenthesised citation from being read as a
    claim about a routine."""
    try:
        with open(os.path.join(root, path), encoding="utf-8", errors="replace") as f:
            return any(_is_definition(l, symbol) for l in f)
    except OSError:
        return False


def check_source_cites(root=ROOT):
    """A PORTED SOURCE that cites upstream in a comment must be right too.

    Check 4 opens every citation in the registry.  NOTHING OPENED THE ONES IN
    THE CODE, and on 2026-08-24 the gap was visible in the tree: the same two
    invented numbers check 4 had just caught in PROVENANCE.md were still sitting
    in `tty.c`'s own comments -- `ttwakeup` at 1746 when it is at 1683, and
    `ttyowake` at 1771 when it is at 123 -- because fixing the registry row had
    never touched the source.  A third, `nextc` at `tty_subr.c:418`, cited OUR
    line rather than upstream's 407.

    These are the citations a porter actually reads.  They sit at the head of
    the routine being extended, which is exactly where the standing rule sends
    the next increment to check its source, so a number nobody can follow turns
    that rule off just as quietly here as in the registry -- and for longer,
    because the registry row had a checker and these did not.
    """
    errors, n_ok, n_unchecked = [], 0, 0
    for rel in SOURCE_CITE_FILES:
        path = os.path.join(root, rel)
        if not os.path.exists(path):
            errors.append("listed ported source is missing: %s" % rel)
            continue
        text = open(path, encoding="utf-8", errors="replace").read()
        cites, unchecked = source_cites(text)
        n_unchecked += unchecked
        if not cites:
            errors.append(
                "%s: no checkable upstream citation found -- the scan has "
                "drifted from the source, not the source from upstream" % rel)
        # the file's own trees, for a citation whose line does not name one
        file_hint = path_hints(text)
        for n, sym, cited, lineno, hint, kind in cites:
            up = resolve_cited_path(cited, hint or file_hint, root)
            if up is None:
                errors.append("%s line %d cites `%s` (%s:%d) but %s resolves to "
                              "no vendored file" % (rel, n, sym, cited, lineno, cited))
                continue
            if kind == "inline" and not defined_anywhere(up, sym, root):
                n_unchecked += 1          # prose, not a claim about a routine
                continue
            ok, what = defines_at(up, sym, lineno, root)
            if not ok:
                errors.append("%s line %d cites `%s` at %s:%d -- %s"
                              % (rel, n, sym, cited, lineno, what))
            else:
                n_ok += 1
    check_source_cites.counts = (n_ok, n_unchecked)
    return errors


check_source_cites.counts = (0, 0)


def check_file_markers(text, spdx, rel, upstream=None):
    """Findings for one registered file.  Pure, so --self-test can drive it.

    `spdx` is None for a UCB row (the REQUIRED_MARKERS set) or the row's
    declared SPDX id for a third-party row.  `upstream` is the text of each
    vendored file the row names: a third-party file may carry the Regents'
    notice only if one of them does."""
    out = []
    if spdx is None:
        for marker in REQUIRED_MARKERS:
            if marker not in text:
                out.append("%s: missing required header marker: '%s'"
                           % (rel, marker))
        return out
    if not spdx:
        return ["%s: third-party row declares no 'SPDX-License-Identifier: "
                "<id>' -- the row is what says which licence the file is "
                "under" % rel]
    for marker in THIRD_PARTY_MARKERS:
        if marker not in text:
            out.append("%s: missing required header marker: '%s'"
                       % (rel, marker))
    if ("SPDX-License-Identifier: " + spdx) not in text:
        out.append("%s: registry row says '%s' but the file's SPDX id does "
                   "not match -- one of the two is wrong, and a licence the "
                   "registry only ASSERTS is worthless" % (rel, spdx))
    regents = REQUIRED_MARKERS[-1]
    if regents in text and not any(regents in u for u in (upstream or [])):
        out.append("%s: claims the Regents' copyright, which no vendored "
                   "upstream it names carries -- an invented notice" % rel)
    return out


# Directories whose C is PORTED and must therefore be registered.  src/userland
# was the only one for a long time, and that was a real hole: the UFS campaign
# ports 4.3BSD-Reno KERNEL source into src/kernel/vfs -- vfs_lookup.c,
# vfs_cache.c, vfs_subr.c, spec_vnops.c, dead_vnops.c -- and not one of them was
# registered here, because nothing looked there.  Those files carry the Regents'
# copyright exactly as a userland port does.
#
# THIS IS ALSO THE THING THAT KEEPS THE PORT HONEST.  Registering a row means
# naming the upstream file it came from, and you cannot name a file you have not
# opened.  Two ports in this campaign were written from MEMORY while the real
# source sat in the tree unnoticed (see vendor/README.md); a build that refuses
# an unregistered port makes that mistake fail loudly instead of quietly
# diverging from the source the campaign is defined against.
PORTED_DIRS = ("src/userland", "src/kernel/vfs")


def scan_userland_c():
    """Every TRACKED .c under the ported directories.

    Deliberately not a raw file walk.  yacc-sourced tools (expr) generate
    <name>.c from the tracked <name>.y; build.sh deleted the .c immediately, so
    this checker never saw one, but a build graph must keep its outputs -- and
    the generated parser then looked like an unregistered 2.11BSD-derived file.
    Provenance belongs to the .y, which docs/PROVENANCE.md registers directly.

    Asking git also means a build product can never be mistaken for a source.
    """
    r = subprocess.run(["git", "ls-files"] + list(PORTED_DIRS),
                       cwd=ROOT, capture_output=True, text=True)
    if r.returncode != 0:
        # No git (a source tarball): fall back to the walk, minus anything the
        # graph is known to generate.
        files = []
        for d in PORTED_DIRS:
            base = os.path.join(ROOT, *d.split("/"))
            for dirpath, _dirs, names in os.walk(base):
                for n in names:
                    if n.endswith(".c") and not os.path.exists(
                            os.path.join(dirpath, n[:-2] + ".y")):
                        files.append(os.path.relpath(
                            os.path.join(dirpath, n), ROOT))
        return files
    return [p for p in r.stdout.splitlines() if p.endswith(".c")]


def _selftest():
    """Prove both directions of the gate before trusting its silence.

    This checker passes by finding nothing, so a marker list that stopped
    matching, a registry parser that returned an empty set, or a file walk that
    found no files would all report "clean".  Exercise the two predicates it is
    built from against known inputs.
    """
    fails = 0

    # (0) The copyright predicate, both directions.  apple/fgx#164 is what a
    #     silent one costs: sixteen headers reproduced a notice no vendored
    #     file carries, and the block they sat in exists to reproduce it
    #     verbatim.  A checker that passes by finding nothing has to be shown
    #     finding something.
    _up = ["Copyright (c) 1989 The Regents of the University of California",
           "Copyright (c) 1986 Regents of the University of California"]
    _hdr = (" * Copyright (c) 1989 The Regents of the University of "
            "California.\n *   All rights reserved.\n")
    if _ucb_lines(_hdr, 24) != [_up[0]]:
        print("  SELFTEST FAIL: _ucb_lines did not extract the notice verbatim")
        fails += 1
    if _ucb_lines(_hdr, 24)[0] not in _up:
        print("  SELFTEST FAIL: a notice the upstream carries was called wrong")
        fails += 1
    # the #164 line itself: 4.4BSD-Lite years on a Reno-derived file
    _bad = _ucb_lines(" * Copyright (c) 1989, 1993 The Regents of the "
                      "University of California.\n", 24)
    if not _bad or _bad[0] in _up:
        print("  SELFTEST FAIL: the 4.4BSD-Lite line was not called wrong")
        fails += 1
    # wording, not just years -- `Regents' against `The Regents'
    _word = _ucb_lines(" * Copyright (c) 1989 Regents of the University of "
                       "California.\n", 24)
    if not _word or _word[0] in _up:
        print("  SELFTEST FAIL: a dropped `The' was not called wrong")
        fails += 1
    # a file with TWO real upstreams carries two notices and both are accepted
    _two = _ucb_lines(" * Copyright (c) 1989 The Regents of the University of "
                      "California.\n * Copyright (c) 1986 Regents of the "
                      "University of California.\n", 24)
    if len(_two) != 2 or any(c not in _up for c in _two):
        print("  SELFTEST FAIL: a two-upstream header was not accepted whole")
        fails += 1

    # (1) A registered file must carry EVERY required header marker.
    good_hdr = ("/* SPDX-License-Identifier: BSD-2-Clause\n"
                " * FGX-Provenance: 2.11BSD usr/bin/cat\n"
                " * Copyright (c) 1980 Regents of the University of California\n */")
    for marker in REQUIRED_MARKERS:
        if marker not in good_hdr:
            print(f"  SELFTEST FAIL: complete header lacks required marker {marker!r}")
            fails += 1
    for drop in REQUIRED_MARKERS:
        partial = good_hdr.replace(drop, "")
        if all(m in partial for m in REQUIRED_MARKERS):
            print(f"  SELFTEST FAIL: header missing {drop!r} still read as complete")
            fails += 1

    # (2) Derivation markers must fire on real provenance and NOT on the
    #     "BSD-shaped" prose that appears all over FGX comments.
    should_hit = ["ported from 2.11BSD", "Regents of the University of California",
                  "Ported from 4.3BSD-Reno kern/vfs_lookup.c",
                  "Berkeley Software Distribution", "UCB notice retained",
                  "originally by Bill Joy"]
    should_miss = ["a BSD-shaped syscall layer", "BSD sockets", "bsd-ish semantics",
                   "FGX is BSD-flavoured"]
    for t in should_hit:
        if not DERIV_MARKERS.search(t):
            print(f"  SELFTEST FAIL: derivation marker missed {t!r}")
            fails += 1
    for t in should_miss:
        if DERIV_MARKERS.search(t):
            print(f"  SELFTEST FAIL: derivation marker false-positive on {t!r}")
            fails += 1

    # (2b) The original-code opt-out must suppress a derivation hit, and ONLY
    #      when it is actually present -- a marker that never matches would
    #      make the escape hatch silently useless, and one that always matches
    #      would disable the whole check.
    cites = "/* a probe for setpgrp, which 2.11BSD's csh calls as setpgrp(0, n) */"
    if not DERIV_MARKERS.search(cites):
        print("  SELFTEST FAIL: citing text no longer trips the derivation markers, "
              "so the opt-out is testing nothing")
        fails += 1
    if ORIGINAL_MARKER in cites:
        print("  SELFTEST FAIL: opt-out marker matched a file that does not declare it")
        fails += 1
    if ORIGINAL_MARKER not in ("/* " + ORIGINAL_MARKER + " */\n" + cites):
        print("  SELFTEST FAIL: opt-out marker missed a file that DOES declare it")
        fails += 1

    # (2c) The third-party arm.  It exists so a non-UCB port is not forced to
    #      claim the Regents' copyright, which would be a WORSE attribution
    #      error than the one this checker prevents -- so it has to be exactly
    #      as strict, just about different facts.
    tp_ok = ("/* SPDX-License-Identifier: GPL-2.0-or-later\n"
             " * FGX-Provenance: frotz */\n")
    tp_cases = [
        (tp_ok, "GPL-2.0-or-later", 0, "matching row and header"),
        (tp_ok, "BSD-2-Clause", 1, "row claims a licence the file does not"),
        (tp_ok, "", 1, "row declares no licence at all"),
        ("/* FGX-Provenance: frotz */\n", "GPL-2.0-or-later", 2,
         "file carries no SPDX id"),
        (tp_ok, None, 2, "a UCB row still demands the UCB markers"),
    ]
    # A third-party file may carry the Regents' notice only if its vendored
    # upstream does: elvis's four ports once claimed it to satisfy the UCB
    # arm's lint, and elvis is Steve Kirkendall's, not Berkeley's.
    _claim = tp_ok + " * Copyright (c) 1980 The Regents of the University of California\n"
    for upstream, want, why in (
            (["/* Author: Steve Kirkendall */"], 1, "Regents claimed, upstream has none"),
            ([], 1, "Regents claimed, no vendored upstream"),
            (["Copyright (c) 1980 The Regents of the University of California"], 0,
             "Regents claimed, upstream carries it")):
        got = len(check_file_markers(_claim, "GPL-2.0-or-later", "t.c", upstream))
        if got != want:
            print(f"  SELFTEST FAIL (third-party: {why}): {got} findings, want {want}")
            fails += 1
    for text, spdx, want, why in tp_cases:
        got = len(check_file_markers(text, spdx, "t.c"))
        if got != want:
            print(f"  SELFTEST FAIL (third-party: {why}): {got} findings, "
                  f"want {want}")
            fails += 1

    # (3) The registry parser must actually find rows -- an empty set would
    #     make every registered file "unregistered" or vice versa.
    try:
        reg = load_registry()
    except Exception as e:
        print(f"  SELFTEST FAIL: registry unreadable: {e}")
        return 1
    if not reg:
        print("  SELFTEST FAIL: registry parsed to ZERO rows -- the gate would be vacuous")
        fails += 1
    if not any(v is not None for v in reg.values()):
        print("  SELFTEST FAIL: no third-party rows in the registry, so the "
              "non-UCB arm above is dead code -- delete it or use it")
        fails += 1

    # (3) The vendor-path check, both ways.  A check that cannot fail is the
    #     defect it exists to prevent, and this one is especially easy to write
    #     that way: point it at a tree with no vendor/ at all and it finds
    #     nothing to complain about because it found nothing at all.  So drive
    #     it against a fixture where one claim resolves and one does not, and
    #     require it to see exactly the broken one.
    import tempfile
    tmp = tempfile.mkdtemp()
    try:
        os.makedirs(os.path.join(tmp, "vendor", "2.11BSD", "usr", "bin"))
        with open(os.path.join(tmp, "vendor", "2.11BSD", "usr", "bin", "cat.c"), "w") as f:
            f.write("/* upstream */\n")
        reg_lines = [
            "| File | Upstream | Notes |\n",
            "|---|---|---|\n",
            "| `src/userland/cat/cat.c` | `vendor/2.11BSD/usr/bin/cat.c` | real |\n",
            "| `src/userland/ls/ls.c` | `vendor/2.11BSD/usr/bin/nope.c` | missing |\n",
            "| `src/userland/yes/yes.c` | not a vendor path at all | fine |\n",
        ]
        saved = globals()["REGISTRY"]
        rp = os.path.join(tmp, "PROVENANCE.md")
        with open(rp, "w") as f:
            f.writelines(reg_lines)
        globals()["REGISTRY"] = rp
        got = check_vendor_claims(tmp)
        globals()["REGISTRY"] = saved
        if len(got) != 1:
            print(f"  SELFTEST FAIL: vendor-path check reported {len(got)} "
                  f"problem(s), expected exactly 1")
            fails += 1
        elif "nope.c" not in got[0]:
            print(f"  SELFTEST FAIL: vendor-path check named the wrong row: {got[0]}")
            fails += 1
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # (4) The line-number check must go RED on a wrong number and GREEN on the
    #     right one.  This checker passes by finding nothing, so the only thing
    #     that makes its silence worth anything is a known-bad input it calls
    #     bad -- and check 4 exists precisely because six citations were wrong
    #     for weeks while every check the gate had stayed green.
    tmp2 = tempfile.mkdtemp(prefix="provcite-")
    try:
        src = ("/* a comment mentioning widget */\n"   # 1
               "#include <stdio.h>\n"                  # 2
               "\n"                                    # 3
               "char partab[] = { 1, 2 };\n"           # 4
               "\n"                                    # 5
               "struct thing {\n"                      # 6
               "\tint\tfield_x;\n"                   # 7
               "};\n"                                  # 8
               "\n"                                    # 9
               "widget(a, b)\n"                        # 10
               "\tint a;\n"                           # 11
               "{\n"                                   # 12
               "\treturn a;\n"                        # 13
               "}\n")                                  # 14
        vdir = os.path.join(tmp2, "vendor", "2.11BSD", "usr", "sys", "sys")
        os.makedirs(vdir)
        with open(os.path.join(vdir, "demo.c"), "w") as f:
            f.write(src)
        rel = "vendor/2.11BSD/usr/sys/sys/demo.c"

        # a DEFINITION citation: right line green, every wrong line red, and the
        # complaint has to name the REAL line or it is not actionable
        if not defines_at(rel, "widget", 10, tmp2)[0]:
            print("  SELFTEST FAIL: correct definition citation reported wrong")
            fails += 1
        for bad in (9, 11, 1):
            ok, why = defines_at(rel, "widget", bad, tmp2)
            if ok:
                print(f"  SELFTEST FAIL: widget cited at line {bad} passed")
                fails += 1
            elif "10" not in why:
                print(f"  SELFTEST FAIL: wrong citation did not name the real "
                      f"line: {why}")
                fails += 1
        if not defines_at(rel, "partab", 4, tmp2)[0]:
            print("  SELFTEST FAIL: data definition `partab` at 4 reported wrong")
            fails += 1

        # an EVIDENCE citation -- a struct field is never a top-level
        # definition, so the cited line must merely CONTAIN it
        if not defines_at(rel, "field_x", 7, tmp2)[0]:
            print("  SELFTEST FAIL: evidence citation `field_x` at 7 reported wrong")
            fails += 1
        if defines_at(rel, "field_x", 6, tmp2)[0]:
            print("  SELFTEST FAIL: evidence citation off by one passed")
            fails += 1
        if defines_at(rel, "nosuch", 4, tmp2)[0]:
            print("  SELFTEST FAIL: citation of an absent symbol passed")
            fails += 1

        # the CITATION regex: both spellings match, a bare line cite does not
        pos = ("| `x.c` | `%s` | ported `widget` (demo.c:10) and "
               "`partab` (`demo.c:4`) |" % rel)
        got = [(m.group(1), int(m.group(3))) for m in SYMBOL_CITE.finditer(pos)]
        if got != [("widget", 10), ("partab", 4)]:
            print(f"  SELFTEST FAIL: citation regex read {got}")
            fails += 1
        if SYMBOL_CITE.search("| the post-pop recheck (`demo.c:163`) names none |"):
            print("  SELFTEST FAIL: a bare line citation was read as a symbol claim")
            fails += 1

        # end to end, through the registry loader
        saved = globals()["REGISTRY"]
        rp2 = os.path.join(tmp2, "PROVENANCE.md")
        globals()["REGISTRY"] = rp2
        with open(rp2, "w") as f:
            f.write(pos.replace("(demo.c:10)", "(demo.c:11)") + "\n")
        red = check_symbol_cites(tmp2)
        with open(rp2, "w") as f:
            f.write(pos + "\n")
        green = check_symbol_cites(tmp2)
        globals()["REGISTRY"] = saved
        if len(red) != 1:
            print(f"  SELFTEST FAIL: a wrong line number produced {len(red)} "
                  f"finding(s), expected 1")
            fails += 1
        if green:
            print(f"  SELFTEST FAIL: correct citations produced {green}")
            fails += 1
    finally:
        shutil.rmtree(tmp2, ignore_errors=True)

    # --- check 5: citations in a ported source's own comments ---------------
    tmp3 = tempfile.mkdtemp(prefix="prov5-")
    try:
        up = os.path.join(tmp3, "vendor", "2.11BSD", "usr", "sys", "sys")
        os.makedirs(up)
        # a SECOND tty.c in the same tree, as 2.11BSD really has -- the
        # basename lookup must not be what resolves the citation
        os.makedirs(os.path.join(tmp3, "vendor", "2.11BSD", "usr", "usr.bin"))
        open(os.path.join(tmp3, "vendor", "2.11BSD", "usr", "usr.bin",
                          "demo.c"), "w").write("int decoy;\n")
        open(os.path.join(up, "demo.c"), "w").write(
            "line1\nline2\nttwakeup(tp)\n{\n}\n")
        src = os.path.join(tmp3, "src")
        os.makedirs(src)
        rel5 = "src/demo.c"

        def write(cite, extra=""):
            open(os.path.join(tmp3, rel5), "w").write(
                "/* FGX-Provenance: 2.11BSD usr/sys/sys/demo.c */\n"
                "/* ttwakeup -- the wake.\n"
                " * 2.11BSD usr/sys/sys/demo.c:%s.  Prose.\n"
                " %s*/\nttwakeup(tp)\n{\n}\n" % (cite, extra))

        saved5 = globals()["SOURCE_CITE_FILES"]
        globals()["SOURCE_CITE_FILES"] = [rel5]
        write("3")
        if check_source_cites(tmp3):
            print("  SELFTEST FAIL: a RIGHT header citation was reported wrong")
            fails += 1
        n_ok5 = check_source_cites.counts[0]
        if n_ok5 != 1:
            print(f"  SELFTEST FAIL: a right citation counted {n_ok5}, expected 1")
            fails += 1
        for wrong in ("2", "4", "99"):
            write(wrong)
            if len(check_source_cites(tmp3)) != 1:
                print(f"  SELFTEST FAIL: header citation :{wrong} was accepted")
                fails += 1
        # an EVIDENCE line inside the same block cites bare and must NOT be
        # read as a claim about the block's routine -- this is the false
        # positive that made the first cut of the check unusable
        write("3", extra="* and see the other arm (demo.c:1) for why\n ")
        if check_source_cites(tmp3):
            print("  SELFTEST FAIL: a bare evidence line was read as a "
                  "definition claim")
            fails += 1
        # English prose before a parenthesised citation is not a symbol claim
        write("3", extra="* an UNMASKED character (demo.c:1) indexes it\n ")
        if check_source_cites(tmp3):
            print("  SELFTEST FAIL: prose before a citation was read as a claim")
            fails += 1
        # a file that has lost its citations entirely must say so
        open(os.path.join(tmp3, rel5), "w").write("/* nothing */\n")
        if len(check_source_cites(tmp3)) != 1:
            print("  SELFTEST FAIL: a source with no citation passed silently")
            fails += 1
        globals()["SOURCE_CITE_FILES"] = saved5
    finally:
        shutil.rmtree(tmp3, ignore_errors=True)

    # --- check 6: a full vendor path beats the row's same-named upstream -----
    tmp6 = tempfile.mkdtemp(prefix="prov6-")
    try:
        for tree in ("2.11BSD", "netbsd-0-9"):
            d = os.path.join(tmp6, "vendor", tree, "x")
            os.makedirs(d)
            open(os.path.join(d, "demo.c"), "w").write("int %s;\n" % tree[0])
        own = "vendor/2.11BSD/x/demo.c"
        other = "vendor/netbsd-0-9/x/demo.c"
        got = resolve_cited_path(other, [own], tmp6)
        if got != other:
            print(f"  SELFTEST FAIL: {other} resolved to {got}")
            fails += 1
        got = resolve_cited_path("demo.c", [own], tmp6)
        if got != own:
            print(f"  SELFTEST FAIL: a short citation resolved to {got}, "
                  f"not the row's own {own}")
            fails += 1
    finally:
        shutil.rmtree(tmp6, ignore_errors=True)

    if fails:
        print(f"check_provenance self-test: {fails} FAILURE(S)")
        return 1
    print(f"check_provenance self-test: OK "
          f"({len(REQUIRED_MARKERS)} markers, {len(should_hit)}+{len(should_miss)} "
          f"derivation cases, {len(reg)} registry rows, "
          f"line citations red on 3 wrong numbers + 1 wrong evidence line and "
          f"green on 3 right ones; source-comment citations red on 3 wrong "
          f"header numbers and on a stripped file, green on the right one and "
          f"on both evidence shapes)")
    return 0


# A Regents copyright line, wherever it appears in a header.
UCB_COPYRIGHT = re.compile(
    r"Copyright \(c\)[^\n]*Regents of the University of California", re.I)


def _ucb_lines(text, limit):
    """Every Regents copyright line in the first `limit` lines, normalised."""
    head = "".join(text.splitlines(True)[:limit])
    return [" ".join(m.group(0).split()).rstrip(".")
            for m in UCB_COPYRIGHT.finditer(head)]


def check_copyright_claims(root=ROOT):
    """A reproduced copyright notice must be one the vendored file actually
    carries.  apple/fgx#164.

    THE HEADER BLOCK'S WHOLE PURPOSE IS REPRODUCING THE UPSTREAM NOTICE, and
    sixteen of them reproduced one nobody wrote: thirteen claimed the
    4.4BSD-Lite line ("1989, 1993 The Regents") for files vendored from
    4.3BSD-Reno and 2.11BSD, which say 1982/1986/1989 and no 1993 at all.  The
    rest differed in wording -- "Regents" against "The Regents", `1983,1986'
    against `1983, 1986' -- which is the same defect at a smaller scale, since
    a notice is reproduced verbatim or it is not reproduced.

    docs/PROVENANCE.md's preamble frames the mirror image as the serious error:
    registering FGX-original work would "assert the Regents' copyright over
    work the Regents did not write".  This asserts their claim with YEARS THEY
    DID NOT ASSERT IT IN, in the one place that looks most like it was checked.

    THE RULE IS "NO INVENTED NOTICE", NOT "ALL NOTICES PRESENT".  Every Regents
    line in our header must match some vendored file the row names; a row may
    also name a file consulted for behaviour rather than ported from, and
    demanding a notice for each would turn advisory reading into an attribution
    claim.  A file with two real upstreams carries two notices and passes --
    ufs_vfsops.c does, Reno's ufs_mount beside 2.11BSD's statfs1.

    It compares against the path the ROW names rather than the one the source
    header names, because check_vendor_claims has already proved the row's path
    resolves -- and three source headers name something that does not: a man
    page (`2.11BSD telnetd(8)') or upstream's real location where the vendor
    tree flattened it (`4.3BSD-Reno miscfs/specfs/spec_vnops.c', apple/fgx#141
    at the other end).
    """
    errors = []
    by_row = {}
    for n, ours, vpath in load_vendor_claims():
        by_row.setdefault(ours, (n, []))[1].append(vpath)

    for ours, (n, vpaths) in sorted(by_row.items()):
        op = os.path.join(root, ours)
        if not os.path.exists(op):
            continue
        with open(op, errors="replace") as f:
            claims = _ucb_lines(f.read(), 24)
        if not claims:
            continue
        upstream = []
        for v in vpaths:
            vp = os.path.join(root, v)
            if not os.path.exists(vp):
                continue
            with open(vp, errors="replace") as f:
                upstream += _ucb_lines(f.read(), 14)
        if not upstream:
            continue
        for c in claims:
            if c not in upstream:
                errors.append(
                    "%s: reproduces a copyright line no named upstream carries\n"
                    "      claims:   %s\n"
                    "      upstream: %s"
                    % (ours, c, "\n                ".join(upstream)))
    return errors


def main():
    if "--self-test" in sys.argv:
        return _selftest()

    if not os.path.exists(REGISTRY):
        sys.stderr.write("PROVENANCE CHECK FAILED: docs/PROVENANCE.md not found\n")
        return 1

    registry = load_registry()
    errors = []
    upstream = {}
    for _n, ours, vpath in load_vendor_claims():
        vp = os.path.join(ROOT, vpath)
        if os.path.isfile(vp):
            upstream.setdefault(ours, []).append(
                open(vp, encoding="utf-8", errors="replace").read())

    # 1. every registered file exists + has all required markers
    for rel in sorted(registry):
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            errors.append("registered file missing on disk: %s" % rel)
            continue
        text = open(path, encoding="utf-8", errors="replace").read()
        errors += check_file_markers(text, registry[rel], rel, upstream.get(rel))

    # 2. no unregistered userland .c carries derivation markers
    for rel in sorted(scan_userland_c()):
        text = open(os.path.join(ROOT, rel), encoding="utf-8", errors="replace").read()
        if ORIGINAL_MARKER in text:
            continue
        if DERIV_MARKERS.search(text) and ORIGIN_MARKER not in text and rel not in registry:
            errors.append(
                "%s: looks 2.11BSD-derived (matched provenance markers) but is NOT "
                "registered in docs/PROVENANCE.md" % rel
            )

    # 3. every vendor/... path a row names actually resolves
    errors += check_vendor_claims()
    errors += check_copyright_claims()

    # 4. every `name` (upstream.c:NNN) citation is right about NNN
    errors += check_symbol_cites()

    # 5. and every citation in a PORTED SOURCE's own comments
    errors += check_source_cites()

    if errors:
        sys.stderr.write("PROVENANCE CHECK FAILED:\n")
        for e in errors:
            sys.stderr.write("  - %s\n" % e)
        sys.stderr.write("Fix: add the SPDX/FGX-Provenance header + a registry row "
                         "(see docs/PROVENANCE.md); a row's `vendor/...` path must "
                         "name a file that is actually vendored, and a `name` "
                         "(upstream.c:NNN) citation must name the line that file "
                         "really has it on -- open it rather than adjusting the "
                         "number until this passes.\n")
        return 1

    n_tp = sum(1 for v in registry.values() if v is not None)
    n_sym = len(load_symbol_cites())
    n_line = len(re.findall(r"[A-Za-z_][A-Za-z0-9_./-]*\.[chs]:\d+",
                            open(REGISTRY, encoding="utf-8").read()))
    print("provenance OK: %d registered derived file(s) attributed (%d UCB, "
          "%d third-party); no unregistered ports; %d of %d upstream line "
          "citations name a symbol and were opened and verified (%d cite a line "
          "as evidence, naming no symbol -- unchecked).  In ported sources: "
          "%d comment citation(s) opened and verified, %d unchecked."
          % (len(registry), len(registry) - n_tp, n_tp,
             n_sym, n_line, n_line - n_sym,
             check_source_cites.counts[0], check_source_cites.counts[1]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
