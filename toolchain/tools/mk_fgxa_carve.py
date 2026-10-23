#!/usr/bin/env python3
"""mk_fgxa_carve.py - build a .fgxa archive index for an umbrella library
whose members are NOT standalone-compilable (libc-breakup task 2).

tools/mk_fgxa.sh compiles each member .c as its OWN TU to get the .s that
`fgx_ar index` scans.  That works for curses/termlib, whose members are
self-contained.  It does NOT work for lib/libc_c: 7 of the 42 members fail
to compile alone, because the one-TU aggregation is load-bearing --

    string.c, strerror.c  need __asm_p0/__asm_w0  (syscall_misc.c)
    env.c                 needs args_env          (proc.c)
    stat.c, system.c      need _libc_lstrBufA/B   (popen.c)
    sigmask.c             needs _sig_disp         (signal.c)
    fltpr.c               needs __lc_pfc          (doprnt.c, a static)

...and forcing them to compile alone would mean editing the members, which
is exactly the coupling the umbrella exists to carry.

So instead of compiling members standalone, CARVE them out of the real
aggregate compile: compile the umbrella with members [0..i] included, i
times, and take what each step added.  fcc --pile emits routines in source
order, so the code segment grows by pure append; the data segment has two
regions (globals, then the string pool) and grows by insertion into both,
so it is carved by line diff.  Both are asserted, not assumed.

The carved .s/.data.s are an INDEXING artifact only -- `fgx_ar select`
scans them for symbols and then compiles the FILTERED AGGREGATE as one TU.
Nothing ever assembles a carved fragment on its own.

Usage:
  mk_fgxa_carve.py --lib libc --out lib/libc.fgxa \
      --cc "./fcc --pile -Ilib/libc_c" --aggregate lib/libc_c/libc_c.c
"""

import argparse
import difflib
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INCLUDE_MEMBER_RE = re.compile(r'#\s*include\s+"([A-Za-z0-9_]+)\.c"')


def die(msg):
    sys.stderr.write("mk_fgxa_carve: %s\n" % msg)
    sys.exit(2)


def compile_prefix(cc, agg_lines, keep, workdir, agg_base, stem):
    """Compile the umbrella with only `keep` members included.  The temp copy
    keeps the aggregate's BASENAME: fcc derives its file-scope label prefix
    (_libc_c_*) from the stem, so a renamed copy would rename every static and
    break the carve."""
    src = os.path.join(workdir, agg_base)
    with open(src, "w") as f:
        f.writelines(l for l in agg_lines
                     if not (INCLUDE_MEMBER_RE.search(l)
                             and INCLUDE_MEMBER_RE.search(l).group(1) not in keep))
    s_out = os.path.join(workdir, "p.s")
    d_out = os.path.join(workdir, "p.data.s")
    r = subprocess.run(cc.split() + [src, "-o", s_out, "--data-segment", d_out],
                       capture_output=True, text=True)
    if r.returncode != 0:
        head = (r.stderr.strip().splitlines() or ["(no message)"])[:3]
        die("prefix compile failed at member '%s':\n  %s"
            % (stem, "\n  ".join(head)))
    return open(s_out).readlines(), open(d_out).readlines()


def body(lines, what, stem):
    """Drop the trailing FGX2_RELOC_COUNT (a per-TU total, not member code)."""
    if not lines or not lines[-1].strip().startswith("FGX2_RELOC_COUNT"):
        die("%s for '%s' does not end in FGX2_RELOC_COUNT" % (what, stem))
    return lines[:-1]


def carve_inserted(prev, cur, stem):
    """The lines `cur` adds to `prev`, in order.  Deletions mean the emission
    is not monotone in member order and the carve would be wrong.

    ponytail: line-level matching, and the guard below only catches deletions.
    Two data lines that are byte-identical could in principle be matched to
    each other rather than to their own member, attributing a `DA _sym` to the
    wrong owner and under-importing.  fcc --pile makes data labels globally
    unique, so an identical PAIR of lines is improbable -- upgrade to matching
    on the column-1 label (with continuation lines following their label) if
    that ever stops holding."""
    out = []
    for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(
            None, prev, cur, autojunk=False).get_opcodes():
        if tag in ("delete", "replace"):
            die("adding member '%s' REMOVED %d emitted line(s) -- the "
                "aggregate is not monotone in member order, carve unsafe"
                % (stem, i2 - i1))
        if tag == "insert":
            out.extend(cur[j1:j2])
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--lib", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--cc", required=True)
    ap.add_argument("--aggregate", required=True)
    ap.add_argument("--public", help="symbol list always exported (fgx_ar index)")
    ap.add_argument("-v", "--verbose", action="store_true")
    a = ap.parse_args()

    agg_lines = open(a.aggregate).readlines()
    stems = [m.group(1) for m in
             (INCLUDE_MEMBER_RE.search(l) for l in agg_lines) if m]
    if not stems:
        die("aggregate '%s' has no #include \"member.c\" lines" % a.aggregate)
    if len(set(stems)) != len(stems):
        die("aggregate '%s' includes a member twice" % a.aggregate)

    shutil.rmtree(a.out, ignore_errors=True)
    os.makedirs(a.out)
    # FIXED, repo-relative workdir -- NOT tempfile.mkdtemp.  fcc stamps the
    # source path into the "generated from" header comment, which lands in the
    # first member's carved fragment, so a random /tmp path made that fragment
    # differ on every regeneration and the archive could never be checked for
    # staleness (the whole point of checking it in).
    work = a.out + ".carve"
    shutil.rmtree(work, ignore_errors=True)
    os.makedirs(work)
    agg_base = os.path.basename(a.aggregate)
    try:
        prev_s, prev_d = [], []
        s_paths = []
        for i, stem in enumerate(stems):
            cur_s, cur_d = compile_prefix(a.cc, agg_lines, set(stems[:i + 1]),
                                          work, agg_base, stem)
            cur_s, cur_d = body(cur_s, "code", stem), body(cur_d, "data", stem)
            # Code: pure append (fcc emits routines in source order).
            if cur_s[:len(prev_s)] != prev_s:
                die("member '%s' did not append to the code segment -- "
                    "emission is not in member order, carve unsafe" % stem)
            frag_s = cur_s[len(prev_s):]
            # Data: two regions (globals, then string pool) both grow, so the
            # new member's data is an INSERT at two points, not an append.
            frag_d = carve_inserted(prev_d, cur_d, stem)
            sp = os.path.join(a.out, stem + ".s")
            with open(sp, "w") as f:
                f.writelines(frag_s)
            with open(os.path.join(a.out, stem + ".data.s"), "w") as f:
                f.writelines(frag_d)
            s_paths.append(sp)
            prev_s, prev_d = cur_s, cur_d
    finally:
        shutil.rmtree(work, ignore_errors=True)

    cmd = [sys.executable, os.path.join(HERE, "src", "ld", "fgx_ar.py")]
    if a.verbose:
        cmd.append("-v")
    cmd += ["index", "--lib", a.lib, "--out", a.out, "--cc", a.cc,
            "--aggregate", a.aggregate]
    if a.public:
        cmd += ["--public", a.public]
    sys.exit(subprocess.call(cmd + s_paths))


if __name__ == "__main__":
    main()
