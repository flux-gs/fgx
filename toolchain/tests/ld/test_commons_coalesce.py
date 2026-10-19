#!/usr/bin/env python3
"""
test_commons_coalesce.py -- self-test for K&R A.10.2 tentative-definition
coalescing (multi-TU link): fcc's --commons sidecar + tools/gen_commons.py.

K&R "The C Programming Language" A.10.2 (p.187): the tentative definitions of an
externally-linked object across ALL translation units are considered together;
if a real definition occurs anywhere the tentatives become mere declarations,
else they become ONE definition with initializer 0.  2.11BSD K&R sources declare
file-scope globals in a shared header WITHOUT `extern` (the Bourne shell's
defs.h), so the same `int x;` appears in every TU -- a per-TU `x DS` label would
collide when the data segments assemble together.

Two halves:
  A. fcc --commons: a tentative def (uninit, no `extern`) is NOT emitted as a
     `<name> DS` label in .data.s; it is recorded `TENT <name> <size> <reloc>`
     in the sidecar.  A real (initialized) def stays in .data.s and is recorded
     `DEF <name>`.
  B. gen_commons.py: merges the sidecars into ONE commons.data.s -- one
     `<name> DS <maxsize>` per name whose only defs are tentative; a name with a
     DEF (or a --extern-defs library label) is dropped (the real def wins).

Hermetic: a real fcc invocation for (A), pure gen_commons runs for (B).  No
merlin32/MAME.  Run: python3 tests/ld/test_commons_coalesce.py
"""
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")
FCC = os.path.join(ROOT, "fcc")
GEN_COMMONS = os.path.join(ROOT, "tools", "gen_commons.py")


def fail(msg):
    print("FAIL:", msg)
    return False


def test_fcc_commons_split():
    """fcc --commons routes a tentative def out of .data.s into the sidecar,
    and records an initialized def as DEF (kept in .data.s)."""
    src = (
        "int tent_a;\n"            # tentative def (uninit)  -> TENT
        "int tent_b;\n"            # tentative def          -> TENT
        "int real_c = 7;\n"        # real def (initialized) -> DEF, stays in data
        "int main(){ return tent_a + tent_b + real_c; }\n"
    )
    with tempfile.TemporaryDirectory() as d:
        cpath = os.path.join(d, "u.c")
        data = os.path.join(d, "u.data.s")
        comm = os.path.join(d, "u.comm")
        code = os.path.join(d, "u.code.s")
        with open(cpath, "w") as f:
            f.write(src)
        r = subprocess.run([FCC, "--data-segment", data, "--commons", comm,
                            cpath, "-o", code], capture_output=True, text=True)
        if r.returncode != 0:
            return fail("fcc --commons rc=%d: %s" % (r.returncode, r.stderr.strip()))
        comm_txt = open(comm).read()
        data_txt = open(data).read()
        # tentatives recorded, sized, NOT in the data segment
        if "TENT tent_a 2 0" not in comm_txt:
            return fail("sidecar missing 'TENT tent_a 2 0':\n" + comm_txt)
        if "TENT tent_b 2 0" not in comm_txt:
            return fail("sidecar missing 'TENT tent_b 2 0':\n" + comm_txt)
        if "DEF real_c" not in comm_txt:
            return fail("sidecar missing 'DEF real_c':\n" + comm_txt)
        if re.search(r"(?m)^tent_a\b", data_txt):
            return fail("tentative 'tent_a' should NOT be a label in .data.s")
        if not re.search(r"(?m)^real_c\b", data_txt):
            return fail("real def 'real_c' should remain a label in .data.s")
        print("PASS fcc_commons_split")
        return True


def run_gen_commons(d, comm_records, extern_defs=None):
    """Write synthetic sidecars + optional extern-def .s, run gen_commons,
    return the coalesced label->size dict from commons.data.s."""
    comm_paths = []
    for i, recs in enumerate(comm_records):
        p = os.path.join(d, "tu%d.comm" % i)
        with open(p, "w") as f:
            f.write("# tu%d\n" % i)
            f.write("\n".join(recs) + "\n")
        comm_paths.append(p)
    argv = [sys.executable, GEN_COMMONS]
    if extern_defs:
        ep = os.path.join(d, "lib.s")
        with open(ep, "w") as f:
            f.write("\n".join("%-14s DS 2" % n for n in extern_defs) + "\n")
        argv += ["--extern-defs", ep]
    out = os.path.join(d, "commons.data.s")
    argv += [out, *comm_paths]
    r = subprocess.run(argv, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError("gen_commons rc=%d: %s" % (r.returncode, r.stderr))
    got = {}
    exported = set()
    for line in open(out):
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s+DS\s+(\d+)", line)
        if m:
            got[m.group(1)] = int(m.group(2))
        m2 = re.match(r"^\s+FGX2_EXPORT\s+(\S+)", line)
        if m2:
            exported.add(m2.group(1))
    return got, exported


def test_gen_commons_dedup():
    """Same tentative in 3 TUs -> ONE definition, at the MAX size."""
    with tempfile.TemporaryDirectory() as d:
        got, _ = run_gen_commons(d, [
            ["TENT shared 2 0"],
            ["TENT shared 2 0", "TENT other 4 0"],
            ["TENT shared 10 0"],           # a bigger tentative (jmp_buf-ish)
        ])
        if got.get("shared") != 10:
            return fail("shared should coalesce to max size 10, got %r" % got.get("shared"))
        if got.get("other") != 4:
            return fail("other should be 4, got %r" % got.get("other"))
        print("PASS gen_commons_dedup")
        return True


def test_gen_commons_def_wins():
    """A real DEF anywhere drops the tentatives (K&R: definition wins)."""
    with tempfile.TemporaryDirectory() as d:
        got, _ = run_gen_commons(d, [
            ["TENT brkincr 2 0"],           # tentative in TU0/TU1
            ["TENT brkincr 2 0"],
            ["DEF brkincr"],                # real (initialized) def in TU2
        ])
        if "brkincr" in got:
            return fail("brkincr has a real def -> must NOT be in commons")
        print("PASS gen_commons_def_wins")
        return True


def test_gen_commons_extern_def_wins():
    """A library-provided label (errno) drops the port's tentative def."""
    with tempfile.TemporaryDirectory() as d:
        got, _ = run_gen_commons(d,
                                 [["TENT errno 2 0"], ["TENT keep 2 0"]],
                                 extern_defs=["errno"])
        if "errno" in got:
            return fail("errno is a libc def -> must NOT be re-defined in commons")
        if got.get("keep") != 2:
            return fail("keep should survive, got %r" % got.get("keep"))
        print("PASS gen_commons_extern_def_wins")
        return True


def test_gen_commons_reloc_export():
    """A tentative that is a pointer-init target (reloc=1) is FGX2_EXPORT'd."""
    with tempfile.TemporaryDirectory() as d:
        _, exported = run_gen_commons(d, [
            ["TENT plain 2 0"],
            ["TENT ptgt 4 1"],              # reloc in one TU
            ["TENT ptgt 4 0"],
        ])
        if "ptgt" not in exported:
            return fail("ptgt is a reloc target -> must be FGX2_EXPORT'd")
        if "plain" in exported:
            return fail("plain is not a reloc target -> must NOT be exported")
        # A link may concatenate commons.data.s with the TUs' data into one
        # source file, where fgx_ld's count gate sums every declaration.
        counts = re.findall(r"^\s+FGX2_RELOC_COUNT\s+(\d+)",
                            open(os.path.join(d, "commons.data.s")).read(), re.M)
        if counts != [str(len(exported))]:
            return fail("commons.data.s must declare its %d FGX2_* rows, got %r"
                        % (len(exported), counts))
        print("PASS gen_commons_reloc_export")
        return True


def main():
    results = [
        test_fcc_commons_split(),
        test_gen_commons_dedup(),
        test_gen_commons_def_wins(),
        test_gen_commons_extern_def_wins(),
        test_gen_commons_reloc_export(),
    ]
    n_fail = results.count(False)
    print("%d/%d commons-coalescing cases passed" % (len(results) - n_fail, len(results)))
    sys.exit(1 if n_fail else 0)


if __name__ == "__main__":
    main()
