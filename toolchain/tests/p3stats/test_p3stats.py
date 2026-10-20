#!/usr/bin/env python3
"""fcc2 Phase-3 increment-0 measurement test.

Compile a fixture with FCC_P3_STATS=1, parse the `fcc-p3` TSV lines fcc emits to
stderr, and assert the hand-computed per-(function,key) counts/bytes.  The
expectations are READ from a real compile (never guessed) and frozen here; this
test guards against regressions in the counting logic, while Task-6's asm-text
sample is the trust anchor for the absolute byte weights.
"""
import os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
FCC  = os.path.join(HERE, "..", "..", "fcc")


def stats_for(cfile):
    """Return {(func, key): (count, bytes)} from compiling cfile with stats on."""
    env = dict(os.environ, FCC_P3_STATS="1")
    with tempfile.NamedTemporaryFile(suffix=".s", delete=False) as t:
        out = t.name
    try:
        p = subprocess.run([FCC, os.path.join(HERE, cfile), "-o", out],
                           env=env, capture_output=True, text=True)
    finally:
        try: os.unlink(out)
        except OSError: pass
    if p.returncode != 0:
        print(f"   fcc failed on {cfile}: {p.stderr.strip()[:200]}")
    res = {}
    for ln in p.stderr.splitlines():
        f = ln.split("\t")
        if len(f) == 5 and f[0] == "fcc-p3":
            res[(f[1], f[2])] = (int(f[3]), int(f[4]))
    return res


def check(name, cfile, expect):
    got = stats_for(cfile)
    bad = [(k, expect[k], got.get(k)) for k in expect if got.get(k) != expect[k]]
    if bad:
        print(f"FAIL {name}:")
        for k, e, g in bad:
            print(f"   {k}: expected {e} got {g}")
        return False
    print(f"ok   {name}")
    return True


# (name, cfile, {(func, key): (count, bytes)})  -- expectations frozen per task,
# READ from a real compile and confirmed against the emitted .s.
CASES = [
    ("scaffold", "empty_fn.c", {("f", "fn"): (1, 0)}),
    # L3: 2 complex stashes (b*g mul, outer a+(b*g) add); 1 leaf-miss (a+c, char
    # leaf, fold-rejected). x+y folds away. 3 surviving pushes.
    ("L3_stash", "stash.c", {
        ("f", "L3_leafmiss"): (1, 2),
        ("f", "L3_complex"):  (2, 4),
        ("f", "L4_ovf"):      (3, 0),
    }),
    # L4: deep param tree. 2 leaf-miss (a+b, c+d: PARAM leaves ir_select excludes);
    # 5 complex (the muls + sub-sums); 7 surviving real pushes.
    ("L4_pushovf", "pushovf.c", {
        ("f", "L3_leafmiss"): (2, 4),
        ("f", "L3_complex"):  (5, 10),
        ("f", "L4_ovf"):      (7, 0),
    }),
    # L1/L2: 2 surviving reloads in the .s (x for `g=x` = L2; y for `return y+g`
    # = L1).  The y=x+2 reload of x is EXCLUDED (the textual peephole already
    # forwards it: A is resident across the store).  Both within-BB, floor=ceil.
    # storedrop=1 (y is read once -> its STA could drop).  L3_leafmiss=2 = the two
    # const-immediate adds (a+1, x+2, fold-reachable as ADC #k).
    ("L1L2_reload", "reload.c", {
        ("f", "L1_wbb"):      (1, 0),
        ("f", "L2_wbb"):      (1, 0),
        ("f", "L1_storedrop"):(1, 2),
        ("f", "floor"):       (2, 4),
        ("f", "ceil"):        (2, 4),
        ("f", "L3_leafmiss"): (2, 4),
    }),
    # L5: a deref barrier between STORE x and its reload -> the reload is
    # cross-barrier (L1_xbar_deref) and the deref is one coverage opportunity
    # (L5_sand_deref).  No floor (cross-barrier can't be allocator-reached yet).
    ("L5_barrier", "barrier.c", {
        ("f", "L1_xbar_deref"): (1, 0),
        ("f", "L5_sand_deref"): (1, 0),
        ("f", "ceil"):          (1, 2),
    }),
]

if __name__ == "__main__":
    ok = all(check(*c) for c in CASES)
    print(f"\n{'PASS' if ok else 'FAIL'}: {sum(1 for _ in CASES)} case(s)")
    sys.exit(0 if ok else 1)
