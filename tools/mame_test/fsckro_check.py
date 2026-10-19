#!/usr/bin/env python3
"""fsckro_check -- `fsck -n' must have written NOTHING.

THE SCREEN CANNOT SAY THIS.  fsck prints `(NO WRITE)' because -n was passed,
not because it then refrained; a build whose write path ignored nflag would
print the same banner, name the same fault, and quietly repair the volume.  So
the claim is checked on the PLATTER: the spindle the machine had is compared
byte for byte with the one the build made, and it must still be broken.

BOTH HALVES ARE NEEDED AND THEY FAIL DIFFERENTLY.  A volume that is
byte-identical but CLEAN would mean the fault never existed -- the vacuous case
ufscorrupt's build-time control exists to stop, checked again here because the
image travels.  A volume that is still broken but CHANGED means something wrote
to it, which is the defect this test is named for even if the change did not
happen to be a repair.

WHY IT IS A SPINDLE AT ALL: 2.11BSD's reply() returns 0 under nflag
(usr/sbin/fsck/utilities.c:49), so `fsck -n' on a regular file answers " no" to
"file is not a block or character device" and never opens the filesystem.  The
read-only claim is only reachable through a block device node.

Exit 0 = pass, 1 = fail, 2 = inconclusive.
"""
import hashlib
import pathlib
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
FGXFS = REPO / "tools" / "fgxfs.py"
SRC = REPO / "disk" / "ufsbadspin.po"
NAME = "ufsbadspin.po"


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main(path="dump.json"):
    scratch = pathlib.Path(path).resolve().parent
    got = scratch / "vols" / NAME
    if not got.exists():
        print(f"fsckro: INCONCLUSIVE -- no staged spindle at {got}.  The "
              f"manifest must name disk/{NAME} in extra_hards; without it the "
              f"machine fscked nothing and there is no platter to judge.")
        return 2
    if not SRC.exists():
        print(f"fsckro: INCONCLUSIVE -- {SRC} is missing, so there is nothing "
              f"to compare against.  `ninja disk/ufsbadspin.po'.")
        return 2

    a, b = sha(SRC), sha(got)
    if a != b:
        print(f"fsckro: FAIL -- the spindle CHANGED under `fsck -n'.\n"
              f"  built   {a[:16]}...\n  after   {b[:16]}...\n"
              f"Something wrote to a volume opened read-only.  fsck's own "
              f"`(NO WRITE)' banner reports the FLAG, not the behaviour, which "
              f"is why this is checked on the platter.")
        return 1

    r = subprocess.run([sys.executable, str(FGXFS), "fsck", str(got)],
                       capture_output=True, text=True)
    if r.returncode == 0:
        print("fsckro: FAIL -- the spindle is byte-identical to the built one "
              "and the host fsck calls it CLEAN, so the fault this test asks "
              "the target to find was never there.  That makes the screen "
              "assertion vacuous rather than the write check green.")
        return 1

    print(f"fsckro: PASS -- {NAME} is byte-identical after `fsck -n' "
          f"({a[:16]}...) and still broken, so nothing was written.")
    return 0


def self_test():
    """Four arms.  The two that matter are the ones that must NOT return 0."""
    import tempfile, shutil, os
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="fsckro_selftest_"))
    fails = []

    def run(make_vol):
        d = tmp / ("run_%d" % len(list(tmp.iterdir())))
        (d / "vols").mkdir(parents=True)
        (d / "dump.json").write_text("{}")
        make_vol(d / "vols" / NAME)
        return main(str(d / "dump.json"))

    if not SRC.exists():
        print("fsckro_check self-test: INCONCLUSIVE -- disk/ufsbadspin.po is "
              "not built, so no arm can run.  `ninja disk/ufsbadspin.po'.",
              file=sys.stderr)
        shutil.rmtree(tmp, ignore_errors=True)
        return 2

    # (1) GREEN: the untouched spindle passes.
    if run(lambda p: shutil.copy(SRC, p)) != 0:
        fails.append("an untouched spindle was not accepted")

    # (2) RED, THE NAMED DEFECT: one byte written must fail.
    def scribble(p):
        shutil.copy(SRC, p)
        with open(p, "r+b") as f:
            f.seek(8192)
            f.write(b"\x5a")
    if run(scribble) != 1:
        fails.append("a spindle that CHANGED was not called a failure -- the "
                     "checker cannot go red on the thing it is named for")

    # (3) RED, THE VACUOUS CASE: unchanged but CLEAN means no fault existed.
    def repair(p):
        subprocess.run([sys.executable, str(FGXFS), "mkfs", str(p),
                        "--size", "64"], capture_output=True)
    if run(repair) != 1:
        fails.append("a clean volume was accepted -- a fault that was never "
                     "there makes the screen assertion vacuous")

    # (4) INCONCLUSIVE: no staged spindle at all is not a pass.
    d = tmp / "run_none"
    d.mkdir()
    (d / "dump.json").write_text("{}")
    if main(str(d / "dump.json")) != 2:
        fails.append("a run with no staged spindle was judged rather than "
                     "refused")

    shutil.rmtree(tmp, ignore_errors=True)
    for f in fails:
        print("SELFTEST FAIL: " + f, file=sys.stderr)
    if fails:
        return 1
    print("fsckro_check self-test: 4 arms pass (1 green, 2 red-capable, "
          "1 refusal)")
    return 0


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--self-test":
        sys.exit(self_test())
    sys.exit(main(*sys.argv[1:]))
