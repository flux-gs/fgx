#!/usr/bin/env python3
"""Build + boot the far-pointer construct sweep; assert exit 43 (all green).

Rebuilds by DEFAULT (safe when hacking emit.c); pass --no-rebuild to reuse an
existing multibank.bin.  Stages the binary the same way the single-bank oracle
stages fixtures (disk_src/tests/fcc/<name>, run by /tests/fcc/<name>), boots via
tools/mame_test/run.py, and scrapes the driver's own screen markers.

Reserved exit codes (driver -> =MBEND / process $?):
  43       all constructs pass (GREEN)
  99       preflight failed: binary not genuinely multi-bank (untrustworthy)
  100+id   first failing construct's ID
  other    harness/boot failure (not a construct verdict)

Process exit: 0 iff the sweep exited 43, else 1.
"""
import json, re, shutil, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[0]))          # toolchain/tests on path
import run_runtime as RR                            # reuse staging helpers/constants

REPO = RR.REPO
RUN_PY = RR.RUN_PY
MAME_TESTS = RR.MAME_TESTS
DISK_SRC_FCC = RR.DISK_SRC_FCC
BIG_DISK_REL = RR.BIG_DISK_REL
BIN = HERE / "multibank.bin"
NAME = "mbsweep"
DISK_NAME = "mbsweep"                               # lower: a 2.11BSD root is
                                                    # case-SENSITIVE (apple/fgx#342)

TEST = {
    "name": NAME,
    "description": "far-pointer construct sweep; 43=green, 99=preflight, 100+id=fail",
    # Just run the binary — the driver prints =MBi/=MBEND itself.  (A chained
    # `echo ...; echo ...` command does NOT execute under MAME autoboot; keep it
    # to one short command and rely on the default prompt-return exit.)
    "command": "/tests/fcc/%s" % DISK_NAME.lower(),
    "timeout_s": 120,
    "disk_image": BIG_DISK_REL,
    "expect": {"screen_contains": ["=MBEND"]},
}


def build_and_stage():
    subprocess.check_call([str(HERE / "build_sweep.sh")])
    print("==> building kernel + userland (./build.sh disk)...")
    RR.build_default_kernel_first(stage_userland=True)
    print("==> staging multibank.bin as /tests/fcc/%s ..." % DISK_NAME.lower())
    if DISK_SRC_FCC.exists():
        shutil.rmtree(DISK_SRC_FCC)
    DISK_SRC_FCC.mkdir(parents=True)
    shutil.copy(BIN, DISK_SRC_FCC / DISK_NAME)
    RR.write_file_info(DISK_SRC_FCC, [DISK_NAME])
    print("==> building 32MB sweep disk at %s ..." % BIG_DISK_REL)
    RR.build_big_disk()


def scrape():
    dump = Path("/tmp/fgx_test_%s/dump.txt" % NAME)
    screen = dump.read_text() if dump.exists() else ""
    vec = re.findall(r'=MBi\s+(\d+)\s+([PF])', screen)
    m = re.search(r'=MBEND\s+(\d+)', screen) or re.search(r'=MBRC\s+(\d+)', screen)
    code = int(m.group(1)) if m else None
    return screen, vec, code


def main():
    if "--no-rebuild" not in sys.argv:
        build_and_stage()
    mf = MAME_TESTS / ("%s.json" % NAME)
    mf.write_text(json.dumps(TEST, indent=2))
    # Clear any stale dump so a boot that fails to run can't return old markers
    # (the stale-dump false-green trap).
    dump = Path("/tmp/fgx_test_%s/dump.txt" % NAME)
    if dump.exists():
        dump.unlink()
    try:
        # --fresh is REQUIRED, not an optimisation knob.  run.py's green cache
        # reports "cached PASS" WITHOUT booting MAME, so it writes no dump --
        # and this scraper consumes the dump, not run.py's verdict.  With the
        # stale-dump unlink above (which is right) the result is a hard FAIL
        # reading "no =MBEND marker (hang or boot failure)" on a tree that is
        # perfectly healthy.  Same defect run_runtime.py had; there it scored
        # ANOTHER chunk's stale screen instead, which was worse.
        subprocess.run(["python3", str(RUN_PY), NAME, "--headless", "--fresh"],
                       cwd=REPO, capture_output=True, text=True, timeout=240)
    finally:
        mf.unlink(missing_ok=True)
    screen, vec, code = scrape()
    print(screen[-2000:] if screen else "(no dump.txt)")
    if vec:
        print("==> per-construct:", " ".join("%d:%s" % (int(i), r) for i, r in vec))
    if code == 43:
        print("==> PASS: all constructs green (exit 43)")
        return 0
    if code == 99:
        print("==> FAIL: preflight — binary not multi-bank (results untrustworthy)")
        return 1
    if code is None:
        print("==> FAIL: no =MBEND/=MBRC marker (hang or boot failure)")
        return 1
    if code > 100:
        print("==> FAIL: first red construct #%d" % (code - 100))
        return 1
    print("==> FAIL: unexpected exit code %d (harness/boot failure)" % code)
    return 1


if __name__ == "__main__":
    sys.exit(main())
