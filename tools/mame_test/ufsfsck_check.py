#!/usr/bin/env python3
"""ufsfsck_check -- hand every volume a test wrote to the campaign's ORACLE.

WHY THIS EXISTS.  The UFS migration plan states the phase-1 bar as a
measurement rather than a habit:

    "Attribution comes from THE ORACLE, NOT FROM THE DISK IMAGE BEING
     UNCHANGED.  Every write FGX makes to the UFS volume is checkable by an
     independent implementation of the same format -- host `fgxfs fsck` and
     2.11BSD's own fsck under SIMH.  That is a far stronger control than 'we
     did not touch ProDOS', and unlike the old phase-1 gate it can actually
     fail."
    (docs/history/plans/2026-08-09-ufs-migration-campaign.md, "Phase 1")

tools/gate.sh says the same thing about the tool: fgxfs is "the independent
implementation every claim FGX makes about a volume it wrote gets checked
against".  UNTIL THIS CHECKER, THAT SENTENCE WAS NOT TRUE.  `fgxfs --self-test'
ran on every gate run and still does, but it fscks volumes IT MADE ITSELF --
nine mutation arms plus 3 KB lifted off a real PDP-11.  No volume the 65816 had
written was ever handed to it, so the oracle proved that fgxfs agrees with
fgxfs, which is the one thing the plan's own words say is not evidence.

Two things stood in the way and both are gone:

  - The volume was not disposable.  MAME was pointed at `disk/ufsscratch.fs'
    in the repo and opens a hard disk read-write, so the four write probes each
    put every byte back by hand and there was nothing left to fsck.  run.py
    stages spindles into the per-test scratch directory now, so a run may leave
    its writes.
  - Nothing carried the verdict.  This does: `check_script' already runs on
    every `run.py NAME', so the oracle is consulted whether or not somebody
    remembers to.

WHAT IT ASSERTS.  Every staged volume is fsck-clean AFTER the machine has had
it.  For a read-only test that is a real claim and not a formality: a mount
that scribbles, a superblock written back with a stale free count, a probe that
frees a block twice, all leave the volume inconsistent, and all of them are
invisible to a screen scrape.

THE VACUOUS CASE IS THE ONE TO GUARD.  A checker that finds no volumes and
exits 0 reads exactly like a checker that found them all clean -- the failure
this suite has shipped before and now has a rule about.  So finding nothing is
a FAILURE here, and arms 3 and 4 of the self-test are that case rather than the
corruption case.

FAIL-CLOSED ON WHAT IT DOES NOT RECOGNISE.  Every staged spindle is fscked; a
volume that is not a 2.11BSD filesystem fails rather than being skipped.  A skip
rule would be the vacuous shape again, one level down: the day somebody attaches
a ProDOS spindle, "not recognised, so clean" is the wrong answer and "this
checker does not know what to do with sd3" is the right one.
"""

import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
FGXFS = REPO / "tools" / "fgxfs.py"


def fsck_dir(vols, only=None):
    """fsck every image in `vols', or exactly the paths in `only'.  Returns
    (problems, checked_names).  `only' skips the empty-directory guards
    below: its caller has already established that the file is there, and a
    named file that does not exist is the caller's question to ask."""
    problems = []
    if only is not None:
        for img in only:
            r = subprocess.run([sys.executable, str(FGXFS), "fsck", str(img)],
                               capture_output=True, text=True)
            if r.returncode != 0:
                detail = (r.stdout + r.stderr).strip() or f"rc={r.returncode}"
                problems.append(f"{img.name}: {detail}")
        return (problems, [p.name for p in only])
    if not vols.is_dir():
        return ([f"no staged-volume directory at {vols} -- either the machine "
                 f"had no spindle attached or run.py did not stage one, and "
                 f"either way this check would otherwise pass having tested "
                 f"nothing"], [])
    images = sorted(p for p in vols.iterdir() if p.is_file())
    if not images:
        return ([f"{vols} is empty -- no volume to check, so a green result "
                 f"here would mean nothing"], [])
    for img in images:
        r = subprocess.run([sys.executable, str(FGXFS), "fsck", str(img)],
                           capture_output=True, text=True)
        if r.returncode != 0:
            detail = (r.stdout + r.stderr).strip() or f"rc={r.returncode}"
            problems.append(f"{img.name}: {detail}")
    return (problems, [p.name for p in images])


def main(argv):
    if len(argv) != 2:
        print("usage: ufsfsck_check.py DUMP_JSON | --self-test",
              file=sys.stderr)
        return 2
    # The harness hands a checker the dump; the scratch directory it lives in
    # is what holds the staged volumes (run.py: `extracted' is scratch/extracted
    # and the dump is written beside it).
    scratch = Path(argv[1]).resolve().parent
    # STAGED SPINDLES ARE OPTIONAL NOW, AND THE VACUOUS GUARD MOVED WITH THAT.
    # It used to be an error for `vols/' to be empty, and that was right while
    # run.py attached the /dev volume to every machine: an empty directory then
    # meant a spindle had gone missing.  The /dev spindle is gone -- a root
    # carrying its own /dev needs no volume mounted for it -- so a manifest
    # with no `extra_hards' now legitimately stages nothing, and the boot
    # volume below is what it has to say about.  The guard is therefore about
    # the TOTAL: fsck nothing and this is still a failure, which is the
    # property that arms 3 and 4 exist to hold.
    problems, checked = ([], [])
    if (scratch / "vols").is_dir() and any((scratch / "vols").iterdir()):
        problems, checked = fsck_dir(scratch / "vols")

    # AND THE BOOT VOLUME, which is where every ORDINARY write test writes and
    # which this checker did not look at for its first month.  `vols' holds the
    # spindles run.py stages beside the boot disk -- what the five write PROBES
    # scribble on -- and those five are the only manifests that named this
    # script, and all five are gated off by default.  So the oracle was pointed
    # exclusively at volumes nobody normally writes, and apple/fgx#332 lived in
    # the boot volume undetected: every `echo x > f' left a block on the free
    # list AND owned by an inode, and after a remount that block was handed out
    # twice.  Found by hand, not by this.
    #
    # run.py:1274 copies the boot disk into the scratch as `fgxroot.fs', so the
    # per-run copy is disposable in exactly the way `vols' is and the same
    # argument applies.  It is added to the SAME problem list rather than
    # checked separately: a caller reading one verdict should not have to know
    # there were two.
    boot = scratch / "fgxroot.fs"
    if boot.is_file():
        bproblems, bchecked = fsck_dir(scratch, only=[boot])
        problems += bproblems
        checked += bchecked
    if not checked and not problems:
        print("FAIL nothing was fsck'd -- no staged spindle and no boot volume "
              "in the scratch, so a green result here would mean nothing")
        return 1
    if problems:
        for p in problems:
            print(f"FAIL {p}")
        return 1
    print(f"fsck clean after the run: {', '.join(checked)}")
    return 0


# ---------------------------------------------------------------------------
def self_test():
    """Four arms.  Two say the checker can go RED, which is the only property
    that makes it worth running; the other two are the vacuous case, which is
    the failure mode a checker of this shape actually has."""
    import shutil
    import tempfile

    tmp = Path(tempfile.mkdtemp(prefix="ufsfsck_selftest_"))
    fails = []

    def mkvol(path, blocks=512):
        subprocess.run([sys.executable, str(FGXFS), "mkfs", str(path),
                        "--size", str(blocks)],
                       check=True, capture_output=True)

    # 1. A clean volume passes.  Without this arm the other three are satisfied
    #    by a checker that always fails.
    vols = tmp / "clean" / "vols"
    vols.mkdir(parents=True)
    mkvol(vols / "sd2.fs")
    problems, checked = fsck_dir(vols)
    if problems or checked != ["sd2.fs"]:
        fails.append(f"arm 1: a clean volume was not accepted: {problems}")

    # 2. A CORRUPT volume fails.  The mutation is the superblock claiming more
    #    blocks than the image holds, which is fgxfs's own `truncated_image'
    #    arm reached from outside -- no import of the oracle's internals, so
    #    this stays a test of the checker rather than of fgxfs.
    vols = tmp / "dirty" / "vols"
    vols.mkdir(parents=True)
    img = vols / "sd2.fs"
    mkvol(img)
    os.truncate(img, os.path.getsize(img) - 8192)
    problems, _ = fsck_dir(vols)
    if not problems:
        fails.append("arm 2: a truncated volume was reported clean")

    # 3. NO VOLUMES IS A FAILURE, not a pass.  This is the arm that matters:
    #    a test whose spindle silently went missing must not read as green.
    vols = tmp / "empty" / "vols"
    vols.mkdir(parents=True)
    problems, checked = fsck_dir(vols)
    if not problems or checked:
        fails.append("arm 3: an empty volume directory was reported clean")

    # 4. And so is no directory at all -- the shape a manifest with no
    #    `extra_hards' and no /dev volume would produce.
    problems, checked = fsck_dir(tmp / "absent" / "vols")
    if not problems or checked:
        fails.append("arm 4: a missing volume directory was reported clean")

    # 5. THE BOOT VOLUME IS CHECKED TOO, and this arm exists because it was
    #    not.  A scratch holding a CLEAN `vols/' and a CORRUPT `fgxroot.fs' is
    #    exactly the shape every ordinary write test had while apple/fgx#332
    #    sat in the boot volume: the checker looked only at the staged
    #    spindles, found them fine, and printed a green line naming a volume
    #    the test never wrote to.  It goes through main() rather than fsck_dir
    #    because WHICH FILES main CHOOSES is the whole of what changed.
    scratch = tmp / "bootbad"
    (scratch / "vols").mkdir(parents=True)
    mkvol(scratch / "vols" / "sd2.fs")
    boot = scratch / "fgxroot.fs"
    mkvol(boot)
    os.truncate(boot, os.path.getsize(boot) - 8192)
    (scratch / "dump.json").write_text("{}")
    if main(["ufsfsck_check.py", str(scratch / "dump.json")]) == 0:
        fails.append("arm 5: a corrupt BOOT volume was reported clean while "
                     "the staged spindle was fine")

    # 6. And the same scratch with a CLEAN boot volume passes, or arm 5 would
    #    be satisfied by a checker that had simply started failing.
    scratch = tmp / "bootok"
    (scratch / "vols").mkdir(parents=True)
    mkvol(scratch / "vols" / "sd2.fs")
    mkvol(scratch / "fgxroot.fs")
    (scratch / "dump.json").write_text("{}")
    if main(["ufsfsck_check.py", str(scratch / "dump.json")]) != 0:
        fails.append("arm 6: a clean scratch with a boot volume was rejected")

    # 7. NO SPINDLE AND A BOOT VOLUME IS THE ORDINARY SHAPE NOW, and must
    #    pass -- run.py stopped attaching the /dev volume, so a manifest
    #    without `extra_hards' stages nothing and `vols/' is legitimately
    #    empty.  Arm 3 asserts the OLD reading of that shape (fsck_dir alone
    #    still calls it vacuous, and still should: on its own it has tested
    #    nothing), so this arm is what says main() no longer agrees when there
    #    is a boot volume to speak for.
    scratch = tmp / "nospindle"
    (scratch / "vols").mkdir(parents=True)
    mkvol(scratch / "fgxroot.fs")
    (scratch / "dump.json").write_text("{}")
    if main(["ufsfsck_check.py", str(scratch / "dump.json")]) != 0:
        fails.append("arm 7: an empty vols/ beside a clean boot volume was "
                     "rejected, which is now every ordinary test's shape")

    # 8. AND NOTHING AT ALL STILL FAILS.  This is arm 3's property moved to
    #    where the guard now lives: a scratch with no spindle AND no boot
    #    volume has nothing to say, and saying it cleanly would be the vacuous
    #    green this whole file exists to refuse.
    scratch = tmp / "nothing"
    scratch.mkdir(parents=True)
    (scratch / "dump.json").write_text("{}")
    if main(["ufsfsck_check.py", str(scratch / "dump.json")]) == 0:
        fails.append("arm 8: a scratch with no volume of any kind was "
                     "reported clean")

    shutil.rmtree(tmp)
    if fails:
        for f in fails:
            print(f"SELF-TEST FAIL: {f}")
        return 1
    print("ufsfsck_check --self-test: OK (clean accepted, truncated volume "
          "caught, a boot volume with no spindle accepted, nothing-at-all "
          "refused, and the "
          "BOOT volume is checked as well as the staged spindles)")
    return 0


if __name__ == "__main__":
    # sys.exit on the RETURN value: a checker whose failure cannot reach the
    # caller is the defect it exists to prevent.
    if len(sys.argv) == 2 and sys.argv[1] == "--self-test":
        sys.exit(self_test())
    sys.exit(main(sys.argv))
