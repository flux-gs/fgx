#!/usr/bin/env python3
# FGX MAME test runner.
#
# Each test is a JSON manifest under tools/mame_test/tests/*.json.  The runner
# boots FGX in MAME (or restores a cached save state for speed), runs the test
# command via natural-keyboard input, polls for an exit marker, extracts
# /root/faslog and any requested files, and runs the manifest's assertions.
#
# Usage:
#   ./run.py                 # run all tests
#   ./run.py NAME [NAME...]  # run named tests
#   ./run.py --list          # list available tests
#   ./run.py --debug NAME    # show MAME window, leave running on failure
#   ./run.py --boot-state    # cold-boot once, save 'shell_ready' state
#   ./run.py --no-state      # don't try to load cached state
#   ./run.py --update-goldens NAME [...]  # record expected outputs
#   ./run.py --window        # show the visible MAME window (default is headless)
#
# Manifest format (JSON):
#   {
#     "name": "fas_nop",
#     "description": "fas assembles nop.s correctly",
#     "command": "fas nop.s -o /root/HI",   # primary autoboot command
#     "post_commands": [],                  # additional commands (rel-frames)
#     "exit_marker": {                      # poll for early exit
#       "addr_hex": "00BF7F",
#       "byte_eq": 1
#     },
#     "timeout_s": 30,
#     "memory_regions": [                   # additional fgxdebug dumps
#       {"name": "fas_buf", "addr_hex": "0D639F", "len": 32},
#       {"name": "posted", "addr_hex": "00B27F", "len": 2, "frame": 30},
#       {"name": "modinit", "addr_hex": "0001C0", "len": 64, "boot_frame": 276}
#     ],
#     # "frame" is relative to the autoboot PASTE; "boot_frame" is ABSOLUTE,
#     # counted from reset, and is the only one that can name a moment before
#     # the paste (module init, driver bring-up).  Absolute is also the axis
#     # capture_log, watch_log and every "sampled_at_frame" are stamped on, and
#     # the dump carries "paste_frame" so the two convert.
#     "expect": {
#       "exit_clean": true,                 # MAME exited via marker, not SIGTERM
#       "disk_files": [
#         {"path": "/root/HI", "sha256": "abc...", "size": 28}
#       ],
#       "faslog_contains": ["main:fwrite done"],
#       "memory": [
#         {"name": "fas_buf", "hex_starts_with": "46475831"},
#         {"name": "vc1buf", "ascii_contains": "QQZVC1"},   # 7-bit text
#         {"name": "shr_full", "sha256": "…"}   # golden; record w/ --update-goldens
#       ],
#       "registers": {"DB_hex": "02"}
#     }
#   }

import argparse
import contextlib
import hashlib
import io
import json
import os
import socket
import re
import shlex
import shutil
import signal
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths.
HERE        = Path(__file__).resolve().parent
REPO        = HERE.parent.parent
TESTS_DIR   = HERE / "tests"
STATE_DIR   = HERE / "state"
PLUGINS_DIR = HERE / "plugins"
# THE SUITE'S BOOT IMAGE, WHICH IS THE UFS ONE NOW (2026-09-04).
#
# It was disk/fgxroot.fs while the campaign moved the suite off ProDOS one
# manifest at a time, and the override existed so both images stayed runnable
# from the same tree while that was true.  It stopped being true when ProDOS
# left the boot path: disk/fgxroot.fs has no filesystem module to read itself with
# and does not boot, so a default pointing at it would fail 246 manifests for
# a reason none of them is about.
#
# THOSE 246 ARE NOT ProDOS TESTS.  They test fork, signals, the tty, ptys and
# the network, and ProDOS was only the medium they booted from -- which is why
# the flip is a migration and not a cull.  Measured before it: eight sampled at
# random, seven passed on the UFS image with no edit at all.
#
# FGX_DISK_BASE still names another image, and still participates in the
# green-result cache key (_hash_file below), so a run against one image can
# never report a cached pass from the other.
DISK_BASE   = REPO / os.environ.get("FGX_DISK_BASE", "disk/fgxroot.fs")
KERNEL_LST  = REPO / "build" / "fgx_S01_KernelMain_Output.txt"
# The TTY BANK's own listing.  A check that wants `ttys[].t_pgrp' has to read
# this one: the field moved out of the core kernel at apple/fgx#108 T3 stage 1c.
TTY_LST     = REPO / "build" / "fgxtty_Output.txt"
FAR_LST     = REPO / "build" / "fgxfar_Output.txt"

# Legacy shared config path.  run.py now writes the plugin config into the
# per-test scratch dir and points MAME at it via FGX_DEBUG_CONFIG (parallel
# runs no longer race); the plugin falls back to this /tmp path only for
# external invocations that don't set the env var (e.g. kprobe.py).
CFG_PATH    = Path("/tmp/fgx_debug_config.json")
# dump JSON, stdout, stderr — written per-test to scratch dirs.
# (Globals retained only for the old fas_diag.sh path; new code reads
#  from <scratch>/dump.json, <scratch>/mame_stdout.log etc.)

# Ample install (where MAME binary + roms live).  MAME's -pluginspath
# is a single dir, not a search list; we sync our patched fgxdebug into
# the user's install at startup so MAME can find both our additions
# AND the system plugins (json, console, etc.) it depends on.
MAME        = os.environ.get("MAME", "/Applications/Ample.app/Contents/MacOS/mame64")
AMPLE_SUP   = Path(os.environ.get("FGX_MAME_SUPPORT",
                                  str(Path.home() / "Library/Application Support/Ample")))
AMPLE_PLUGINS = AMPLE_SUP / "plugins"
USER_FGXDBG   = AMPLE_PLUGINS / "fgxdebug"

# Boot configuration.  FGX_MAME_BOOT_S overrides the seconds-to-shell-prompt
# estimate (autoboot_delay + paste/snapshot frame).
#
# 60 s, and what it has to clear is the CONSOLE SHELL's prompt rather than the
# last boot message.  init runs /etc/rc -- the modules, netstart, syslogd,
# update and inetd -- to COMPLETION before any line starts, and rc waits for
# syslogd to read the boot log out of /dev/klog (measured: the prompt arrives
# between 54 and 55 s), and the console line
# then loads /bin/sh, which is the last thing on the machine to say anything:
# ttyv1's getty is at `login: ' well before the console reaches `fgx# '.  The
# autoboot command is typed on a fixed schedule, not when the prompt appears,
# so past the estimate it lands in a console that is not reading yet and is
# simply lost -- the test then times out having produced no output at all,
# which reads like the program crashing rather than like a boot that was still
# going.  The tests that inject keys at fixed frames after the paste are the ones
# that notice first.
#
# A test whose own boot is heavier than this says so with "boot_s", which can
# only RAISE the estimate: a smaller one is ignored, since a paste before the
# prompt types into a console that is not reading yet.
#
# Counted in EMULATED frames under -nothrottle (see the autoboot_delay note
# below), so the cost is far less than the wall clock the number suggests.
BOOT_FRAMES_FRESH  = int(os.environ.get("FGX_MAME_BOOT_S", "60")) * 60
BOOT_FRAMES_LOADED = 180          # 3s — only used if/when state-load
                                  # gains a working keyboard-input path.
STATE_NAME = "shell_ready"        # save-state slot name

# Emulator overrides:
#   FGX_MAME_HDSLOT   slot-7 boot device (default retronet, the A2retroNET
#                     SmartPort card in stock MAME and Ample; cffa2 also
#                     boots).  "microdrive" (ReActiveMicro MicroDrive/Turbo)
#                     is EXPERIMENTAL: no published MAME has the device, and
#                     the image -> .mdt CF-card wrap needs mdttool.  It is the
#                     EXTENDED-SmartPort card ($CnFB=$80), the only one here
#                     that does multi-block reads at speed; its bios= suffix
#                     and the wrap are applied automatically.  Tests naming
#                     "boot_device": "microdrive" or the Second Sight card
#                     need the same unpublished MAME.
#   FGX_MAME_PRIMARY  how the PRIMARY command reaches the shell:
#                     "autoboot" (default) = MAME -autoboot_command natural
#                     typing; "inject" = the fgxdebug kernel-ring injection
#                     (use when the build's natural typing never reaches
#                     FGX, e.g. Ample's stock mame64 0.268).
HDSLOT_DEVICE  = os.environ.get("FGX_MAME_HDSLOT", "retronet")
# The MicroDrive is a CF-card device: it needs a bios= and an image wrapped by
# mdttool, not a raw image.  Keyed off the device name so FGX_MAME_HDSLOT stays
# one plain word.
IS_MICRODRIVE  = HDSLOT_DEVICE.split(",")[0] == "microdrive"
if IS_MICRODRIVE and "," not in HDSLOT_DEVICE:
    HDSLOT_DEVICE += ",bios=iigs"


def _hdslot_for(manifest):
    """The slot-7 card THIS test runs on: (device string, is-microdrive).

    A manifest may name its own card with `"boot_device": "microdrive"`, and
    apple/fgx#257 is why it can.  `mdboot' is the only test that exercises the
    one card which REFUSES the generic Read ($48) -- so it is the only cover for
    _SP_ReadBlockN's @sprbn_err -- and it selected that card through the
    FGX_MAME_HDSLOT ENVIRONMENT, which meant it could not simply join
    GATE_TESTS: the gate does not set that variable, so the test would SKIP, and
    a skipping test in the gate reads as coverage while providing none.

    This is the rule the extra_hards comment below already states, applied to
    the card: a test that needs particular hardware should SAY SO ITSELF rather
    than depend on the runner's environment being set up beforehand.  The env
    var still works and still sets the default for every test that expresses no
    preference.
    """
    want = manifest.get("boot_device")
    if want in (None, "floppy"):
        return HDSLOT_DEVICE, IS_MICRODRIVE
    dev = want
    if dev.split(",")[0] == "microdrive" and "," not in dev:
        dev += ",bios=iigs"
    return dev, dev.split(",")[0] == "microdrive"
MDTTOOL = Path(os.environ.get("MDTTOOL") or shutil.which("mdttool") or "mdttool")
PRIMARY_INPUT  = os.environ.get("FGX_MAME_PRIMARY", "autoboot")
PRIMARY_INPUTS = ("autoboot", "inject")


def _primary_for(manifest):
    """How THIS test's primary command reaches the shell.

    The rule `_hdslot_for` states for the card, applied to the input path: a
    test whose RESULT IS A TIMING should say so itself rather than depend on
    the runner's environment being set up beforehand.

    "autoboot" hands the command to MAME's natural keyboard, which types it one
    character at a time -- measured at 6.24 frames (104 ms) per character, so a
    146-character command carries 755 frames that are not the workload, and a
    pc_sample profile spends 42% of its samples idling at `swtch's WAI between
    keystrokes instead of 10%.  "inject" pokes the bytes into `_kKbdRing' in a
    single frame, so the measured interval is the workload -- at the cost of
    the path it skips: ADB, the heartbeat's key poll, and the vt100
    translation that only `raw_inject' goes through.  So a test covering the
    keyboard or the tty input path wants "autoboot"; one that reports a number
    wants "inject".

    An unrecognised value is fatal rather than a quiet fall back to the
    default.  Falling back is the exact failure this key exists to stop, and it
    would look like a clean run.
    """
    want = manifest.get("primary_input") or PRIMARY_INPUT
    if want not in PRIMARY_INPUTS:
        fatal(f"primary_input: {want!r} is not one of "
              f"{', '.join(PRIMARY_INPUTS)} (manifest key or FGX_MAME_PRIMARY)")
    return want


# ---------------------------------------------------------------------------
def colour(s, code):
    if not sys.stdout.isatty(): return s
    return f"\x1b[{code}m{s}\x1b[0m"

OK_   = lambda s: colour(s, "32")
FAIL_ = lambda s: colour(s, "31")
DIM_  = lambda s: colour(s, "2")
BOLD_ = lambda s: colour(s, "1")


def fatal(msg):
    print(FAIL_("ERROR: ") + msg, file=sys.stderr)
    sys.exit(1)


def ensure_toolchain_fixture(hostp):
    """Build a staged toolchain fixture binary if it is not on disk.

    toolchain/tests/M*/<name>.expected.bin is a BUILD PRODUCT, not a
    checked-in file: fcc stopped committing them (each is merlin32 + fgx_ld
    over the committed .expected.s plus the libc pile, so a one-line libc
    change rewrote ~544 blobs every time).  Two tests stage one as their
    payload -- lc_malloc and for_long_init -- so build it on demand instead
    of requiring that someone happened to run the toolchain fixture suite
    first.  On a fresh clone nobody has, and the failure looked like a
    kernel regression rather than a missing artifact.

    No-op for any other staged file, and for a fixture already present.
    """
    p = Path(hostp)
    if p.exists() or not p.name.endswith(".expected.bin"):
        return
    if "toolchain/tests/" not in p.as_posix():
        return
    runner = REPO / "toolchain" / "tests" / "run.sh"
    if not runner.exists():
        return
    name = p.name[:-len(".expected.bin")]
    print(DIM_(f"  building toolchain fixture {name} (derived; not committed)"))
    subprocess.run(["bash", str(runner), name], cwd=str(REPO / "toolchain"),
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


# ---------------------------------------------------------------------------
def sync_plugin():
    """Copy the repo's fgxdebug plugin to the user's MAME plugins dir.

    MAME's -pluginspath replaces (not appends to) its system plugin
    search dir.  Pointing it at the repo would lose access to the
    system 'json' / 'console' / etc. plugins that fgxdebug depends on.
    Solution: keep the repo as canonical, sync into the user's dir
    each run.  Idempotent — only copies when modified.
    """
    repo_init = PLUGINS_DIR / "fgxdebug" / "init.lua"
    repo_json = PLUGINS_DIR / "fgxdebug" / "plugin.json"
    if not repo_init.exists():
        return  # repo plugin not present — leave user install alone
    if not USER_FGXDBG.exists():
        USER_FGXDBG.mkdir(parents=True)
    for src in (repo_init, repo_json):
        if not src.exists(): continue
        dst = USER_FGXDBG / src.name
        if (not dst.exists()
                or src.stat().st_mtime > dst.stat().st_mtime
                or src.read_bytes() != dst.read_bytes()):
            shutil.copy2(src, dst)


# ---------------------------------------------------------------------------
RESULTS_JOURNAL = HERE / "results.jsonl"   # gitignored; green-result cache


def _is_ufs_image(path):
    """Is this a 2.11BSD volume?  ASK fgxfs, rather than re-deriving it here.

    The first cut read the superblock inline and got it wrong: byte 512 of the
    image is zeros, because the filesystem does not start at the image's second
    block.  fgxfs.py already knows where it lives and is the tree's independent
    implementation of the format -- the whole point of which is that nothing
    else re-implements it.  A second, subtly different reader in the harness is
    the failure this project keeps naming.

    A ProDOS volume fails it the same way the kernel's own mount does.
    """
    try:
        r = subprocess.run(
            [sys.executable, str(REPO / "tools" / "fgxfs.py"), "ls",
             str(path), "/"],
            capture_output=True, text=True, timeout=30)
    except Exception:                                        # noqa: BLE001
        return False
    return r.returncode == 0


def _hash_file(h, p):
    """Fold file bytes into hasher h (absent file folds a marker)."""
    try:
        h.update(Path(p).read_bytes())
    except OSError:
        h.update(b"<absent:%s>" % str(p).encode())


def _env_key(h):
    """Fold behavior-affecting env vars into the key."""
    # FGX_MAME_HDSLOT/BOOT_S must be here: the boot device changes what is
    # actually exercised (and how long boot takes), so without them a run on
    # one card silently reuses another card's cached PASS.
    for var in ("FGX_EXTRA_HARDS", "FGX_MAME_A2CFG",
                "FGX_MAME_HDSLOT", "FGX_MAME_BOOT_S"):
        h.update(f"{var}={os.environ.get(var, '')};".encode())


def _shared_inputs_hash(no_state):
    """Hash of the run-wide inputs every test depends on: the disk image,
    the warm boot state (unless cold-booting), the harness env knobs.
    A warm state holds the booted KERNEL in RAM, so it must key results
    (run.py --no-state exists for exactly that reason)."""
    h = hashlib.sha256()
    _hash_file(h, DISK_BASE)
    if not no_state:
        _hash_file(h, STATE_DIR / "apple2gs" / f"{STATE_NAME}.sta")
    _env_key(h)
    return h.hexdigest()


# EVERY TEST BOOT TURNS THE OPTIONAL DEVICES AND DAEMONS ON.  The image's own
# /etc/rc.local ships them commented out; the suite tests them, so each boot
# stages this one over it, first, before the manifest's own stage_files.
TEST_RC_LOCAL = {"host": "tools/mame_test/rc.local", "prodos_dir": "/FGX/ETC",
                 "name": "rc.local"}


def stage_list(m):
    """The files a test stages: the test rc.local, then the manifest's."""
    return [TEST_RC_LOCAL] + m.get("stage_files", [])


def _test_input_key(manifest_path, m, shared_hash):
    """Per-test input key: run-wide hash + this test's manifest bytes +
    every file it stages + its check_script.  Conservative: any byte
    change anywhere in the inputs invalidates the cached result."""
    h = hashlib.sha256()
    h.update(shared_hash.encode())
    _hash_file(h, manifest_path)
    # Resolved as staging resolves it: a relative `host' names a file under
    # REPO, and read from the caller's directory it hashed as <absent>, so a
    # rebuilt staged binary kept the verdict of the one it replaced.
    for sf in stage_list(m):
        _sp = Path(sf["host"])
        _hash_file(h, _sp if _sp.is_absolute() else REPO / sf["host"])
    # A SECOND SPINDLE IS AN INPUT, AND THE KEY COULD NOT SEE IT.  `extra_hards'
    # names a path in the manifest, so the manifest bytes above pin the NAME and
    # nothing pinned the CONTENT: rebuilding disk/ufsscratch.fs with a different
    # layout left every verdict that read it cached against the volume it
    # replaced.  (The test that caught it, `mountprobe', is retired; the hole
    # it found is not, and the next `extra_hards' user inherits the fix.)
    # It matters more now that a run can write to its staged copy -- the verdict
    # is then a claim about those exact bytes.  (FGX_EXTRA_HARDS is folded in by
    # _env_key as a NAME only, for the same reason DISK_BASE is hashed here.)
    for _img in (m.get("extra_hards") or []):
        _p = Path(_img)
        _hash_file(h, _p if _p.is_absolute() else REPO / _img)
    cs = m.get("expect", {}).get("check_script")
    if cs:
        _hash_file(h, HERE / cs)
    # The host-side program is as much an input as a staged file: editing the
    # probe must invalidate the cached PASS, or a weakened probe inherits the
    # strong one's green.  Hash every argument that names a real file, which
    # covers the script without having to know its position in the command.
    for arg in m.get("host_proc", {}).get("cmd", []):
        if (REPO / str(arg)).is_file():
            _hash_file(h, REPO / str(arg))
    # An EXTERNAL peer is an input too, and it is the one the key could not
    # otherwise see: a `requires.tcp' test is fed by a program this harness
    # never launches, so weakening that program would inherit the strong run's
    # cached PASS.  The manifest names it -- declared, never inferred, like
    # every other requirement -- and a named file that does not exist is a
    # manifest error rather than a silently unhashed input.
    peer = (m.get("requires") or {}).get("peer_script")
    if peer:
        if not (REPO / peer).is_file():
            fatal(f"{m.get('name')}: requires.peer_script {peer} does not exist")
        _hash_file(h, REPO / peer)
    return h.hexdigest()


def _journal_green_keys():
    """Set of input keys with a recorded PASS."""
    keys = set()
    try:
        for line in RESULTS_JOURNAL.read_text().splitlines():
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            if rec.get("ok"):
                keys.add(rec.get("key"))
    except OSError:
        pass
    return keys


def _default_jobs():
    """How many tests to run at once when -j is not given.

    Half the logical CPUs, capped at 8.  Each test is one MAME process pinned to
    roughly one core, so the cap is about leaving the machine usable rather than
    about correctness -- and about not turning every test into a timing outlier.
    Measured on a 16-logical/12-performance-core box: -j1 ~20-30 min, -j6 146 s,
    -j10 93 s, all with identical results.  Override with -j1 to serialise.
    """
    try:
        n = os.cpu_count() or 1
    except NotImplementedError:
        n = 1
    return max(1, min(8, n // 2))


class _ThreadStdout:
    """sys.stdout replacement that routes each thread's writes to its own buffer.

    contextlib.redirect_stdout swaps a GLOBAL, so under --jobs the threads fight
    over it: output lands in whichever buffer happened to be installed, and one
    test's assertions print under another's header.  Measured, not theorised --
    that is exactly what the first cut of this did.  A proxy that dispatches per
    thread is the fix; a thread with no buffer registered (the main thread)
    writes straight through to the real stdout.
    """
    def __init__(self, real):
        self._real = real
        self._tl = threading.local()

    def _target(self):
        return getattr(self._tl, "buf", None) or self._real

    def bind(self, buf):     self._tl.buf = buf
    def unbind(self):        self._tl.buf = None

    def write(self, s):      return self._target().write(s)

    def flush(self):
        tgt = self._target()
        if hasattr(tgt, "flush"):
            tgt.flush()

    def __getattr__(self, name):
        return getattr(self._real, name)


def _journal_append(name, key, ok):
    try:
        with open(RESULTS_JOURNAL, "a") as f:
            json.dump({"test": name, "key": key, "ok": bool(ok),
                       "ts": int(time.time())}, f)
            f.write("\n")
    except OSError:
        pass                       # journal is best-effort, never fatal


def discover_tests():
    if not TESTS_DIR.exists():
        return []
    return sorted([p for p in TESTS_DIR.glob("*.json")])


# Every TOP-LEVEL manifest key run.py actually consumes.  Derived from the
# `manifest.get(...)` / `manifest[...]` sites rather than written from memory --
# a hand-kept list drifts, and a key this set is missing would be rejected
# spuriously, which is a worse failure than the one it prevents.
#
# WHY THIS EXISTS (apple/fgx#24).  check_expectations already rejects unknown
# keys INSIDE `expect`.  Nothing checked the level ABOVE it, and that is the one
# that bit: `check_script` written at the top level instead of inside `expect`
# was dropped without a word, and the test reported PASS with its entire checker
# never invoked.  The manifest read exactly like a test with a checker, and the
# run output has no line saying a checker ran -- so "no check_script line" looks
# identical to a passing check.
KNOWN_MANIFEST_KEYS = {
    "name", "description", "command", "timeout_s", "expect",
    "memory_regions", "post_commands", "post_gap_frames", "exit_on_prompt",
    "raw_inject", "capture_writes", "stage_files", "pc_sample", "boot_device",
    "mame_slots", "extra_hards", "cycle_markers", "disk_image", "exit_marker",
    "boot_s", "primary_input",
    "fresh_nvram", "serial",
    "out_path", "paste_mode", "png_snapshot", "requires", "stack_excursion",
    "use_state", "watch_addrs", "watch_min",
    "warm_reset_frame", "warm_settle_frames", "poison", "host_proc",
    "ram_poison_seed", "ram_poison_top_bank",
    "ram_poison_win_lo", "ram_poison_win_hi",
    # Injected by run.py itself, not written by manifest authors.
    "_exit_reason", "_no_state", "_hostproc",
}


def _selftest_manifest_keys():
    """The guard must fire, and must not fire on the real corpus.

    A validator that accepts everything is the defect it exists to prevent, one
    level up -- so this drives it both ways, and then over every TRACKED
    manifest, which is what proves the key set is complete rather than merely
    plausible.
    """
    import glob
    fails = []
    if check_manifest_keys({"name": "x", "command": "sh", "expect": {}}, "t"):
        fails.append("a valid manifest was rejected")
    bad = check_manifest_keys({"name": "x", "chekc_script": "y.py"}, "t")
    if not bad:
        fails.append("a misspelled top-level key was accepted")
    # THE CASE THAT PRODUCED apple/fgx#24's second half: an expect-key written
    # at the top level.  The message must SAY so, not merely reject it.
    bad = check_manifest_keys({"name": "x", "check_script": "y.py"}, "t")
    if not bad or "INSIDE" not in bad[0]:
        fails.append("check_script at the top level was not diagnosed as "
                     "belonging inside 'expect'")
    # THE REGION KEYS, driven both ways for the same reason.  A region's keys
    # are read nowhere else, so a misspelling is silent -- and the pair that
    # actually gets confused is "frame" against "boot_frame", which are two
    # different time axes (see the sample-frame block in build_plugin_config).
    ok_region = {"memory_regions": [{"name": "r", "addr_hex": "00", "len": 4,
                                     "boot_frame": 276}]}
    if check_region_keys(ok_region, "t"):
        fails.append("a valid memory_region was rejected")
    if not check_region_keys({"memory_regions": [{"name": "r", "frmae": 3}]}, "t"):
        fails.append("a misspelled region key was accepted")
    if not check_region_keys({"memory_regions": [{"addr": 0}]}, "t"):
        fails.append("a memory_region with no name was accepted")
    both = check_region_keys(
        {"memory_regions": [{"name": "r", "frame": 3, "boot_frame": 3}]}, "t")
    if not both or "different axes" not in both[0]:
        fails.append("a region setting both frame and boot_frame was not "
                     "diagnosed as mixing axes")
    # THE SYMBOL RESOLVER, DRIVEN AGAINST THE LINE THAT BROKE IT.  A region
    # names a symbol and never carries its number, so a resolver that answers
    # with the wrong address does not fail -- it dumps four bytes of OPCODE and
    # they decode to a plausible number.  Merlin's force-absolute prefix puts a
    # pipe inside an operand, and the listing is pipe-delimited, so a greedy
    # match walked past the source-line column and took the INSTRUCTION's
    # address.  Measured 2026-08-27 on `_hbDpKernSched': $6E51 for a cell at
    # $7065.  The code line is FIRST here on purpose; the resolver returns its
    # first match, which is how the bug presented.
    import tempfile
    lst = ("32261 | 48 ../kernel/toolbox.s 423 | Code | 00 | | 3 | "
           "02/6E51 : 8D 65 70    |                               STA"
           "              |_selfTestCell\n"
           "32695 | 48 ../kernel/toolbox.s 857 | Data | 00 | | 4 | "
           "02/7065 : 00 00 00 00 | _selfTestCell                 DS"
           "               4\n")
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as fh:
        fh.write(lst)
        fake = Path(fh.name)
    try:
        got = _kernel_symbol("_selfTestCell", fake)
        if got != 0x7065:
            fails.append("_kernel_symbol resolved a symbol to %s, not its data "
                         "definition at $7065 -- an operand's force-absolute "
                         "pipe was read as the label column"
                         % ("$%04X" % got if got else got))
        if _kernel_symbol("_notInTheListing", fake) is not None:
            fails.append("_kernel_symbol invented an address for a symbol that "
                         "is not in the listing")
    finally:
        fake.unlink()
    for f in sorted(glob.glob(str(TESTS_DIR / "*.json"))):
        with open(f) as fh:
            data = json.load(fh)
        where = os.path.basename(f)
        fails.extend(check_manifest_keys(data, where))
        fails.extend(check_region_keys(data, where))
    if fails:
        for f in fails:
            print("  " + f, file=sys.stderr)
        print("run.py manifest-key self-test: %d FAILURE(S)" % len(fails))
        return 1
    print("run.py manifest-key self-test: OK (rejects unknown and misplaced "
          "keys and unknown/mixed-axis region keys, accepts every tracked "
          "manifest, and resolves a symbol to its DEFINITION and not to an "
          "operand that mentions it)")
    return 0


# Region sub-keys, for the same reason KNOWN_MANIFEST_KEYS exists one level up:
# nothing else reads a memory_region, so a misspelling is DEAD and the region
# silently falls back to a plain end-of-run read of address 0.  That is not
# hypothetical -- "frame" vs "boot_frame" is exactly the pair a tired reader
# gets wrong, and a dropped sample frame reads identically to a successful
# capture of the wrong moment (apple/fgx#183).
KNOWN_REGION_KEYS = {
    "name", "len", "frame", "boot_frame",
    "addr", "addr_hex", "ptr_addr", "ptr_addr_hex", "symbol", "addr_equ",
    "kbank", "farbank", "conbank", "vcbank", "modbank", "ttybank",
}


def check_region_keys(data, where):
    """Return complaint strings for unknown or contradictory region keys."""
    out = []
    for r in data.get("memory_regions", []) or []:
        nm = r.get("name", "<unnamed>")
        if "name" not in r:
            out.append("%s: a memory_region has no \"name\"; nothing can "
                       "assert on it and the dump cannot label it." % where)
        unknown = sorted(set(r) - KNOWN_REGION_KEYS)
        if unknown:
            out.append("%s: memory_region %r has unknown key(s) %s. Nothing "
                       "reads them, so whatever they configure is DEAD and the "
                       "region falls back to an end-of-run read."
                       % (where, nm, ", ".join(repr(k) for k in unknown)))
        if "frame" in r and "boot_frame" in r:
            out.append("%s: memory_region %r sets both \"frame\" "
                       "(paste-relative) and \"boot_frame\" (absolute). "
                       "They are different axes; pick one." % (where, nm))
        # A LITERAL OFFSET INTO THE KERNEL BANK IS REFUSED.  apple/fgx#123, and
        # the reason is _kernel_symbol's docstring: the address goes stale the
        # moment anything resizes the kernel, and a stale region reads a
        # serene, wrong value rather than failing.  Measured on this corpus --
        # the #105 counter probe went stale three times, and allocwarm's region
        # pointed at FGX_DATA's old address and reported PASS from dead memory.
        #
        # THE POINT IS TO MAKE THE GOOD FORM THE ONLY FORM, not to validate the
        # bad one more carefully: a checker that verified a literal against the
        # listing was shipped once and deleted in the same change that removed
        # the literals, because it guarded a problem that only exists if you
        # write the literal.  Both good forms resolve per build -- `symbol' from
        # the assembler listing, `addr_equ' from the include sources -- and
        # between them they cover everything this corpus needed.
        if r.get("kbank") and ("addr_hex" in r or "addr" in r):
            out.append("%s: memory_region %r is a kernel-bank region with a "
                       "LITERAL address. Name it instead: \"symbol\" for a "
                       "label in the assembler listing, or \"addr_equ\" for an "
                       "EQU in include/ (FGX_TASK_TBL is an EQU, not a label, "
                       "which is why these were the last fifteen to convert). "
                       "A literal offset goes stale on any kernel resize and "
                       "reads a wrong value rather than failing."
                       % (where, nm))
    return out


def check_manifest_keys(data, where):
    """Return a list of complaint strings for unknown top-level keys."""
    unknown = sorted(set(data) - KNOWN_MANIFEST_KEYS)
    if not unknown:
        return []
    hint = ""
    inner = [k for k in unknown if k in KNOWN_EXPECT_KEYS]
    if inner:
        hint = (" -- %s belong(s) INSIDE \"expect\", not at the top level"
                % ", ".join(repr(k) for k in inner))
    return ["%s: unknown top-level key(s) %s%s. Nothing reads them, so whatever "
            "they configure is DEAD and the test still reports PASS."
            % (where, ", ".join(repr(k) for k in unknown), hint)]


def load_manifest(path):
    with open(path) as f:
        data = json.load(f)
    if "name" not in data:
        data["name"] = path.stem
    bad = check_manifest_keys(data, path.name) + check_region_keys(data, path.name)
    if bad:
        fatal("\n".join(bad))
    return data


# ---------------------------------------------------------------------------
_KBD_SYMS = ("_kKbdRing", "_kKbdRingHead", "_kKbdRingCount", "_kKbdInjectRaw")

# Virtual-console statics the plugin needs to dump the console the user is
# actually looking at.  _kConsoleBank is the LIVE framebuffer bank and moves on
# every VC switch; _kVcBank[] is the per-VC registry, so a test can ask for a
# specific console's buffer rather than only the active one.  Scraped, never
# hardcoded, for the same reason the keyboard cells are (see below).
_VC_SYMS = ("_kConsoleBank", "_kVcBank", "_kVcActive")

# _modBankTab[ordinal] -> the real bank Mod_Load put that module in.  Scraped so
# a test can dump a LOADED MODULE'S IMAGE without baking the bank the allocator
# happened to hand out (apple/fgx#110).
_MOD_SYMS = ("_modBankTab",)


def _kernel_symbol(name, lst=None):
    """Address of a kernel-bank symbol, read from the assembler listing.

    A hardcoded probe address is a landmine: it goes stale the moment anything
    resizes the kernel, and a stale probe reads a serene, wrong zero rather than
    failing.  This project has lost a debugging session to exactly that.  The
    listing already carries every symbol's assembled address and is rebuilt with
    the kernel, so a test can name the symbol and never carry the number.

    Returns None if the listing is absent (fresh clone) or the symbol is not in
    it -- callers report that rather than guessing.
    """
    lst = lst or KERNEL_LST
    if not lst.exists():
        return None
    # `[^|]*` AND NOT `.*`, WHICH IS THE WHOLE POINT.  The listing is
    # pipe-delimited and the SOURCE-LINE field is everything after the first
    # pipe that follows the `BB/AAAA` address -- so the name has to appear in
    # that field's LABEL column to be a definition.  A greedy `.*\|` instead
    # walks to the LAST pipe on the line, and Merlin's force-absolute prefix
    # puts one inside an operand: `STA |_hbDpKernSched` then matched as though
    # it were the label, and the symbol resolved to the address of that
    # INSTRUCTION.  Measured 2026-08-27: $6E51 (code) for a cell at $7065, and
    # the region dumped four bytes of opcode as data.  That is the failure this
    # function's own docstring exists to prevent -- apple/fgx#236's shape, from
    # the other direction -- and it is silent, because opcodes decode to
    # plausible numbers.
    pat = re.compile(r"\b([0-9A-F]{2})/([0-9A-F]{4})\b[^|]*\|\s*" + re.escape(name) + r"\s")
    with open(lst, errors="replace") as f:
        for line in f:
            if name not in line:
                continue
            m = pat.search(line)
            if m:
                return int(m.group(2), 16)
    return None

_CONFIG_S = Path(__file__).resolve().parent.parent.parent / "include" / "config.s"
_ADDR_EXPR = re.compile(r"^\s*(CFG_[A-Z0-9_]+)\s*(?:([+-])\s*\$?([0-9A-Fa-f]+))?\s*$")


def _addr(spec):
    """A probe address: a bare hex string, or `CFG_NAME` / `CFG_NAME+hex`.

    THE BANK-0 LAYOUT MOVES.  It is derived from kernel.nproc
    (tools/ninja/genconfig.py), so every per-pid address in bank 0 shifts when
    the task count does -- and a probe that baked one in does not fail, it reads
    a serene, wrong value from whatever now lives there.  That is not
    hypothetical: 22 manifests pointed at the kernel DP page as a literal
    $00B5B0, and several probes still name $00B7xx, which was the DP base
    before 2026-08-05.

    So a probe can name the constant instead: "CFG_DP_KKERN+B0" is the kernel
    log pointer wherever the DP block happens to be.  An unknown name is a hard
    error -- resolving it to zero is precisely the failure being prevented.
    """
    if isinstance(spec, int):
        return spec
    m = _ADDR_EXPR.match(spec)
    if not m:
        return int(spec, 16)
    name, sign, off = m.group(1), m.group(2) or "+", m.group(3)
    cfg = _CONFIG_S.read_text(errors="replace")

    # CFG_STK_ARENA_TOP is SYNTHETIC: the arena's ceiling, not an EQU.
    #
    # A tap inside a stack LANE has to be anchored to the top, because a lane
    # sits at ARENA + (ARENA_PAGES - LANE_PAGES) * 256 and therefore moves with
    # the ceiling, not the floor.  Spelling that as a base-anchored offset is
    # how apple/fgx#104 happened: !157 re-anchored the b3park/b3pty CHECKERS to
    # ARENA_TOP and left their MANIFESTS on CFG_STK_ARENA+4A70.  The two agreed
    # exactly at NPROC=11 and silently diverged by one page the moment the
    # arena changed size, so the plugin captured writes at one address while
    # the checker asked about another.
    if name == "CFG_STK_ARENA_TOP":
        base_m = re.search(r"^\s*CFG_STK_ARENA\s+EQU\s+\$([0-9A-Fa-f]+)",
                           cfg, re.MULTILINE)
        pages_m = re.search(r"^\s*CFG_STK_ARENA_PAGES\s+EQU\s+(\d+)",
                            cfg, re.MULTILINE)
        if not (base_m and pages_m):
            fatal("probe address 'CFG_STK_ARENA_TOP': CFG_STK_ARENA / "
                 "CFG_STK_ARENA_PAGES are not both in include/config.s")
        base = int(base_m.group(1), 16) + int(pages_m.group(1)) * 256
        delta = int(off, 16) if off else 0
        return base + delta if sign == "+" else base - delta

    mm = re.search(rf"^\s*{name}\s+EQU\s+(\$[0-9A-Fa-f]+|\d+)(?=\s|;|$)",
                   cfg, re.MULTILINE)
    if not mm:
        fatal(f"probe address '{spec}': {name} is not in include/config.s -- "
             f"it was renamed, or the config was not generated. Refusing to "
             f"guess: a wrong address here reads as a passing test.")
    tok = mm.group(1)
    base = int(tok[1:], 16) if tok.startswith("$") else int(tok)
    delta = int(off, 16) if off else 0
    return base + delta if sign == "+" else base - delta


_SRC_EQU_FILES = ("include/kfar.s", "include/console.s", "include/kernel.s",
                  "include/memmap.s", "include/ktty.s")
_SRC_EQU_EXPR = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)"
                           r"(?:\s*\+\s*([A-Za-z_][A-Za-z0-9_]*|\$?[0-9A-Fa-f]+))?\s*$")


def _src_equ(spec):
    """Resolve `NAME` or `NAME+NAME` / `NAME+hex` from the include sources.

    _addr() reads include/config.s, which only carries the CFG_* layout
    derived from kernel.nproc.  Far-bank addresses are not in there: they are
    ordinary EQUs in include/kfar.s (the region base) and include/console.s
    (the field offset within it).

    READ FROM SOURCE, NOT CARRIED IN THE MANIFEST.  A manifest that spelled
    the offset as a literal is exactly how vccursor came to read a cell that
    had moved (apple/fgx#102): apple/fgx!159 relocated _conTopRow out of the direct
    page, the manifest kept the old address, the stale read returned 0, and 0
    happens to reproduce the pre-apple/fgx#94 behaviour -- so the check went on
    passing while the fix it was written to hold in place was inert.

    An unknown name is a hard error.  Resolving it to zero is the failure.
    """
    m = _SRC_EQU_EXPR.match(spec)
    if not m:
        fatal(f"far-bank address '{spec}': expected NAME or NAME+NAME/hex")
    total, parts = 0, [g for g in m.groups() if g]
    for part in parts:
        if re.fullmatch(r"\$?[0-9A-Fa-f]+", part) and not re.match(
                r"^[A-Za-z_]", part.lstrip("$")):
            total += int(part.lstrip("$"), 16)
            continue
        for rel in _SRC_EQU_FILES:
            src = REPO / rel
            if not src.exists():
                continue
            mm = re.search(rf"^\s*{part}\s+EQU\s+(\$[0-9A-Fa-f]+|\d+)(?=\s|;|$)",
                           src.read_text(errors="replace"), re.MULTILINE)
            if mm:
                tok = mm.group(1)
                total += int(tok[1:], 16) if tok.startswith("$") else int(tok)
                break
        else:
            fatal(f"far-bank address '{spec}': {part} is not an EQU in any of "
                 f"{', '.join(_SRC_EQU_FILES)} -- it was renamed or moved. "
                 f"Refusing to guess: a wrong address here reads as a pass.")
    return total


def kbd_ring_offsets():
    """Kernel-bank offsets of the keyboard-ring cells, read from the kernel
    listing.

    The fgxdebug plugin injects scripted keystrokes by poking these cells
    directly.  They used to be hardcoded in init.lua, which silently rotted
    the moment kernel data grew: the constants said $E732/$E742/$E746/$E748
    while the kernel had moved them to $EC72/$EC82/$EC86/$EC88, so every
    post_command was written into dead memory and never typed.  Nothing
    failed loudly — tests whose assertions the PRIMARY autoboot command
    already satisfied still passed.  Derive them instead, so a kernel data
    move can never quietly disable scripted input again.

    Returns {} if the listing is absent (fresh clone, no build yet); the
    plugin keeps its built-in constants as a fallback in that case.
    """
    if not KERNEL_LST.exists():
        return {}
    want = {s: None for s in _KBD_SYMS + _VC_SYMS + _MOD_SYMS}
    pat = re.compile(r"\b([0-9A-F]{2})/([0-9A-F]{4})\b.*\|\s*"
                     r"(_k(?:Kbd|Console|Vc)\w+|_modBankTab)\s")
    _prefilter = ("_kKbd", "_kConsoleBank", "_kVcBank", "_kVcActive",
                  "_modBankTab")
    with open(KERNEL_LST, errors="replace") as f:
        for line in f:
            if not any(t in line for t in _prefilter):
                continue
            m = pat.search(line)
            if m and m.group(3) in want and want[m.group(3)] is None:
                want[m.group(3)] = int(m.group(2), 16)
    if any(v is None for v in want.values()):
        missing = ", ".join(k for k, v in want.items() if v is None)
        print(DIM_(f"  warning: {KERNEL_LST.name} has no address for "
                   f"{missing}; plugin falls back to built-in constants"))
        return {}
    return want


def build_plugin_config(manifest, *, mode, paste_frame, primary=None):
    """Build the JSON config the fgxdebug plugin reads at startup."""
    cfg = {
        "dump_frame": 60,
        # test_mode opts in to auto-exit (exit_after_frame / exit_on_prompt /
        # exit_marker) AND input_script.  Without this field the plugin
        # loads passively (memory dumps only) and won't hijack interactive
        # `./build.sh run` sessions even with a stale config file present.
        "test_mode": True,
        # output_path is set per-test by the caller; default kept for
        # backwards compatibility with any external invocation.
        "output_path": "/tmp/fgx_test_dump.json",
    }

    # warm_reset_frame: soft-reset the machine once at this frame, leaving RAM
    # untouched, so the run's assertions describe a WARM boot (apple/fgx#120).
    # A cold boot is the only thing this suite has ever tested, which is how a
    # warm boot that dies could ship.
    if "warm_reset_frame" in manifest:
        cfg["warm_reset_frame"] = int(manifest["warm_reset_frame"])
    if "warm_settle_frames" in manifest:
        cfg["warm_settle_frames"] = int(manifest["warm_settle_frames"])
    # RAM_POISON: fill physical DRAM with seeded garbage before the first
    # instruction, so a run models a COLD boot on real hardware rather than
    # MAME's zero-filled one.  See the plugin's ram_poison block for why the
    # language card and the I/O windows are NOT covered.
    if "ram_poison_seed" in manifest:
        cfg["ram_poison_seed"] = int(manifest["ram_poison_seed"])
    if "ram_poison_top_bank" in manifest:
        cfg["ram_poison_top_bank"] = int(manifest["ram_poison_top_bank"])
    # Window inside the TOP bank only.  The plugin still consumes the stream
    # over skipped bytes, so a window is comparable to the full fill byte for
    # byte -- which is the whole point of bisecting inside a bank.
    if "ram_poison_win_lo" in manifest:
        cfg["ram_poison_win_lo"] = int(manifest["ram_poison_win_lo"])
    if "ram_poison_win_hi" in manifest:
        cfg["ram_poison_win_hi"] = int(manifest["ram_poison_win_hi"])
    if "poison" in manifest:
        # A poison entry may name its target SYMBOL alongside the address.  The
        # BANK byte stays from the literal -- the live kernel bank is not
        # knowable host-side, and at RESET (frame 0) the plugin cannot read it
        # from memory either, because nothing has loaded yet.  The OFFSET is
        # taken from the listing, because that is the half that rots.
        #
        # This matters more than it looks.  allocwarm poisons _taskAllocCur and
        # then proves the poke landed by dumping the region and checking its
        # neighbour DetectedROM is populated.  That only vouches for the poke
        # while BOTH addresses move together: converting just the dump to a
        # symbol left the poison on a literal, so the next kernel resize would
        # have given a serene green for a poke into dead memory.
        pois = []
        for p_ in manifest["poison"]:
            p_ = dict(p_)
            sym = p_.pop("symbol", None)
            if sym is not None:
                off = _kernel_symbol(sym)
                if off is None:
                    fatal(f"poison: symbol {sym} not found in "
                          f"{KERNEL_LST.name} -- rebuild, or fix the name")
                if "addr" not in p_:
                    fatal(f"poison: symbol {sym} needs `addr` too, for its "
                          f"BANK byte (the offset comes from the listing)")
                p_["addr"] = (p_["addr"] & 0xFF0000) | \
                             ((off + p_.pop("offset", 0)) & 0xFFFF)
            pois.append(p_)
        cfg["poison"] = pois

    # Input script: post-commands only.  The PRIMARY command is delivered by
    # -autoboot_command (MAME core) on fresh boots; it used to be duplicated
    # here too, harmless only because the plugin's natural-keyboard sends
    # were silently dead (nil property on MAME 0.288).  Now that the plugin
    # delivers input_script via kernel-ring injection, a duplicate primary
    # would be typed twice.
    script = []
    primary = primary or _primary_for(manifest)
    if "command" in manifest and mode == "test":
        if primary == "inject":
            # FGX_MAME_PRIMARY=inject: the primary command rides the plugin's
            # kernel-ring injection instead of -autoboot_command (run_mame
            # skips the autoboot flags in this mode, so nothing types twice).
            # +2 frames so the prompt-count baseline (snapshotted at
            # paste_frame) lands strictly before the first injected byte.
            script.append([paste_frame + 2, manifest["command"] + "\n"])
        # post_gap_frames: spacing between the autoboot paste and each
        # post_command (default 60).  Raise it when the primary needs longer
        # to start — e.g. a fresh-BRAM boot reaches the prompt ~1 s later,
        # and a too-early post types into the primary's command line.
        gap = int(manifest.get("post_gap_frames", 60))
        for i, extra in enumerate(manifest.get("post_commands", []), start=1):
            # Real newline: json.dumps encodes it as the 2-char \n escape,
            # which the plugin's unescape turns back into one CR.  The old
            # "\\n" double-escaped — the plugin decoded it to a literal
            # backslash + newline, sending a stray '\' down every paste
            # (jsh ran a junk '\' command; raw-mode consumers got a spare
            # byte).
            script.append([paste_frame + gap * i, extra + "\n"])
    if script:
        cfg["input_script"] = script
    # raw_inject: [[rel_frame, key, mods], ...] — pre-translation ADB bytes fed
    # mods: 0 = none, 1 = Ctrl, 2 = Option (slice D alt-N), 3 = both.
    # to _kKbdInjectRaw so the heartbeat's vt100 translation runs (arrows ->
    # ESC-seq, Ctrl+letter -> bare).  rel_frame is relative to the autoboot
    # paste, same convention as post_commands.
    if "raw_inject" in manifest and mode == "test":
        cfg["raw_inject"] = [[paste_frame + int(rf), int(k), int(c)]
                             for rf, k, c in manifest["raw_inject"]]
    if "command" in manifest and mode == "test":
        # The prompt-count baseline used to be snapshotted when the primary
        # command fired from input_script; the primary now rides only on
        # -autoboot_command, so tell the plugin when to take the snapshot.
        cfg["prompt_snapshot_frame"] = paste_frame
    if manifest.get("paste_mode"):
        # "post" | "paste" | "both" — which natural-keyboard mechanism the
        # plugin uses to deliver input_script text (A/B for the stuck-paste
        # investigation; plugin default is "both").
        cfg["paste_mode"] = manifest["paste_mode"]

    # Exit marker.
    em = manifest.get("exit_marker")
    if em and mode == "test":
        addr = int(em["addr_hex"], 16) if "addr_hex" in em else em["addr"]
        cfg["exit_marker"] = {"addr": addr, "byte_eq": em["byte_eq"]}

    # Exit-on-prompt.  Default to looking for the shell prompt
    # The prompt appearing one more time than at first-paste — the standard
    # "command finished, prompt returned" signal.  Tests can override via
    # manifest["exit_on_prompt"].
    #
    # SENTINEL IS "fgx#", the 2.11BSD Bourne shell's prompt.  It was "fgx:",
    # which is JSH's (jsh.c prints "fgx:<cwd># ").  jsh stopped being /bin/sh
    # when bsh landed, so the sentinel never matched, the early exit never
    # fired, and every test using the default ran to its FRAME LIMIT instead --
    # surfacing as `expected exit_reason 'prompt', got 'frame'`.  51 manifests
    # take this default; most merely ran slow, but those asserting exit_reason
    # failed outright.
    if mode == "test" and "command" in manifest:
        ep = manifest.get("exit_on_prompt", {"sentinel": "fgx#",
                                              "count_delta": 1})
        if ep:
            cfg["exit_on_prompt"] = ep

    # Hard frame cap (defense in depth).
    timeout_s = manifest.get("timeout_s", 30)
    cfg["exit_after_frame"] = paste_frame + timeout_s * 60

    # Save state on exit (for --boot-state mode).
    if mode == "boot_state":
        cfg["save_state"] = STATE_NAME
        # Boot-state mode: exit when reaches an idle marker (or hard cap).
        cfg["exit_after_frame"] = BOOT_FRAMES_FRESH + 60

    # Custom memory regions to dump (in addition to plugin defaults).
    regions = []
    for r in manifest.get("memory_regions", []):
        # Pointer-indirect region: deref a 3-byte little-endian pointer at
        # ptr_addr (bank 0), then dump `len` bytes from there.  For heap
        # structures whose static address moved (e.g. the kernel-log ring →
        # heap; ptr_addr_hex "CFG_DP_KKERN+B0" = _kLogBufPtr in the kernel DP).
        if "ptr_addr_hex" in r or "ptr_addr" in r:
            ptr = _addr(r["ptr_addr_hex"]) if "ptr_addr_hex" in r else r["ptr_addr"]
            regions.append({"name": r["name"], "ptr": ptr, "len": r.get("len", 32)})
        elif "symbol" in r:
            # Kernel-bank region named by SYMBOL, resolved from the listing.
            # Preferred over kbank+addr_hex for anything in the kernel's data
            # area: the address then cannot go stale.
            #
            # "ttybank": true resolves against the TTY BANK's listing instead,
            # and the plugin puts it at kernel bank + 2.  THIS BRANCH COMES
            # BEFORE the farbank and kbank ones, so the flag has to be handled
            # HERE -- a ttybank region handled further down would silently be
            # resolved against the CORE listing and dump a plausible read of the
            # wrong bank, which is the apple/fgx#74 failure exactly.
            # "farbank": true is the third bank, resolved the same way and
            # here for the same reason the ttybank note gives: a far-bank
            # symbol handled by the farbank branch below would need an EQU,
            # and far-bank C DATA has labels rather than EQUs (UFS 2.4b's
            # root_mounted is one).  Naming it beats an address that goes
            # stale on any far-bank resize.
            ttyb = bool(r.get("ttybank"))
            farb = bool(r.get("farbank")) and "addr_equ" not in r
            lst = TTY_LST if ttyb else (FAR_LST if farb else KERNEL_LST)
            off = _kernel_symbol(r["symbol"], lst)
            if off is None:
                fatal(f"memory_region '{r['name']}': symbol {r['symbol']} not "
                     f"found in {lst.name} -- rebuild, or fix the name")
            key = ("ttybank_off" if ttyb else
                   "farbank_off" if farb else "kbank_off")
            regions.append({"name": r["name"], key: off,
                            "len": r.get("len", 32)})
        elif r.get("farbank"):
            # FAR-kernel-bank-relative region.  The plugin resolves the bank as
            # the live kernel bank + 1 (include/kernel.s:185) -- the assembled
            # FGX_KFAR_BANK ($08) is an ORG convention and never appears at
            # runtime.  The offset is resolved from the include sources so it
            # cannot go stale the way a literal did in apple/fgx#102.
            off = _src_equ(r["addr_equ"]) & 0xFFFF
            regions.append({"name": r["name"], "farbank_off": off,
                            "len": r.get("len", 32)})
        elif r.get("kbank"):
            # Kernel-bank-relative region: keep only the 16-bit offset; the
            # plugin combines it with the live kernel bank (anchor $00:032C),
            # so it resolves under both the relocating ($20) and legacy ($02)
            # builds.  The bank nibble is ignored.
            #
            # `addr_equ' IS THE FORM TO USE, and it is the far bank's arm above
            # brought down here (apple/fgx#123).  A literal offset into the
            # kernel bank is the landmine _kernel_symbol's docstring describes:
            # it goes stale the moment anything resizes the kernel, and a stale
            # region reads a serene wrong value rather than failing.  `symbol'
            # cannot serve every case -- FGX_TASK_TBL is an EQU in
            # include/kernel.s, not a label in the listing, so it never appears
            # there -- which is why these fifteen regions kept their literal
            # while the rest of the corpus converted.
            if "addr_equ" in r:
                off = _src_equ(r["addr_equ"]) & 0xFFFF
            else:
                off = (_addr(r["addr_hex"]) if "addr_hex" in r else r["addr"]) & 0xFFFF
            regions.append({"name": r["name"], "kbank_off": off, "len": r.get("len", 32)})
        elif "vcbank" in r:
            # Virtual-console-relative region: the plugin resolves the bank from
            # _kVcBank[N], the per-VC framebuffer registry.  con_base()/conbank
            # only ever follow the ACTIVE console, which cannot express the
            # assertion that matters most for virtual consoles -- "VC1 received
            # this while VC0 did not".  A VC with no bank yet (lazy first-write
            # allocation) dumps addr 0 and an EMPTY body, so "not allocated" is
            # distinguishable from "allocated but blank".
            addr = _addr(r["addr_hex"]) if "addr_hex" in r else r["addr"]
            regions.append({"name": r["name"], "addr": addr,
                            "len": r.get("len", 32), "vcbank": int(r["vcbank"])})
        elif "modbank" in r:
            # Module-bank-relative region: the plugin resolves the bank from
            # _modBankTab[ordinal], the ordinal -> real-bank map Mod_Load fills
            # in.  A module cannot name its own bank (it does not know which one
            # it will get), so the ORDINAL is the only stable handle a manifest
            # can carry -- it comes straight from the FGXM header's load-address
            # high byte minus FGX_MOD_ORG_BANK ($05 -> 0).  Baking the bank
            # instead would pin whatever the allocator happened to hand out on
            # the day the test was written.  0 in the table means the ordinal
            # has no bank yet, and the region then dumps addr 0 with an EMPTY
            # body so "never loaded" is distinguishable from "loaded but blank".
            addr = _addr(r["addr_hex"]) if "addr_hex" in r else r["addr"]
            regions.append({"name": r["name"], "addr": addr,
                            "len": r.get("len", 32), "modbank": int(r["modbank"])})
        elif r.get("conbank"):
            # Console-bank-relative region: the plugin swaps the bank byte for
            # the live console bank, exactly as it does for its own
            # charbuf/attrbuf dumps.  CON_CHARBUF and friends move off the
            # assembly-time $03 under relocation, so a test that wants FGBUF or
            # BGBUF must ask for them this way rather than baking an address.
            addr = _addr(r["addr_hex"]) if "addr_hex" in r else r["addr"]
            regions.append({"name": r["name"], "addr": addr,
                            "len": r.get("len", 32), "conbank": True})
        else:
            addr = _addr(r["addr_hex"]) if "addr_hex" in r else r["addr"]
            regions.append({"name": r["name"], "addr": addr, "len": r.get("len", 32)})
        # Optional SAMPLE FRAME — capture the region at that frame instead of
        # at dump time (the default).  Needed for anything TRANSIENT: a cell
        # that is written and then consumed reads 0 at the end of the run
        # whether or not it was ever set, so an end-of-run dump cannot tell
        # "never posted" from "posted and drained".
        #
        # TWO AXES, AND THEY ARE NOT INTERCHANGEABLE (apple/fgx#183):
        #
        #   "frame":      N  relative to the autoboot PASTE, the same origin
        #                    raw_inject and post_commands use.  This is the
        #                    axis for anything the command does.
        #   "boot_frame": N  ABSOLUTE plugin frames, counted from reset.  This
        #                    is the axis the plugin stamps capture_log,
        #                    watch_log and every "sampled_at_frame" on, and the
        #                    only one that can name a moment BEFORE the paste.
        #
        # The distinction is not pedantic: a fresh boot pastes at frame 1500,
        # and module init -- where a probe compiled into a module runs -- is
        # around frame 276.  Reading a region "frame" and a capture "frame" as
        # one axis is wrong by twenty seconds, which is how #183's `ufs: ok` at
        # region frame 350 looked adjacent to a runaway at capture frame 353.
        #
        # A NEGATIVE "frame" IS NOT THE WAY TO NAME A BOOT MOMENT, even though
        # it usually works.  The arithmetic happens HERE, so -1224 against a
        # 1500-frame paste reaches the plugin as 276 and samples correctly --
        # and that is the trap, not a reprieve:
        #
        #   - it encodes "absolute 276" as an offset from a number the manifest
        #     never states, so FGX_MAME_BOOT_S moves every such region without
        #     touching the file;
        #   - and if the sum ever goes BELOW zero the plugin gets `"frame": -N`,
        #     which its `%d+` cannot match, so the region loses its sample frame
        #     and is read at dump time instead -- a successful-looking capture
        #     of the wrong moment.  That is what the guard below refuses.
        #
        # "boot_frame" says the same thing directly and cannot drift.
        if "frame" in r and "boot_frame" in r:
            fatal(f"memory_region '{r['name']}': has both \"frame\" and "
                 f"\"boot_frame\".  They are different axes; pick one.")
        if "boot_frame" in r:
            bf = int(r["boot_frame"])
            if bf < 0:
                fatal(f"memory_region '{r['name']}': boot_frame {bf} is "
                     f"negative; frames are counted from reset.")
            regions[-1]["frame"] = bf
        elif "frame" in r:
            abs_frame = paste_frame + int(r["frame"])
            if abs_frame < 0:
                fatal(f"memory_region '{r['name']}': \"frame\": "
                     f"{r['frame']} is {abs_frame} absolute -- the paste is at "
                     f"frame {paste_frame}, so this names a moment before "
                     f"reset.  Use \"boot_frame\" for a boot-time sample; a "
                     f"negative absolute frame reaches the plugin as a value "
                     f"its \"%d+\" cannot match, and the region would be read "
                     f"at dump time without a word.")
            regions[-1]["frame"] = abs_frame
    if regions:
        cfg["memory_regions"] = regions

    # THE ORIGIN, ECHOED INTO THE DUMP.  Every frame the plugin reports --
    # capture_log, watch_log, sampled_at_frame -- is absolute, and a reader
    # cannot convert one to a manifest "frame" without knowing where the paste
    # was.  Carrying it means the dump answers that itself instead of the
    # reader assuming 25 seconds.
    cfg["paste_frame"] = paste_frame

    # Keyboard-ring cell offsets, derived from the kernel listing rather than
    # hardcoded in the plugin (see kbd_ring_offsets).
    kbd = kbd_ring_offsets()
    if kbd:
        cfg["kbd_ring"] = kbd

    # capture_writes: instruction-precise write-tap snapshots (writer PC +
    # registers + HW-stack return chain + DP window).  Each manifest entry:
    # {"name": ..., "addr_hex"|"addr": ..., "len": 1, "max_hits": 32,
    #  "keep": "first"|"last"}.
    #
    # keep="first" (default) stops capturing once max_hits are in hand: the
    # right answer for "what touched this FIRST".  keep="last" never stops and
    # retains the most recent max_hits in a ring.  Use it for anything that goes
    # wrong at the END of a run -- a first-N tap on a busy address fills during
    # boot and then reports nothing, which reads identically to "it never
    # happened".  Every entry carries "frame", so a capture can be placed on the
    # run's timeline; without it, "stopped happening" and "never captured" are
    # indistinguishable.  NOTE: the address is RAW -- there is no kbank support
    # here, so a kernel-bank target needs the live bank in the address.
    if manifest.get("png_snapshot") and mode == "test":
        cfg["png_snapshot"] = manifest["png_snapshot"]

    cw = manifest.get("capture_writes")
    if cw and mode == "test":
        out = []
        for c in cw:
            addr = _addr(c["addr_hex"]) if "addr_hex" in c else c["addr"]
            keep = c.get("keep", "first")
            if keep not in ("first", "last"):
                fatal(f"capture_writes '{c.get('name','cap')}': keep must be "
                     f"\"first\" or \"last\", got {keep!r}")
            out.append({"name": c.get("name", "cap"), "addr": addr,
                        "len": c.get("len", 1), "max_hits": c.get("max_hits", 32),
                        "keep": keep})
        cfg["capture_writes"] = out

    # watch_min: 16-bit write-value aggregator (min/max/hits per cell, no
    # per-hit log) — for high-water measurements like _fcc_fb where every
    # prologue writes the cell and a capture log would be huge.
    wm = manifest.get("watch_min")
    if wm and mode == "test":
        out = []
        for w in wm:
            addr = _addr(w["addr_hex"]) if "addr_hex" in w else w["addr"]
            out.append({"name": w.get("name", "wm"), "addr": addr})
        cfg["watch_min"] = out

    # stack_excursion: one write-tap over the user-stack arena; the plugin
    # aggregates per-task max(e = _fcc_fb-1-S) + absolute min_S.  For P3-3 pad
    # calibration (#42) — the depth of non-C pushes below the live C frame that
    # DEFAULT_PAD / FCC_STK_FLOOR_MARGIN must cover.  Manifest may set lo/hi
    # (defaults arena $3000..$B000); pass the object straight through.
    se = manifest.get("stack_excursion")
    if se is not None and mode == "test":
        cfg["stack_excursion"] = se if isinstance(se, dict) else {}
        # The plugin used to classify each tap hit by the writer's DIRECT
        # PAGE against a per-pid block.  A task's page is the first page of
        # its own stack reservation now, so there is no band to send, and
        # the plugin skips attribution when none is given.  No manifest uses
        # the tap today.

    # Watch addrs: per-frame byte poll, log value changes.
    watch = []
    for w in manifest.get("watch_addrs", []):
        addr = _addr(w["addr_hex"]) if "addr_hex" in w else w["addr"]
        watch.append({"name": w["name"], "addr": addr})
    if watch:
        cfg["watch_addrs"] = watch

    # fbench cycle markers: plugin installs write-taps on these two addrs and
    # captures emu.time() at each, writing the delta to out_path. Optional.
    cm = manifest.get("cycle_markers")
    if cm and mode == "test":
        sa = int(cm["start_addr_hex"], 16) if "start_addr_hex" in cm else cm["start_addr"]
        da = int(cm["done_addr_hex"], 16) if "done_addr_hex" in cm else cm["done_addr"]
        cfg["cycle_markers"] = {"start_addr": sa, "done_addr": da,
                                "out_path": cm.get("out_path", "/tmp/fbench_cyc.json")}

    # PC-sampler (Phase-0 profiler): when manifest["pc_sample"] is truthy, the
    # plugin histograms the program counter once per frame while the command
    # runs.  run_mame overrides the out path to per-test scratch.
    if manifest.get("pc_sample") and mode == "test":
        cfg["pc_sample"] = {"out": "/tmp/fgx_pc_samples.json"}

    return cfg


# ---------------------------------------------------------------------------
def run_mame(*, manifest, mode, debug=False, headless=True, scratch=None):
    """Launch MAME for one test.  Returns (exit_status, mame_pid, scratch_dir).

    Per-test scratch dir at /tmp/fgx_test_<name>/ holds disk copy,
    plugin dump JSON, MAME stdout/stderr, and extracted disk
    contents.  Caller can pre-allocate one.

    The plugin's config path is hard-coded to /tmp/fgx_debug_config.json
    — we still write there since the plugin can't be parameterized
    — but the dump output goes to scratch/dump.json.
    """
    name = manifest.get("name", "_run")
    scratch = scratch or Path(f"/tmp/fgx_test_{name}")
    if scratch.exists():
        shutil.rmtree(scratch)
    scratch.mkdir(parents=True)
    test_disk = scratch / "fgxroot.fs"
    # Per-manifest `disk_image` lets a test boot from an alternate image
    # (e.g. tools/fcc/tests/run_runtime.py builds a 32MB disk for the
    # full fcc-runtime sweep that wouldn't fit on the default 800KB).
    src_disk = REPO / manifest["disk_image"] if "disk_image" in manifest else DISK_BASE
    if not src_disk.exists():
        fatal(f"disk image {src_disk} (manifest disk_image) missing")
    _require_fresh_build(src_disk)
    shutil.copy(src_disk, test_disk)
    # Floppy-boot mode: a manifest `"boot_device": "floppy"` (or FGX_BOOT_FLOPPY=
    # <path> for an ad-hoc image) boots the streamlined 3.5" floppy from the
    # built-in slot-5 drive (-flop3) instead of the slot-7 SmartPort HD, so the
    # floppy-boot path is regression-testable headless (it had been untested,
    # which is how the slot-5 ROM-firmware DP-clobber bug lurked).  The IWM
    # emulation is much slower, so the boot timing is stretched (paste_frame +
    # autoboot_delay below).
    _boot_floppy = (bool(os.environ.get("FGX_BOOT_FLOPPY"))
                    or manifest.get("boot_device") == "floppy")
    # SECONDS TO A READY PROMPT, PER TEST.  BOOT_FRAMES_FRESH is one number for
    # every manifest, and the autoboot command is typed on that schedule rather
    # than when the prompt appears -- so an image that reaches its shell later
    # than the estimate has its command echoed into a console that is not
    # reading yet, and the command is simply lost.  The test then shows a boot
    # that worked and no command output, which reads as the guest executing
    # nothing (that misreading cost two consecutive UFS diagnoses on
    # 2026-09-01, apple/fgx#291).  disk/fgxroot.fs is the case: it brings its
    # root up through the VFS and reaches /bin/sh well past 25 s.
    _boot_s = manifest.get("boot_s")
    _boot_frames = (max(int(_boot_s) * 60, BOOT_FRAMES_FRESH) if _boot_s
                    else 66 * 60 if _boot_floppy
                    else BOOT_FRAMES_FRESH)
    # The slot-7 card for THIS test (apple/fgx#257).  Env default unless the
    # manifest names one; see _hdslot_for.
    _hdslot, _is_md = _hdslot_for(manifest)
    # PER-TEST BRAM, ALWAYS -- MAME WRITES THIS DIRECTORY ON EXIT.  The default
    # used to point straight at the shared Ample nvram, which is fine one test
    # at a time and a data race the moment two MAME instances run together
    # (--jobs).  Copying preserves the semantics exactly: the default case still
    # boots with the USER's persistent control-panel state (slot 1 = AppleTalk
    # on, which serial.mod reads at load), it just cannot write back to it.
    # The two branches below deliberately leave the directory EMPTY instead, so
    # MAME falls back to power-on defaults -- that is their whole point.
    _nvdir = scratch / "nvram"
    _nvdir.mkdir(parents=True, exist_ok=True)
    _nv_shared = AMPLE_SUP / "nvram"
    if _nv_shared.is_dir():
        for _sub in _nv_shared.iterdir():
            _dst = _nvdir / _sub.name
            if _sub.is_dir():
                shutil.copytree(_sub, _dst, dirs_exist_ok=True)
            else:
                shutil.copy2(_sub, _dst)
    if _boot_floppy:
        _fsrc = os.environ.get("FGX_BOOT_FLOPPY") or "disk/fgx-floppy.po"
        _fpath = _fsrc if os.path.isabs(_fsrc) else str(REPO / _fsrc)
        # A MISSING IMAGE IS A BUILD STATE, NOT A TEST RESULT.  Copying it
        # blind raised FileNotFoundError out of the harness, which reads as a
        # crash in the thing under test rather than "you have not built it"
        # (apple/fgx#83).  Every other missing input in this suite either
        # fatal()s with an explanation or declares a skip with a reason; this
        # one traced back.  Say which file and which target makes it.
        if not os.path.exists(_fpath):
            fatal(f"{manifest['name']}: boot image {_fsrc} does not exist. "
                 f"Build it with `ninja disk/fgx-floppy.po`.  IT IS NOT PART "
                 f"OF `ninja disk` -- it is a target of the `release` phony, "
                 f"which this message used to claim otherwise and which is why "
                 f"a dev tree hit this at all.  A manifest that boots the "
                 f"floppy should declare requires.files so the tree without it "
                 f"SKIPS: this fatal() exits the process, so it takes every "
                 f"test after it with it.")
        shutil.copy(_fpath, scratch / "floppy.po")
        # The floppy boots from the internal IWM 3.5" drive, which requires the
        # control panel's slot 5 = "Built-in".  The shared Ample BRAM may have
        # slot 5 = "Your Card" (a SCSI / CFFA2 setup), disabling that drive -> no
        # boot device -> DB=$0 hang.  Boot the floppy with a FRESH per-test BRAM
        # (MAME's power-on default has slot 5 = Built-in), so this test is
        # independent of whatever the user's persistent control-panel state is.
        # EMPTY, not merely per-test: the seed copy above would otherwise hand
        # it the very state this branch exists to escape.
        shutil.rmtree(_nvdir, ignore_errors=True)
        _nvdir.mkdir(parents=True, exist_ok=True)
    if manifest.get("fresh_nvram"):
        # Per-test power-on-default BRAM, independent of the user's persistent
        # control-panel state.  Needed by tests that depend on a CP setting the
        # shared Ample BRAM may have flipped — e.g. cu_port needs Slot 1 =
        # Printer Port (AppleTalk off) or serial.mod skips chan A / tty00.
        # EMPTY, for the same reason as the floppy branch above.
        shutil.rmtree(_nvdir, ignore_errors=True)
        _nvdir.mkdir(parents=True, exist_ok=True)

    # CPU speed: MAME's apple2gs models a ZipGS accelerator via the a2_config
    # "CPU type" port (0=Standard 2.8MHz, 1=7MHz, 3=8, 5=12, 7=16 MHz ZipGS).
    # MAME's default cfg dir resolves cwd-relative, so run.py never picked up
    # the shared Ample cfg -> tests ran at stock 2.8 MHz. Force 7 MHz ZipGS with
    # a dedicated per-run cfg dir (deterministic; matches mame-hd.sh's intent
    # and the real accelerated IIgs FGX targets). Override via FGX_MAME_A2CFG.
    _a2cfg = os.environ.get("FGX_MAME_A2CFG", "1")   # 1 = 7 MHz ZipGS
    _cfgdir = scratch / "cfg"
    _cfgdir.mkdir(parents=True, exist_ok=True)
    (_cfgdir / "apple2gs.cfg").write_text(
        '<?xml version="1.0"?>\n<mameconfig version="10">\n'
        '    <system name="apple2gs">\n        <input>\n'
        '            <port tag=":a2_config" type="CONFIG" mask="7" '
        'defvalue="0" value="%s" />\n' % _a2cfg +
        '        </input>\n    </system>\n</mameconfig>\n')

    dump_path = scratch / "dump.json"
    stdout    = scratch / "mame_stdout.log"
    stderr    = scratch / "mame_stderr.log"

    # Wipe any faslog so we only see this run's markers.
    subprocess.run(
        ["cadius", "DELETEFILE", str(test_disk), "/FGX/ROOT/FASLOG"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # Stage host files onto the per-test disk copy (Phase-0 profiler: swap in a
    # tool binary built by an alternate fcc, and add workload inputs).  Each
    # manifest entry: {"host": <repo-rel or abs path>, "prodos_dir": "/FGX/...",
    # "name": <PRODOS_NAME, default host basename upper>, "replace": true}.
    # replace=true uses cadius REPLACEFILE (keeps the existing file's type/aux),
    # otherwise DELETEFILE+ADDFILE (idempotent add of a new file).
    for sf in stage_list(manifest):
        hostp = sf["host"]
        hostp = hostp if os.path.isabs(hostp) else str(REPO / hostp)
        ensure_toolchain_fixture(hostp)
        if not os.path.exists(hostp):
            fatal(f"stage_files: host file {hostp} missing")
        name = sf.get("name") or Path(hostp).name.upper()
        staged = scratch / name
        shutil.copy(hostp, staged)
        pdir = sf["prodos_dir"].rstrip("/")

        # THE IMAGE DECIDES THE TOOL.  cadius speaks ProDOS and the suite's
        # boot image is 2.11BSD now, so every one of these staged NOTHING --
        # silently, because both cadius calls below discard their output.  A
        # fixture that does not arrive is not a failure, it is the SHIPPED file
        # being tested instead: apple/fgx#147's ttypeneg went green-adjacent
        # reporting vt100, which is exactly what /etc/ttys says when the
        # fixture typing the console vt102 never lands.
        #
        # `prodos_dir' is kept as the manifest key because it is what 22
        # manifests already say, and the ProDOS volume is named FGX -- so the
        # UFS path is the same path with that volume name off the front.
        if _is_ufs_image(test_disk):
            upath = pdir
            if upath.upper().startswith("/FGX"):
                upath = upath[4:] or "/"
            # ...AND LOWERCASED, because a 2.11BSD root is case-sensitive and
            # ProDOS was not.  `prodos_dir' is spelled in ProDOS's shouting --
            # `/FGX/TESTBIN' -- while the volume this stages onto carries
            # `/testbin', so the path came through as a directory that does not
            # exist and fgxfs answered `/TESTBIN: no such file or directory'.
            # The whole path goes down, name included: every file on the UFS
            # root is lower case, modules included since they stopped being
            # staged in ProDOS's naming.
            upath = (upath.rstrip("/") + "/" + name).lower()
            r = subprocess.run(
                [sys.executable, str(REPO / "tools" / "fgxfs.py"), "put",
                 "--replace", str(test_disk), str(staged), upath],
                capture_output=True, text=True)
            if r.returncode != 0:
                fatal("stage_files: fgxfs put %s failed: %s"
                      % (upath, (r.stderr or r.stdout).strip()))
            print(DIM_("  staged %s -> %s (ufs)" % (name, upath)))
            continue

        if sf.get("replace"):
            subprocess.run(["cadius", "REPLACEFILE", str(test_disk), pdir, str(staged)],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            subprocess.run(["cadius", "DELETEFILE", str(test_disk), f"{pdir}/{name}"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["cadius", "ADDFILE", str(test_disk), pdir, str(staged)],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(DIM_(f"  staged {name} -> {pdir}/{name}"
                   + (" (replace)" if sf.get("replace") else "")))

    # Pick paste-frame based on whether we're loading a state.
    # Auto-invalidate: the save-state captures RAM, including the
    # loaded kernel + shell.  If disk/fgxroot.fs was rebuilt (any of:
    # kernel.s, libc.s, sh.s, anything linked into a userland
    # binary), the cached state may be testing stale code.
    # MAME writes state files as <state_dir>/<machine>/<name>.sta
    #
    # State-load is OPT-IN per test, via manifest["use_state"]: true.
    # It skips the boot, so a test that asserts on boot output, module load
    # order or the device probe must not use it.
    #
    # The command reaches a restored state through the plugin's kernel-ring
    # injection; the autoboot path cannot, because run_mame adds
    # -autoboot_command only on the fresh-boot arm.  use_state therefore
    # selects injection itself (see primary_input below) rather than leaving
    # the caller to discover a run that waits for its timeout.
    #
    # Staleness: the save-state captures RAM, including the loaded kernel and
    # shell, so a rebuilt image means the cache is testing stale code.  The
    # mtime test below compares against DISK_BASE, which is the image actually
    # booted (disk/fgxroot.fs by default).
    state_file = STATE_DIR / "apple2gs" / f"{STATE_NAME}.sta"
    use_state = (mode == "test" and state_file.exists()
                 and manifest.get("use_state", False)
                 and not manifest.get("_no_state"))
    if use_state and DISK_BASE.stat().st_mtime > state_file.stat().st_mtime:
        print(DIM_(f"  state cache stale (disk/fgxroot.fs newer than "
                   f"{STATE_NAME}.sta) — regenerating"))
        # Regenerate the cache once, then proceed with state-load.
        # Subsequent tests in the same batch pick up the fresh state.
        boot_state()
        if state_file.exists() and (DISK_BASE.stat().st_mtime
                                    <= state_file.stat().st_mtime):
            print(DIM_("  state regenerated; using cached boot"))
        else:
            print(DIM_("  state regeneration failed; falling back to cold boot"))
            use_state = False
    # _boot_frames already carries the floppy stretch (3.5" boot is much slower
    # than the SmartPort HD: the complete streamlined floppy, 44-entry /bin,
    # reaches the shell ~60s on slow IWM) and any per-manifest boot_s.
    paste_frame = BOOT_FRAMES_LOADED if use_state else _boot_frames
    if mode == "boot_state":
        paste_frame = 0   # boot-state doesn't paste anything

    # A STATE-LOADED RUN MUST INJECT.  run_mame adds -autoboot_command only on
    # the fresh-boot arm, so with a restored state the primary command can only
    # reach the guest through the plugin's kernel-ring injection.  Left on the
    # autoboot default it is never delivered at all and the run sits until its
    # timeout, which is what "state-load is useless" used to mean.
    primary_input = _primary_for(manifest)
    if use_state and primary_input != "inject":
        primary_input = "inject"
        print(DIM_("  use_state: routing the command through kernel-ring "
                   "injection (autoboot does not reach a restored state)"))

    # Write plugin config.  Override output_path to per-test scratch.
    cfg = build_plugin_config(manifest, mode=mode, paste_frame=paste_frame,
                              primary=primary_input)
    cfg["output_path"] = str(dump_path)
    # PC-sampler output goes to per-test scratch (Phase-0 profiler).
    if "pc_sample" in cfg:
        cfg["pc_sample"]["out"] = str(scratch / "pc_samples.json")
    # Per-test config path (task #60 parallel runs): the plugin reads
    # FGX_DEBUG_CONFIG from its environment, so concurrent MAME instances
    # no longer race on the shared /tmp config.  The legacy /tmp path is
    # still the plugin's fallback for manual invocations.
    cfg_path = scratch / "fgx_debug_config.json"
    cfg_path.write_text(json.dumps(cfg, indent=2))

    # Build MAME args.  Settings mirror mame-hd.sh.
    #
    # IMPORTANT: NEVER use -nowindow on macOS — bgfx falls back to a
    # fullscreen window that takes over the display.  Use one of two
    # modes only:
    #   windowed  : -window -video bgfx -resolution 1408x924
    #   headless  : -window -video none (renders nothing, runs CPU)
    # MicroDrive: wrap the staged image into a one-partition CF-card image.  Done
    # here, AFTER cadius has finished editing test_disk, so the wrap sees the
    # staged files.
    # THE EXTRA SPINDLES ARE RESOLVED HERE, BEFORE THE WRAP, because on a
    # MicroDrive they are not spindles at all.  The card takes ONE CF image and a
    # second volume is a second PARTITION inside it, so `-hard2' is not a thing
    # MAME will accept for this slot -- it exits with "unknown option: -hard2"
    # before the machine ever starts.
    #
    # THAT KILLED THE ONLY MICRODRIVE TEST IN THE SUITE.  `mdboot' exists to
    # cover apple/fgx#111, the one card that refuses the generic Read ($48) and
    # so the only target that reaches _SP_ReadBlockN's @sprbn_err at all -- and
    # it could not run at all once the /dev volume below became part of every
    # machine (UFS 1.7d I3).  It is not in GATE_TESTS either, so nothing said so.
    # A card FGX actually boots from on real hardware had no working coverage.
    #
    # mame-hd.sh has always done it this way ("Disks are wrapped into one .mdt"),
    # which is why interactive MicroDrive use kept working while the harness's
    # own MicroDrive path was dead.
    # EVERY SPINDLE IS STAGED INTO THE SCRATCH DIR, exactly as the boot disk is
    # (`test_disk' above), and MAME is pointed at the COPY.  It used to be
    # handed the tracked image in `disk/' by path, and MAME opens a hard disk
    # READ-WRITE, so the guest wrote to the repo's own file.
    #
    # THAT IS WHY THE FILESYSTEM WRITE PROBES ARE KNOBS RATHER THAN TESTS.  Each
    # of ufs{,vn,w,dev}probe writes to disk/ufsscratch.fs and then puts every
    # byte back by hand, because -- as ufswprobe.json says in its own words --
    # "the image is handed to MAME by path with no per-run copy and ninja will
    # not rebuild an output newer than its inputs, so a run that left it changed
    # would poison it until someone deleted it by hand".  A crash mid-write
    # poisons it anyway, and two tests running under --jobs raced for it.
    #
    # AND IT IS WHAT KEPT THE CAMPAIGN'S ORACLE OUT OF THE LOOP.  tools/gate.sh
    # says fgxfs is "the independent implementation every claim FGX makes about
    # a volume it wrote gets checked against", and the campaign plan puts it
    # plainer still: "attribution comes from the ORACLE, not from the disk image
    # being unchanged".  Nothing could hand fgxfs a volume FGX had written while
    # the only such volume was one the probe was obliged to restore.  A staged
    # copy is disposable, so the run can LEAVE its writes and be judged on them:
    # that is ufsfsck_check.py, wired as an ordinary `check_script'.
    # NO /dev SPINDLE.  disk/fgxdev.fs used to be attached to EVERY machine
    # here, and it stopped being a device the system uses when the UFS root
    # grew its own /dev: main.s mounts the root and nothing else now, as
    # 2.11BSD's kernel does, so the volume arrived, was never mounted, and
    # occupied SmartPort unit 1 for the whole run.  What that cost was the unit
    # numbering -- a test's own spindle landed on unit 2 rather than unit 1,
    # /dev/sd2 was baked to match, and anyone driving MAME by hand had to pass
    # a disk nobody wanted in order to push their volume up to the unit that
    # had a node.  A drive attached so that the numbering comes out right is
    # not a drive.
    _srcvols = []

    _hards = list(manifest.get("extra_hards") or [])
    _extra = os.environ.get("FGX_EXTRA_HARDS", "")
    if _extra:
        _hards += _extra.split(":")
    for _img in _hards:
        _p = Path(_img)
        if not _p.is_absolute():
            _p = REPO / _img
        if not _p.exists():
            fatal(f"{manifest.get('name')}: extra_hards image {_p} does not "
                f"exist -- a missing second drive makes the test pass "
                f"vacuously against the boot disk instead")
        _srcvols.append(_p)

    # Staged under their own basenames so a checker can name the volume it
    # wants.  A COLLISION IS FATAL rather than last-one-wins: two spindles with
    # the same basename would silently become one drive, and the machine would
    # come up with a volume missing -- which is the vacuous-pass shape the
    # missing-image fatal() above already exists to prevent.
    _spindles = []
    _vol_dir = scratch / "vols"
    _vol_dir.mkdir(parents=True, exist_ok=True)
    for _p in _srcvols:
        _dst = _vol_dir / _p.name
        if _dst.exists():
            fatal(f"{manifest.get('name')}: two spindles are both named "
                  f"{_p.name} -- staged volumes are keyed by basename, so one "
                  f"would silently replace the other")
        shutil.copy(_p, _dst)
        _spindles.append(_dst)

    # MicroDrive: wrap the staged image AND every extra volume into one CF-card
    # image, boot disk first so it stays s7d1.  Done here, AFTER cadius has
    # finished editing test_disk, so the wrap sees the staged files.
    boot_image = test_disk
    if _is_md and not _boot_floppy:
        if not os.access(MDTTOOL, os.X_OK):
            fatal(f"FGX_MAME_HDSLOT=microdrive needs mdttool at {MDTTOOL} "
                  f"(set $MDTTOOL, or put mdttool on $PATH)")
        boot_image = test_disk.with_suffix(".mdt")
        subprocess.run([str(MDTTOOL), "-a", "-o", str(boot_image),
                        str(test_disk), *[str(x) for x in _spindles]],
                       check=True, stdout=subprocess.DEVNULL)

    args = [
        MAME, "apple2gs",
        "-skip_gameinfo",
        # FGX_MAME_RAM overrides the machine's RAM for minimum-memory work
        # (apple/fgx: the kernel must detect what it actually has and refuse to
        # boot below its floor, rather than hang).  Default stays 8M so every
        # existing test is unaffected.
        "-ramsize", os.environ.get("FGX_MAME_RAM", "8M"),
        "-window",
        "-nounevenstretch",
        "-sound", "coreaudio", "-volume", "0",
        "-homepath",       str(AMPLE_SUP),
        "-rompath",        str(AMPLE_SUP / "roms"),
        "-artpath",        str(AMPLE_SUP / "artwork"),
        "-nvram_directory", str(_nvdir),
        "-cfg_directory", str(_cfgdir),
        "-state_directory", str(STATE_DIR),
        # User's plugin dir (synced from repo at startup).
        "-pluginspath", str(AMPLE_PLUGINS),
        "-plugin", "fgxdebug",
        *(["-flop3", str(scratch / "floppy.po")] if _boot_floppy else
          ["-sl7", _hdslot, "-hard1", str(boot_image)]),
        "-natural",
    ]
    # Optional extra SmartPort drives (-hard2, -hard3, ...) for repro/diag of
    # multi-volume / mount scenarios.  Colon-separated image paths in
    # FGX_EXTRA_HARDS; FGX auto-mounts each under /mnt/<volname>/.
    # A manifest may ask for them by name instead, which is where the request
    # belongs: a test that needs a second spindle should say so itself rather
    # than depend on the runner's environment being set up beforehand.  Paths
    # are repo-relative.  Manifest entries come first, then any from the env.
    # EVERY DRIVE HERE IS A TEST'S OWN NOW.  The /dev volume used to be added
    # to this list unconditionally -- see the comment where the list is built
    # -- and apple/fgx#220 is what that hid: a machine with no /dev volume was
    # supposed to log the failure and carry on, and instead the boot hung.
    # Nothing in the suite could measure it, because every machine got the
    # volume.  There is no such machine any more: a root that carries its own
    # /dev needs no volume mounted for it, so EVERY test is now the case that
    # issue was about, and `no_dev_volume' is gone with the spindle it declined.
    #
    # The list itself is built ABOVE, before the wrap -- see the comment there
    # for why the MicroDrive cannot take these as -hardN at all.  The boot disk
    # is -hard1, so the extras start at -hard2 in card order, which makes the
    # first of them SmartPort unit 1 and /dev/sd1.
    # A FLOPPY BOOT HAS NO CARD TO HANG THEM ON.  `-flop3' replaces the whole
    # -sl7/-hard1 group, so MAME rejects `-hard2' outright ("unknown option")
    # and exits before the machine starts -- which the runner reports only as
    # "plugin never ran".  That is what the unconditional /dev spindle used to
    # do to both this path and the MicroDrive's; with the list empty unless a
    # manifest asks, neither can be broken by a drive nobody requested.
    if not _is_md and not _boot_floppy:
        for _i, _p in enumerate(_spindles, start=2):
            args += [f"-hard{_i}", str(_p)]
    # Optional extra MAME slot devices from the test manifest, e.g. networking
    # gates needing the Uthernet II: "mame_slots": ["-sl1", "uthernet2"].
    _slots = manifest.get("mame_slots")
    if _slots:
        args += list(_slots)
    if headless and not debug:
        # No rendering, no audio.  Combined with SDL_VIDEODRIVER=dummy
        # below, this is fully silent and invisible — suitable for
        # bulk / CI runs.
        args += ["-video", "none", "-sound", "none"]
        # ...but that alone does NOT make emulation fast: MAME throttles to
        # real time by default, so `-autoboot_delay 12` cost 12 WALL seconds
        # per test.  Measured 2026-07-28: one test 14s throttled -> 2s with
        # -nothrottle (7x), identical checks reached in both.
        #
        # This is safe because autoboot_delay is counted in EMULATED FRAMES
        # (12 * 60 = 720).  Unthrottled, the guest still sees 720 frames --
        # guest-visible timing is bit-identical; only wall-clock shrinks.
        #
        # EXCEPT where the guest talks to the HOST on a real clock: the
        # uthernet2 gates wait on a real DHCP server, real TCP peers and real
        # DNS, which do not speed up.  Those keep real-time pacing so the
        # emulated side cannot outrun its peer.  Manifests self-identify via
        # mame_slots (see above), so no per-test annotation is needed.
        _wants_net = any("uthernet2" in str(s) for s in (_slots or []))
        if not _wants_net and os.environ.get("FGX_MAME_THROTTLE", "0") != "1":
            args += ["-nothrottle"]
    else:
        # Visible window with bgfx Fighters chain at 1408x924.
        args += [
            "-resolution", "1408x924",
            "-video", "bgfx",
            "-bgfx_screen_chains", "Fighters",
            "-bgfx_path", str(AMPLE_SUP / "bgfx"),
        ]

    # Cold-boot helpers: autoboot + state load.
    if use_state:
        args += ["-state", STATE_NAME]
    else:
        # Use autoboot for the FIRST shell command in fresh-boot test mode
        # (unless FGX_MAME_PRIMARY=inject routed it through input_script).
        if mode == "test" and "command" in manifest and primary_input != "inject":
            _ad = str(_boot_frames // 60)
            args += ["-autoboot_delay", _ad,
                     "-autoboot_command", manifest["command"] + "\\n"]

    # Override config for debug mode: no exit_after_frame, no save.
    if debug:
        cfg.pop("exit_after_frame", None)
        cfg.pop("exit_marker", None)
        cfg_path.write_text(json.dumps(cfg, indent=2))

    # Diagnostic escape hatch: extra MAME arguments, shell-split, appended
    # last.  The harness has no other way to attach MAME's debugger to a
    # failing test, and static reading is a poor substitute for a write
    # watchpoint on a cell that something unknown is scribbling:
    #
    #   FGX_MAME_EXTRA_ARGS='-debug -debugger none -debugscript /tmp/wp.txt \
    #                        -debuglog' python3 tools/mame_test/run.py NAME
    #
    # (the script must end in `go`, or the debugger stops at reset and the
    # test times out looking like a hang).  Deliberately not a manifest key:
    # a committed test must not depend on the debugger.
    _extra_args = os.environ.get("FGX_MAME_EXTRA_ARGS", "")
    if _extra_args:
        args += shlex.split(_extra_args)

    # Launch.  When headless, override SDL_VIDEODRIVER=dummy so SDL
    # doesn't open even an empty AppKit window — fully invisible.
    # macOS MAME otherwise creates a tiny black window even with
    # -video none.
    print(DIM_(f"  mame: {' '.join(args[:2])} … {' '.join(args[-6:])}"))
    print(DIM_(f"  scratch: {scratch}"))
    # Say which input path delivered the command.  A frames number is only
    # comparable against another taken the same way -- autoboot's typing is
    # 6.24 frames a character -- and the setting used to live only in the
    # environment, so a recorded number carried no trace of it.
    if mode == "test" and "command" in manifest:
        if primary_input == "inject":
            print(DIM_("  primary: inject (kernel-ring, one frame)"))
        else:
            print(DIM_(f"  primary: autoboot "
                       f"({len(manifest['command'])} chars typed by MAME)"))
    env = os.environ.copy()
    env["FGX_DEBUG_CONFIG"] = str(cfg_path)
    if headless and not debug:
        env["SDL_VIDEODRIVER"] = "dummy"
    with open(stdout, "w") as so, open(stderr, "w") as se:
        proc = subprocess.Popen(args, stdout=so, stderr=se, env=env)

    # host_proc: a program on the HOST, run alongside the emulated machine.
    # The wire tests need one -- a listener that must survive being accepted
    # can only be driven by a peer the guest cannot see itself, and nothing in
    # the guest can play that part (the loopback path does not detach the
    # listener, so it does not exercise the case at all).  It runs in a thread
    # so the completion-marker wait below is untouched; its combined output and
    # exit code land in scratch/hostproc.log for expect.host_proc_* to read.
    _hp = manifest.get("host_proc")
    if _hp:
        def _host_proc_thread():
            time.sleep(_hp.get("delay_s", 20))
            try:
                r = subprocess.run([str(a) for a in _hp["cmd"]], cwd=str(REPO),
                                   capture_output=True, text=True,
                                   timeout=_hp.get("timeout_s", 180))
                out, rc = r.stdout + r.stderr, r.returncode
            except subprocess.TimeoutExpired:
                out, rc = "host_proc TIMED OUT\n", 124
            except OSError as e:
                out, rc = "host_proc FAILED TO START: %s\n" % e, 125
            (scratch / "hostproc.log").write_text(out + "HOSTPROC_RC=%d\n" % rc)
        threading.Thread(target=_host_proc_thread, daemon=True).start()

    # Wait for clean exit (plugin will call machine:exit()) or timeout.
    # Python's wait must be longer than the plugin's exit_after_frame:
    # plugin = paste_frame_seconds + timeout_s; python = plugin + slack.
    paste_frame_s = paste_frame // 60
    plugin_cap_s  = paste_frame_s + manifest.get("timeout_s", 30)
    timeout_s     = plugin_cap_s + 8           # 8s slack for save/exit
    if mode == "boot_state":
        timeout_s = 25
    if debug:
        # In debug mode, let it run.  User SIGINTs when done.
        print(DIM_("  debug: MAME running with window.  ^C to stop."))
        try:
            proc.wait()
        except KeyboardInterrupt:
            proc.terminate()
            proc.wait(5)
        return ("debug", proc.pid, scratch)

    # The guest is DONE when the plugin says so, and only then.
    #
    # MAME often does not actually exit after the plugin asks it to, so waiting
    # for process death burned the whole timeout on a finished test: the plugin
    # logged `prompt-exit @ frame 804` ~13 s in and Python still sat for 45 s.
    #
    # My first attempt keyed on dump.json EXISTING, which was simply wrong --
    # do_dump() runs PERIODICALLY from frame 60 onward (eight "wrote dump.json"
    # lines in one boot), so the first mid-boot dump looked like a result and the
    # test was killed before the shell had even prompted.  It reported a FALSE
    # FAILURE, which is far worse than being slow.
    #
    # These two markers are the plugin's own completion signals, and they are
    # already what the caller uses to derive expect.exit_reason:
    #     "prompt-exit @ frame"        the prompt returned
    #     "exit_after_frame reached"   the hard frame cap
    # request_exit() prints the marker and THEN calls do_dump(), so the final
    # dump lands a frame or two later -- hence the grace wait below rather than
    # terminating the instant the marker appears.
    DONE_MARKERS = ("prompt-exit @ frame", "exit_after_frame reached")

    def _guest_done():
        try:
            with open(stdout, errors="ignore") as f:
                text = f.read()
        except OSError:
            return False
        return any(mark in text for mark in DONE_MARKERS)

    deadline = time.time() + timeout_s
    while time.time() < deadline:
        if proc.poll() is not None:
            return ("clean", proc.pid, scratch)
        if _guest_done():
            print(DIM_("  plugin signalled completion — waiting for the final dump"))
            # Give MAME a bounded chance to leave on its own; the final dump is
            # written before it would.
            for _ in range(20):                 # <= 10 s
                if proc.poll() is not None:
                    return ("clean", proc.pid, scratch)
                time.sleep(0.5)
            proc.terminate()
            try:
                proc.wait(3)
            except subprocess.TimeoutExpired:
                proc.kill()
                try:
                    proc.wait(20)
                except subprocess.TimeoutExpired:
                    print(DIM_(f"  pid {proc.pid} slow to die; continuing"))
            return ("clean", proc.pid, scratch)
        time.sleep(0.5)

    # Timeout — SIGTERM then SIGKILL.
    print(DIM_(f"  timeout ({timeout_s}s) — sending SIGTERM"))
    proc.terminate()
    try:
        proc.wait(2)
    except subprocess.TimeoutExpired:
        # MEASURED: a -nothrottle MAME takes ~14 s to be reaped after SIGKILL,
        # so the old wait(2)/wait(5) both "failed" on a process that was dying
        # perfectly well.  Waiting is not optional and the deadline must be
        # generous -- see below for what it costs to get this wrong.
        proc.kill()
        try:
            proc.wait(45)
        except subprocess.TimeoutExpired:
            # Report and CONTINUE.  A timeout is not the end of the test: the
            # screen dump has already been written, and the assertions are
            # checked from it -- so a slow-dying MAME still yields a real
            # verdict.  Raising here (which I briefly did) aborted the test
            # before it was ever evaluated, turning "timed out but verifiable"
            # into "no result at all".
            #
            # The cascade this guard was written for needed a QUEUE of later
            # tests to starve.  There is one test now, so there is nothing
            # downstream to poison.
            print(DIM_(f"  pid {proc.pid} slow to die; continuing to the "
                       f"assertions"))
    return ("timeout", proc.pid, scratch)


# ---------------------------------------------------------------------------
def extract_disk_to(scratch, dst):
    """Pull the boot volume's /root into dst.  Returns dst path.

    THE IMAGE DECIDES THE TOOL, exactly as it does for stage_files.  cadius
    speaks ProDOS and the suite's boot image is 2.11BSD now, so EXTRACTFOLDER
    pulled NOTHING -- silently, because its output is discarded -- and every
    `disk_files' and `faslog_contains' assertion in the corpus failed with
    "not present on disk".  That reads as the machine not having written the
    file, which is a claim about the guest; what it actually said was that the
    harness could not read the volume.  Measured 2026-09-06 on initrespawn.

    The layout it produces is the one find_extracted already expects: a `root'
    directory holding the files, no type/aux suffix (that is a cadius spelling,
    and find_extracted strips it either way).
    """
    dst = Path(dst)
    if dst.exists(): shutil.rmtree(dst)
    dst.mkdir(parents=True)
    disk = scratch / "fgxroot.fs"
    if _is_ufs_image(disk):
        out = dst / "root"
        out.mkdir(parents=True, exist_ok=True)
        fgxfs = str(REPO / "tools" / "fgxfs.py")
        r = subprocess.run([sys.executable, fgxfs, "ls", str(disk), "/root"],
                           capture_output=True, text=True)
        if r.returncode != 0:
            return dst
        for line in r.stdout.splitlines():
            # "-rw-r--r--   1   286828    291 name" -- five fields, and the
            # name is the last.  Only regular files: `.' and `..' are the
            # directory's own entries and would extract as empty stand-ins
            # that find_extracted could match.
            parts = line.split(None, 4)
            if len(parts) != 5 or not parts[0].startswith("-"):
                continue
            name = parts[4]
            g = subprocess.run(
                [sys.executable, fgxfs, "cat", str(disk), "/root/" + name],
                capture_output=True)
            if g.returncode == 0:
                (out / name).write_bytes(g.stdout)
        return dst
    subprocess.run(
        ["cadius", "EXTRACTFOLDER", str(disk), "/FGX/ROOT/", str(dst)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return dst


def find_extracted(extracted, virtual_path):
    """Translate /root/HI -> the actual extracted path (handles #aaTTTT suffix).

    ProDOS filenames are case-insensitive on the volume but cadius
    extracts them with their canonical (upper) case.  Match both.
    """
    name = virtual_path.lstrip("/").split("/")[-1].lower()
    # cadius may extract the /root dir as ROOT or root depending on the volume's
    # canonical case; match case-insensitively (ProDOS names are case-folding),
    # so validation works on a case-sensitive scratch filesystem too.
    root = None
    if extracted.exists():
        for d in extracted.iterdir():
            if d.is_dir() and d.name.lower() == "root":
                root = d
                break
    if root is None or not root.exists(): return None
    for p in root.iterdir():
        # cadius appends '#aaTTTT' (hex aux+type) to the name.
        stem = p.name.split("#", 1)[0].lower()
        if stem == name:
            return p
    return None


def read_faslog(extracted):
    p = find_extracted(extracted, "/root/faslog")
    if not p: return ""
    raw = p.read_bytes()
    return raw.replace(b"\r", b"\n").decode("latin-1")


# ---------------------------------------------------------------------------
def load_dump(scratch):
    p = Path(scratch) / "dump.json"
    if not p.exists():
        return None
    try:
        with open(p) as f:
            d = json.load(f)
    except json.JSONDecodeError:
        return None
    # Decode the kernel charbuf into readable rows for assertions /
    # post-mortem inspection.  Each cell is 7-bit ASCII; rows are 80 chars
    # wide (kernel CON_ROW_BYTES; CharBuf = CON_BUF_ROWS 100 x 80 = 8000 B).
    # NOTE: must match the kernel stride exactly — a wrong width misaligns
    # every row and splits on-screen substrings across the row join (which
    # is what silently broke df_test's '1K-blocks' match under the old 106).
    cb = (d.get("memory") or {}).get("charbuf")
    if cb:
        raw = bytes(b & 0x7F for b in bytes.fromhex(cb["hex"]))
        text = raw.decode("ascii", "replace")
        rows = []
        for i in range(0, len(text), 80):
            rows.append(text[i:i+80].rstrip())
        d["screen_text"] = rows
        d["screen_text_concat"] = "\n".join(r for r in rows if r)
    return d


def _dump_reference_lines(dump, exit_reason, cap_frame):
    """The frame of reference, the verdict, and the write-tap caveat.

    Rendered BELOW the register block so the line-1/line-2 contract above holds.
    """
    out   = []
    frame = dump.get("frame")
    paste = dump.get("paste_frame")
    if isinstance(frame, int) and isinstance(paste, int):
        out.append(f"paste_frame: {paste}   (frames above are ABSOLUTE; "
                   f"this dump is at paste+{frame - paste})")
    elif isinstance(paste, int):
        out.append(f"paste_frame: {paste}   (frames above are ABSOLUTE)")

    if exit_reason == "frame":
        where = (f" at paste+{cap_frame - paste}"
                 if isinstance(cap_frame, int) and isinstance(paste, int) else "")
        out.append(f"exit: FRAME CAP REACHED{where} -- THE RUN DID NOT FINISH. "
                   f"A capped run is not a slow run.")
    elif exit_reason == "prompt":
        out.append("exit: the prompt returned -- the command finished")
    elif exit_reason:
        out.append(f"exit: {exit_reason} -- neither the prompt nor the frame cap")

    n = len(dump.get("capture_log") or ())
    if n:
        out.append(f"captures: {n} write-tap entries. THE RECORDED PC IS READ "
                   f"AFTER THE STORE RETIRES, so a 3-byte `STA abs' taps at its "
                   f"own address + 3; searching the store's start address finds "
                   f"nothing.")
    return out


def write_dump_summary(scratch, dump, exit_reason=None, cap_frame=None):
    """Save a human-readable companion to dump.json alongside it.

    THE FIRST TWO LINES ARE A CONTRACT.  tools/tryprobe.sh reads line 1 for the
    frame and line 2 for the PC BY LINE NUMBER, and recovers the frame with
    `tr -d 'frame: '`, which deletes those CHARACTERS anywhere in the line -- so
    appending a word to line 1 yields garbage rather than a number.  Everything
    new goes BELOW the register block.  _selftest_dump_summary pins this.

    WHY THE REFERENCE LINE EXISTS: every frame the harness reports is ABSOLUTE,
    counted from power-on, and the first command is not delivered until
    `paste_frame` (boot_s * 60, so 3600 by default).  apple/fgx#377 spent twelve
    passes reading absolute frames as though the command had run, and described
    a stop 31 frames INTO the paste as "a ~400-byte command wedges".  Both
    numbers needed to catch that were already in the dump; nothing printed them.
    """
    if not dump: return
    p = Path(scratch) / "dump.txt"
    lines = []
    r = dump.get("registers", {})
    def hx(v, w=4): return ("%0"+str(w)+"X") % (v & ((1<<(4*w))-1))
    lines.append(f"frame: {dump.get('frame')}")
    lines.append(f"PC=${hx(r.get('PB',0),2)}/{hx(r.get('PC',0),4)}  "
                 f"S=${hx(r.get('S',0))}  D=${hx(r.get('D',0))}")
    lines.append(f"A=${hx(r.get('A',0))}  X=${hx(r.get('X',0))}  "
                 f"Y=${hx(r.get('Y',0))}")
    lines.append(f"P=${hx(r.get('P',0),2)}  DB=${hx(r.get('DB',0),2)}  "
                 f"E={r.get('E',0)}")
    lines.extend(_dump_reference_lines(dump, exit_reason, cap_frame))
    lines.append("")
    lines.append("screen text:")
    for row in dump.get("screen_text", []):
        if row: lines.append("  " + row)
    p.write_text("\n".join(lines) + "\n")


# ---------------------------------------------------------------------------
# Every key check_expectations knows how to evaluate.  An `expect` block used
# to be read key-by-key with .get(), so a MISSPELLED key was silently dropped
# and its assertion never ran — ttysprobe shipped `screen_not_contains` (there
# is no such key; it is `screen_lacks`) and reported green for weeks with that
# assertion dead.  That is the same vacuous-check failure this suite keeps
# hitting, in the one place that is supposed to catch it.  Fail closed on
# anything unrecognised: a typo is now a red test, not a missing one.
KNOWN_EXPECT_KEYS = {
    "exit_clean", "exit_reason", "disk_files", "faslog_contains", "registers",
    "screen_contains", "screen_lacks", "diff_against", "memory",
    "klog_contains", "klog_lacks", "klog_region", "check_script",
    "host_proc_rc", "host_proc_contains",
    # card_screen_min: at least this many of the plugin's pixel samples of a
    # Second Sight card's own screen differ from the screen's most common
    # value.  The card draws its cell buffer into a screen of its own, so
    # this is the only evidence that the console reached the card; the
    # charbuf capture behind screen_contains is the same with or without it.
    "card_screen_min",
    # echo_ok: needles this manifest KNOWINGLY allows to also appear in the
    # command line MAME types.  Evaluated by tools/check_vacuous_assertions.py,
    # not here -- it asserts nothing at runtime.  Listing a needle there is a
    # statement that the author checked the assertion still discriminates, and
    # the manifest's description must say how.
    "echo_ok",
}


def check_expectations(manifest, exit_status, dump, extracted, *, update=False):
    """Return (passed, [messages])."""
    expect = manifest.get("expect", {})
    msgs = []
    ok = True

    def fail(msg):
        nonlocal ok
        ok = False
        msgs.append(FAIL_("  ✗ ") + msg)

    def passmsg(msg):
        msgs.append(OK_("  ✓ ") + msg)

    unknown = sorted(set(expect) - KNOWN_EXPECT_KEYS)
    if unknown:
        fail("unknown expect key(s) " + ", ".join(repr(k) for k in unknown)
             + " — nothing evaluates them, so whatever they assert is DEAD. "
             + "Known keys: " + ", ".join(sorted(KNOWN_EXPECT_KEYS)))

    # exit_clean.
    if expect.get("exit_clean") is True:
        if exit_status != "clean":
            fail(f"expected clean exit (via marker), got {exit_status}")
        else:
            passmsg("MAME exited via marker (not timeout)")

    # exit_reason: how MAME left — "prompt" (shell prompt returned, i.e. the
    # command finished and control came back) vs "frame" (ran out the hard frame
    # cap = hung).  TCDONE-style output prints before a deadlock, so this is the
    # only reliable signal for the spawned-writer pipeline-deadlock regression.
    want_reason = expect.get("exit_reason")
    if want_reason:
        got = manifest.get("_exit_reason", "unknown")
        if got != want_reason:
            fail(f"expected exit_reason '{want_reason}', got '{got}'")
        else:
            passmsg(f"exit_reason = {got}")

    # disk_files.
    for f in expect.get("disk_files", []):
        actual = find_extracted(extracted, f["path"])
        if not actual:
            fail(f"disk file {f['path']} not present on disk")
            continue
        size = actual.stat().st_size
        if "size" in f and size != f["size"]:
            fail(f"{f['path']} size {size} != expected {f['size']}")
            continue
        if "sha256" in f:
            digest = hashlib.sha256(actual.read_bytes()).hexdigest()
            if update:
                f["sha256"] = digest
                passmsg(f"recorded sha256 for {f['path']}: {digest[:12]}…")
            elif digest != f["sha256"]:
                fail(f"{f['path']} sha256 {digest[:12]}… != {f['sha256'][:12]}…")
            else:
                passmsg(f"{f['path']} sha256 matches ({size} B)")

    # faslog markers.
    if "faslog_contains" in expect:
        log = read_faslog(extracted)
        for needle in expect["faslog_contains"]:
            if needle in log:
                passmsg(f"faslog contains '{needle}'")
            else:
                fail(f"faslog missing '{needle}'")

    # Registers.
    if "registers" in expect and dump:
        regs = dump.get("registers", {})
        for k, want in expect["registers"].items():
            if k.endswith("_hex"):
                base = k[:-4]
                actual = regs.get(base)
                if actual is None:
                    fail(f"register {base} not in dump")
                    continue
                # "KERNEL" = the live kernel code+data bank, read from the
                # loader anchor by the plugin and reported as kernel_bank.
                # Lets one test gate both the relocating ($20) and legacy
                # ($02) builds: under reloc DB/PB = $20, legacy = $02.
                if isinstance(want, str) and want.upper() == "KERNEL":
                    want_int = dump.get("kernel_bank")
                    if want_int is None:
                        fail(f"reg {base}: test wants KERNEL bank but dump "
                             f"has no kernel_bank (old plugin?)")
                        continue
                    label = f"KERNEL=${want_int:X}"
                else:
                    want_int = int(want, 16)
                    label = f"${want_int:X}"
                if actual == want_int:
                    passmsg(f"reg {base} = ${actual:X} ✓ ({label})")
                else:
                    # Carry the diagnosis in the failure line (2026-07-17:
                    # a bare "DB=$0" cost six boots to re-learn what the
                    # dump already knew — CPU sampled in firmware).
                    ctx = (f" [PC=${regs.get('PC', 0):X} PB=${regs.get('PB', 0):X}"
                           f" dumpframe={dump.get('frame', '?')}"
                           f" last_in_kernel={dump.get('registers_frame', '?')}"
                           f" in_kernel={dump.get('registers_in_kernel', '?')}]")
                    fail(f"reg {base} = ${actual:X}, want {label}{ctx}")
            else:
                actual = regs.get(k)
                if actual != want:
                    fail(f"reg {k} = {actual}, want {want}")
                else:
                    passmsg(f"reg {k} = {actual} ✓")

    # Screen text content.  FAIL-CLOSED on a missing dump: a test whose
    # manifest asserts screen or register state must not pass when the
    # fgxdebug plugin produced no dump.json — that is exactly what happens
    # when the plugin dies silently (e.g. the pre-fix GC'd notifier
    # subscriptions, or a MAME that rejects the boot-slot args and exits
    # instantly, which run_mame's wall-clock wait misreads as "clean").
    if dump is None and (expect.get("screen_contains")
                         or expect.get("screen_lacks")
                         or expect.get("registers")):
        fail("no dump.json from fgxdebug — plugin never ran; "
             "screen/register expectations cannot be verified")
    if dump:
        # A DEAD RELOCATION ANCHOR IS A CRASH REPORT, NOT A BLANK SCREEN.
        #
        # kernel_bank comes off the anchor at $00:032C; when the magic byte is
        # gone the plugin falls back to bank $02 and every kbank/conbank region
        # -- the console among them -- resolves into the wrong bank.  The screen
        # then reads as NULs, so `screen_lacks PANIC' and `screen_lacks BRK' pass
        # VACUOUSLY and the only complaint is "screen missing <needle>", which
        # reads as "the program did not print it" when what happened is that the
        # machine died and took bank 0 with it.
        #
        # This cost a full investigation: a run whose probe had ALREADY printed
        # PASS (confirmed by sampling the console at a frame before the crash)
        # was reported as a probe failure, and the two lacks-assertions that
        # would have named it a crash both reported green.
        #
        # Named separately from the EMPTY-screen guard below because the cause is
        # different and so is the next step: an empty capture means look at the
        # capture, a dead anchor means look for a wild jump into bank 0.  Old
        # plugins do not emit the key; absent is not false.
        if dump.get("kernel_bank_anchor") is False:
            fail("THE MACHINE CRASHED: the bank-0 relocation anchor at "
                 "$00:032C is gone, so kernel_bank fell back to "
                 f"${dump.get('kernel_bank', 0):02X} and every kernel/console "
                 "region in this dump was read from the WRONG BANK. The screen "
                 "text below is not the machine's screen, and no 'screen_lacks' "
                 "assertion in this run means anything. A wild jump into bank 0 "
                 "leaves a COP/BRK loop whose stack wraps the bank and erases "
                 "the anchor -- sample the console at an earlier frame to see "
                 "how far the run actually got.")
        screen = dump.get("screen_text_concat", "")
        # POSITIVE EVIDENCE BEFORE ABSENCE.  A `screen_lacks` assertion passes
        # when the needle is not there -- which is ALSO what an empty capture
        # looks like.  18 of 318 manifests carry only screen_lacks, so a
        # capture that silently came back blank would report them all green.
        # Require the screen to be non-empty before any absence assertion is
        # allowed to count.  (screen_contains needs no such guard: it demands a
        # positive match and already fails on an empty capture.)
        if expect.get("screen_lacks") and not screen.strip():
            fail("screen capture is EMPTY — 'screen_lacks' assertions cannot be "
                 "evaluated (absence would be indistinguishable from a capture "
                 "that never happened)")
        screen_bad = False
        for needle in expect.get("screen_contains", []):
            if needle in screen:
                passmsg(f"screen contains '{needle}'")
            else:
                fail(f"screen missing '{needle}'")
                screen_bad = True
        for needle in expect.get("screen_lacks", []):
            if needle in screen:
                fail(f"screen unexpectedly contains '{needle}'")
                screen_bad = True
            else:
                passmsg(f"screen lacks '{needle}' ✓")
        # THE SCREEN IS THE EVIDENCE, AND IT USED TO BE THROWN AWAY.  A red
        # left "✗ screen missing 'X'" in the suite log and nothing else: the
        # scratch dir is reused by the next run, so the dump that would say
        # WHICH step failed is gone by the time anyone looks.  That is what
        # made apple/fgx#262's two flakes un-diagnosable -- both were re-run to
        # green because there was nothing left to read -- and re-running a red
        # is the reflex a gate must never teach.  Print it here, where the
        # failure is still in hand.  Blank lines are dropped and the tail is
        # capped: a fixture that prints steadily would otherwise bury its own
        # verdict, and it is the END of the output that says how far it got.
        if screen_bad:
            lines = [l.rstrip() for l in screen.splitlines() if l.strip()]
            shown = lines[-24:]
            head = (f"  --- screen at the assertion "
                    f"({len(shown)} of {len(lines)} non-blank lines) ---")
            msgs.append(DIM_(head))
            for l in shown:
                msgs.append(DIM_("  | " + l[:120]))
        if "card_screen_min" in expect:
            want = int(expect["card_screen_min"])
            cs = dump.get("card_screen") or {}
            got = cs.get("nonmajority", 0)
            if not cs.get("present"):
                fail("card_screen_min: the machine has no Second Sight screen "
                     "(is mame_slots set to add the card?)")
            elif got < want:
                fail(f"the card's screen shows {got} non-background samples "
                     f"of {cs.get('samples', 0)}, want at least {want}")
            else:
                passmsg(f"the card's screen shows {got} non-background samples "
                        f"of {cs.get('samples', 0)}")

    # Optional: kernel-statics diff against a baseline dump.  If
    # expect["diff_against"] points to another scratch dir's
    # dump.json, report any region whose hex changed.  Useful for
    # detecting unintended kernel-state mutations.
    if dump and "diff_against" in expect:
        base_path = Path(expect["diff_against"])
        if not base_path.exists():
            fail(f"diff_against baseline {base_path} missing")
        else:
            try:
                with open(base_path) as f: base = json.load(f)
            except Exception as e:
                fail(f"diff_against load: {e}"); base = None
            if base:
                base_mem = base.get("memory") or {}
                cur_mem  = dump.get("memory") or {}
                changed = []
                for name, region in cur_mem.items():
                    if name not in base_mem: continue
                    if region["hex"] != base_mem[name]["hex"]:
                        changed.append(name)
                if changed:
                    fail(f"kernel state diff: {', '.join(changed)} changed")
                else:
                    passmsg(f"kernel state stable vs {base_path.name}")

    # Memory regions.
    if "memory" in expect and dump:
        mem = dump.get("memory", {})
        for chk in expect["memory"]:
            name = chk["name"]
            if name not in mem:
                fail(f"memory region '{name}' not dumped")
                continue
            got_hex = mem[name]["hex"]
            if "hex_starts_with" in chk:
                want = chk["hex_starts_with"].lower()
                if got_hex.lower().startswith(want):
                    passmsg(f"mem.{name} starts with {want[:16]}…")
                else:
                    fail(f"mem.{name} hex={got_hex[:32]}… want prefix {want[:32]}…")
            elif "ascii_contains" in chk:
                # 7-bit decode, matching how CharBuf is rendered for
                # screen_contains.  Added for virtual consoles: the assertion
                # that matters is "VC1 received this text", and a CharBuf is
                # characters, not a hex blob -- expressing it as hex_eq would
                # mean pinning 8000 bytes to assert six.
                raw = bytes(b & 0x7F for b in bytes.fromhex(got_hex)) if got_hex else b""
                text = raw.decode("ascii", "replace")
                want = chk["ascii_contains"]
                if not got_hex:
                    fail(f"mem.{name} is EMPTY -- region unresolved (a vcbank "
                         f"region reads empty when that VC has no bank yet)")
                elif want in text:
                    passmsg(f"mem.{name} contains '{want}'")
                else:
                    fail(f"mem.{name} lacks '{want}'")
            elif "hex_eq" in chk:
                want = chk["hex_eq"].lower()
                if got_hex.lower() == want:
                    passmsg(f"mem.{name} = {want[:24]}…")
                else:
                    fail(f"mem.{name} hex={got_hex[:32]}… want {want[:32]}…")
            elif "sha256" in chk:
                # Golden hash of a (possibly large) region — e.g. the 32000-byte
                # SHR framebuffer, where a full hex_eq would be unwieldy.  Record
                # with --update-goldens (mirrors disk_files sha256).
                raw = bytes.fromhex(got_hex)
                digest = hashlib.sha256(raw).hexdigest()
                if update:
                    chk["sha256"] = digest
                    passmsg(f"recorded sha256 for {name}: {digest[:12]}… ({len(raw)} B)")
                elif digest != chk["sha256"]:
                    fail(f"mem.{name} sha256 {digest[:12]}… != "
                         f"{chk['sha256'][:12]}… ({len(raw)} B)")
                else:
                    passmsg(f"mem.{name} sha256 matches ({len(raw)} B)")

    # klog_contains: decoded (bit-7-masked) substring match over a dumped memory
    # region (default the 'klog' ring) — for kernel-log lines that scroll off-screen.
    if "klog_contains" in expect and dump:
        mem = dump.get("memory", {})
        region = expect.get("klog_region", "klog")
        if region not in mem:
            fail(f"klog region '{region}' not dumped (add it to memory_regions)")
        elif not mem[region].get("hex"):
            # An UNRESOLVED region, not an empty log.  A pointer-indirect region
            # whose ptr_addr misses (e.g. the kernel DP page moved and the
            # manifest still names the old address) dumps addr 0 and an empty
            # body -- and every klog_contains then failed as "klog lacks X",
            # which reads as "the kernel did not log it" when in truth nothing
            # was ever captured.  That cost a wrong diagnosis on 2026-08-05.
            # Say which it is.
            fail(f"klog region '{region}' resolved to addr "
                 f"${mem[region].get('addr', 0):06X} and captured NOTHING -- "
                 f"the pointer is stale, so this is not a claim about content")
        else:
            raw = bytes.fromhex(mem[region]["hex"])
            text = "".join(chr(b & 0x7F) for b in raw)
            for needle in expect["klog_contains"]:
                if needle in text:
                    passmsg(f"klog contains '{needle}'")
                else:
                    fail(f"klog lacks '{needle}'")

    # klog_lacks: the ABSENCE half.  Same region and same decoding as
    # klog_contains, and it repeats that key's guards on purpose -- an absence
    # assertion against a region that was never captured is the most vacuous
    # check there is, since "not dumped" and "not logged" both look like a pass.
    if "klog_lacks" in expect and dump:
        mem = dump.get("memory", {})
        region = expect.get("klog_region", "klog")
        if region not in mem:
            fail(f"klog region '{region}' not dumped (add it to memory_regions)")
        elif not mem[region].get("hex"):
            fail(f"klog region '{region}' resolved to addr "
                 f"${mem[region].get('addr', 0):06X} and captured NOTHING -- "
                 f"an absence proves nothing against an empty capture")
        else:
            raw = bytes.fromhex(mem[region]["hex"])
            text = "".join(chr(b & 0x7F) for b in raw)
            for needle in expect["klog_lacks"]:
                if needle in text:
                    fail(f"klog unexpectedly contains '{needle}'")
                else:
                    passmsg(f"klog lacks '{needle}'")

    # check_script: run an external analyzer against the raw dump.json and gate
    # on its exit code (0 = pass; anything else — including an "inconclusive"
    # rc=2 — fails).  Path relative to tools/mame_test.  Keeps dump-analyzing
    # tests fail-closed: the verdict runs on every `run.py NAME`, not only when
    # someone remembers to invoke the checker by hand.
    if "check_script" in expect:
        script = HERE / expect["check_script"]
        dump_path = Path(extracted).parent / "dump.json"
        if not script.exists():
            fail(f"check_script {expect['check_script']} not found")
        elif not dump_path.exists():
            fail(f"check_script {script.name}: no dump.json in {dump_path.parent}")
        else:
            r = subprocess.run([sys.executable, str(script), str(dump_path)],
                               capture_output=True, text=True)
            tail = (r.stdout + r.stderr).strip().splitlines()
            last = f" — {tail[-1]}" if tail else ""
            if r.returncode == 0:
                passmsg(f"check_script {script.name} rc=0{last}")
            else:
                fail(f"check_script {script.name} rc={r.returncode}{last}")

    # host_proc_rc / host_proc_contains: the verdict of the host-side program
    # declared by the top-level `host_proc` key.  A missing result is a FAILURE
    # rather than a skip -- a probe that never ran and a probe that found
    # nothing produce the same silence, and this suite has shipped that
    # confusion before.
    if "host_proc_rc" in expect or "host_proc_contains" in expect:
        hp = manifest.get("_hostproc")
        if hp is None:
            fail("host_proc produced no result (did the manifest declare the "
                 "top-level 'host_proc' key?)")
        else:
            if "host_proc_rc" in expect:
                want, got = expect["host_proc_rc"], hp["rc"]
                if got == want:
                    passmsg(f"host_proc rc={got}")
                else:
                    fail(f"host_proc rc={got}, expected {want}")
            for needle in expect.get("host_proc_contains", []):
                if needle in hp["text"]:
                    passmsg(f"host_proc output contains '{needle}'")
                else:
                    fail(f"host_proc output lacks '{needle}'")

    return ok, msgs


# ---------------------------------------------------------------------------

def _selftest_dump_summary():
    """The reference block must fire, and the line-1/line-2 contract must hold.

    Both halves matter.  A summary that never says "DID NOT FINISH" is the
    defect this exists to prevent (apple/fgx#377 read a capped run as a slow
    one).  A summary that says it by rewriting line 1 breaks tools/tryprobe.sh,
    which reads the frame and the PC BY LINE NUMBER -- so the shape of those two
    lines is asserted here rather than left to whoever edits next.
    """
    import tempfile
    fails = []

    def render(**kw):
        base = {"frame": 2731, "paste_frame": 2700,
                "registers": {"PB": 0x7C, "PC": 0x9105, "S": 0xF1F1,
                              "D": 0x1100, "A": 0, "X": 0, "Y": 0,
                              "P": 4, "DB": 0x7C, "E": 0},
                "screen_text": ["fgx# cat /etc/passwd", "root:x:0:0"]}
        base.update(kw.pop("dump", {}))
        with tempfile.TemporaryDirectory() as d:
            write_dump_summary(d, base, **kw)
            return (Path(d) / "dump.txt").read_text()

    # 1. THE CONTRACT tryprobe.sh depends on: line 1 is `frame: <int>' and
    #    nothing else, line 2 is the PC.  `tr -d 'frame: '` on line 1 must
    #    still yield the bare number.
    capped = render(exit_reason="frame", cap_frame=4500)
    l = capped.splitlines()
    if not re.match(r"^frame: \d+$", l[0]):
        fails.append(f"line 1 is no longer `frame: <int>\' -- tryprobe.sh "
                     f"parses it by line number: {l[0]!r}")
    if l[0].translate({ord(c): None for c in "frame: "}) != "2731":
        fails.append("tryprobe.sh's `tr -d \'frame: \'' no longer yields the "
                     "frame from line 1")
    if not l[1].startswith("PC=$"):
        fails.append(f"line 2 is no longer the PC line: {l[1]!r}")

    # 2. A CAPPED RUN MUST SAY SO, in words that cannot be read as "slow".
    if "FRAME CAP REACHED" not in capped or "DID NOT FINISH" not in capped:
        fails.append("a capped run does not announce that it never finished")
    if "paste+1800" not in capped:
        fails.append("the cap is not reported relative to the paste")

    # 3. THE FRAME OF REFERENCE, which is the whole point.
    if "paste_frame: 2700" not in capped or "paste+31" not in capped:
        fails.append("the dump does not restate its frame against the paste")
    if "ABSOLUTE" not in capped:
        fails.append("the dump does not say its frames are absolute")

    # 4. AND IT MUST NOT CRY WOLF: a run that finished says the opposite.
    done = render(dump={"frame": 2869}, exit_reason="prompt", cap_frame=4500)
    if "DID NOT FINISH" in done or "FRAME CAP" in done:
        fails.append("a finished run was reported as capped")
    if "the prompt returned" not in done:
        fails.append("a finished run does not say the prompt returned")

    # 5. THE WRITE-TAP CAVEAT, present only when there are captures to misread.
    caps = render(dump={"capture_log": [{"PC": 1}, {"PC": 2}]},
                  exit_reason="prompt")
    if "AFTER THE STORE RETIRES" not in caps:
        fails.append("a dump carrying captures does not warn that the tap PC "
                     "is post-retire")
    if "AFTER THE STORE RETIRES" in done:
        fails.append("the post-retire caveat fired with no captures present")

    # 6. THE REGEX CONSUMERS still find the screen (run_runtime.py, multibank).
    if "screen text:" not in capped or "root:x:0:0" not in capped:
        fails.append("the screen block was disturbed")

    if fails:
        for f in fails:
            print("  " + f, file=sys.stderr)
        print("run.py dump-summary self-test: %d FAILURE(S)" % len(fails))
        return 1
    print("run.py dump-summary self-test: OK (restates the frame against the "
          "paste, calls a capped run unfinished without crying wolf on a "
          "finished one, warns that a write-tap PC is post-retire, and keeps "
          "line 1/line 2 in the shape tryprobe.sh parses)")
    return 0


def read_config_value(key, path=None):
    """One `section.name = value` out of cfg/system.cfg, or None.

    Deliberately a five-line reader rather than an import of the config
    generator: this needs to answer "what does the file say" for a skip
    decision, and pulling in the generator would couple the test harness to a
    build tool that derives bank-0 geometry as a side effect.
    """
    p = Path(path) if path else (REPO / "cfg" / "system.cfg")
    try:
        text = p.read_text()
    except OSError:
        return None
    for line in text.splitlines():
        line = line.split("#", 1)[0].strip()
        if not line or "=" not in line:
            continue
        name, _, val = line.partition("=")
        if name.strip() == key:
            return val.strip()
    return None


def _selftest_config_requirement():
    """A config requirement must SKIP on the wrong value and run on the right.

    Both directions, because a requirement that never fires is a test silently
    running against a kernel that cannot satisfy it -- which is the failure
    this exists to prevent, one level up.
    """
    import tempfile
    fails = []
    with tempfile.NamedTemporaryFile("w", suffix=".cfg", delete=False) as f:
        f.write("# comment\nkernel.vfsprobe = 0   # trailing comment\n"
                "kernel.nproc = 11\n")
        p = f.name
    if read_config_value("kernel.vfsprobe", p) != "0":
        fails.append("a value with a trailing comment was not parsed")
    if read_config_value("kernel.nproc", p) != "11":
        fails.append("a plain value was not parsed")
    if read_config_value("kernel.absent", p) is not None:
        fails.append("a missing key did not read as None")
    os.unlink(p)
    if read_config_value("kernel.vfsprobe", "/nonexistent") is not None:
        fails.append("an unreadable config did not read as None")
    for v in fails:
        print(f"self-test FAILED: {v}", file=sys.stderr)
    if not fails:
        print("run.py config-requirement self-test: OK")
    return 1 if fails else 0


def unmet_requirement(manifest):
    """Why this test cannot run here, or None if it can.

    A few tests need something the repo cannot supply: a second ProDOS volume
    passed via FGX_EXTRA_HARDS, or an external serial feeder listening on a
    socket.  Without a way to say so they simply FAILED on every machine that
    lacked the rig, which made the full suite unpassable -- and release.sh
    requires a full green suite, so `./release.sh` could never succeed.

    Requirements are DECLARED, never inferred.  A test is skipped only because
    its manifest asked to be, and every skip is named in the summary: the point
    is to distinguish "did not run here" from "passed", not to hide failures.

        "requires": {"env": ["FGX_EXTRA_HARDS"],
                     "tcp": "localhost:25232",
                     "peer_script": "tools/mame_test/serial_feeder.py",
                     "config": {"kernel.vfsprobe": "1"},
                     "reason": "..."}

    `peer_script` names the external program that satisfies a `tcp`
    requirement.  It is not launched here -- the point of `tcp` is that the peer
    is outside this harness -- but naming it puts it in the RESULT CACHE KEY,
    so weakening the peer cannot inherit a strong run's cached PASS.

    `config` names cfg/system.cfg keys the KERNEL had to be built with.  Some
    probes exist only in a kernel configured for them, and without this the
    test does not skip -- it runs against a kernel where the probe was compiled
    out and reports a red about a missing line, which reads exactly like the
    subsystem being broken.  The value is compared as text against the config
    file, so it describes the SOURCE the image was built from; a test run
    against a stale image can still lie, and only --fresh after a rebuild
    settles that.
    """
    req = manifest.get("requires")
    if not req:
        return None
    reason = req.get("reason", "")
    for var in req.get("env", []):
        if not os.environ.get(var):
            return f"{var} is not set" + (f" -- {reason}" if reason else "")
    # `files' NAMES A BUILD PRODUCT THE REPO CANNOT SUPPLY ON ITS OWN -- an
    # image carved from something under gitignored examples/, say.  Without the
    # check such a test does not skip: extra_hards fatal()s on the missing
    # image, which is a RED on every machine but the one that built it by hand.
    # Paths are repo-relative.  (No manifest uses this today; `bsd211mnt' was
    # its one customer and was retired 2026-09-08.  Kept because the shape
    # recurs and the failure it prevents is a confusing one.)
    for f in req.get("files", []):
        if not (REPO / f).exists():
            return f"{f} does not exist" + (f" -- {reason}" if reason else "")
    for key, want in (req.get("config") or {}).items():
        got = read_config_value(key)
        if got != str(want):
            return (f"cfg/system.cfg has {key} = {got or '(unset)'}, "
                    f"needs {want}" + (f" -- {reason}" if reason else ""))
    tcp = req.get("tcp")
    if tcp:
        host, _, port = tcp.rpartition(":")
        s = socket.socket()
        s.settimeout(0.5)
        try:
            s.connect((host or "localhost", int(port)))
        except OSError:
            return (f"nothing listening on {tcp}"
                    + (f" -- {reason}" if reason else ""))
        finally:
            s.close()
    return None


def _require_fresh_build(src_disk):
    """Refuse to boot an image the build graph says is out of date.

    THE GATE ALREADY CANNOT DO THIS -- tools/gate.sh builds and fails out on a
    bad build before it runs anything.  What it cannot cover is the ad-hoc
    loop: edit, build, run one test.  There, a failed build is easy to miss,
    and `ninja || { retry; }` under `set -e` hides it outright, because a
    compound on the left of || is exempt from errexit.  The result is a green
    or red verdict about an image from an hour ago, which is worse than either
    -- a fix reads as ineffective and gets rewritten, or a defect reads as
    fixed.  That happened three times in one session (2026-08-16) and cost
    hours; the last of them nearly shipped a wrong kernel diagnosis.

    ASK NINJA, NOT THE CLOCK.  `ninja -n` reports what the graph would still
    do.  mtimes cannot answer this: an artifact regenerated byte-identically
    is newer and NOT stale, which this tree has documented the hard way.

    FGX_ALLOW_STALE=1 opts out, for the cases that want a deliberately old
    image (a stale-module test, bisecting against a prebuilt image).
    """
    if os.environ.get("FGX_ALLOW_STALE"):
        return
    if src_disk != DISK_BASE:          # a manifest's own image is not ours to judge
        return
    try:
        r = subprocess.run(["ninja", "-n"], cwd=REPO, capture_output=True,
                           text=True, timeout=120)
    except Exception:
        return                          # no ninja here: not our business to fail
    if r.returncode != 0:
        fatal("the build graph is BROKEN (`ninja -n` failed), so "
              f"{src_disk.name} cannot be the tree you are testing:\n"
              f"{r.stdout.strip()[:400]}{r.stderr.strip()[:400]}\n"
              "Fix the build, or set FGX_ALLOW_STALE=1 to test the old image "
              "on purpose.")
    out = (r.stdout or "").strip()
    if "no work to do" not in out.lower():
        pending = [l for l in out.splitlines() if l.strip()][:6]
        fatal(f"{src_disk.name} is STALE -- `ninja -n` still has work to do, so "
              "this run would report on an image that is not your tree:\n  "
              + "\n  ".join(pending)
              + "\nRun `ninja` first, or set FGX_ALLOW_STALE=1 to test the old "
                "image on purpose.")



def run_one(manifest_path, *, debug=False, headless=True, update=False,
            no_state=False):
    m = load_manifest(manifest_path)
    if no_state: m["_no_state"] = True

    name = m["name"]
    desc = m.get("description", "")
    print(BOLD_(f"\n→ {name}"), DIM_(f"({desc})") if desc else "")

    exit_status, _, scratch = run_mame(
        manifest=m, mode="test", debug=debug, headless=headless)

    extracted = extract_disk_to(scratch, scratch / "extracted")
    dump      = load_dump(scratch)

    # Derive how MAME actually left from the plugin log: a returned shell prompt
    # ("prompt-exit") vs running out the hard frame cap ("exit_after_frame").
    # A manifest can assert this via expect.exit_reason -- essential for the
    # spawned-writer pipeline deadlock regression, where the command's output
    # prints BEFORE any hang so only the exit reason separates pass from wedge.
    #
    # DERIVED BEFORE THE SUMMARY IS WRITTEN so dump.txt can carry the verdict.
    # It used to be computed thirty lines further down, which is why a capped
    # run and a finished one were indistinguishable in the one file a human
    # opens, and why apple/fgx#377's first pass read a hang as a slow run.
    try:
        logtxt = (scratch / "mame_stdout.log").read_text(errors="ignore")
    except OSError:
        logtxt = ""
    if "prompt-exit @ frame" in logtxt:
        m["_exit_reason"] = "prompt"
    elif "exit_after_frame reached" in logtxt:
        m["_exit_reason"] = "frame"
    else:
        m["_exit_reason"] = "unknown"

    _paste = dump.get("paste_frame") if isinstance(dump, dict) else None
    _cap   = (_paste + int(m.get("timeout_s", 30)) * 60
              if isinstance(_paste, int) else None)
    write_dump_summary(scratch, dump, exit_reason=m["_exit_reason"],
                       cap_frame=_cap)
    if m["_exit_reason"] == "frame":
        print(FAIL_("  exit: FRAME CAP REACHED -- the run did NOT finish "
                    "(a capped run is not a slow run)"))

    # Collect the host-side program's verdict.  MAME can leave before the probe
    # is finished, so wait a bounded while for the log rather than reading a
    # race -- but never wait forever, or a probe that hangs takes the run with
    # it instead of failing it.
    if m.get("host_proc"):
        hp_log = scratch / "hostproc.log"
        for _ in range(120):                    # <= 60 s
            if hp_log.exists():
                break
            time.sleep(0.5)
        if hp_log.exists():
            text = hp_log.read_text(errors="ignore")
            rc = -1
            for line in text.splitlines():
                if line.startswith("HOSTPROC_RC="):
                    rc = int(line.split("=", 1)[1])
            m["_hostproc"] = {"rc": rc, "text": text}
            print(DIM_("  host_proc:"))
            for line in text.strip().splitlines():
                print(DIM_("    " + line))

    ok, msgs  = check_expectations(m, exit_status, dump, extracted,
                                   update=update)
    for msg in msgs:
        print(msg)

    if update:
        # Write updated manifest back to disk.
        m.pop("_hostproc", None)        # a run result, not a golden
        with open(manifest_path, "w") as f:
            json.dump(m, f, indent=2)
            f.write("\n")
        print(DIM_(f"  updated {manifest_path.name}"))

    return ok


def boot_state():
    """Cold-boot once, capture save state at shell prompt."""
    print(BOLD_("\n→ boot-state: cold-booting kernel + saving state"))
    # Dummy manifest: no command, just wait for shell + save.
    m = {"name": "_boot_state", "timeout_s": 25}
    exit_status, _, scratch = run_mame(
        manifest=m, mode="boot_state", debug=False, headless=True)
    state_file = STATE_DIR / "apple2gs" / f"{STATE_NAME}.sta"
    if state_file.exists():
        print(OK_(f"  ✓ saved {state_file} ({state_file.stat().st_size} B)"))
        print(DIM_(f"  exit={exit_status}; future runs will skip ~10s of boot."))
        return True
    else:
        print(FAIL_("  ✗ save_state did not produce a file."))
        print(DIM_(f"  Looked at {state_file}"))
        # Best-effort show MAME stderr from whichever scratch dir
        # the boot-state run used.
        boot_stderr = Path("/tmp/fgx_test__boot_state/mame_stderr.log")
        if boot_stderr.exists():
            print(DIM_(f"  MAME stderr tail:"))
            sys.stderr.write(boot_stderr.read_text()[-1500:])
        return False


# ---------------------------------------------------------------------------
def main():
    # Before argparse: the self-test must run without a MAME install.
    if "--self-test" in sys.argv:
        return (_selftest_manifest_keys() or _selftest_config_requirement()
                or _selftest_dump_summary())
    p = argparse.ArgumentParser()
    p.add_argument("names", nargs="*",
                   help="test names to run (default: all)")
    p.add_argument("--list",          action="store_true")
    p.add_argument("--debug",         action="store_true",
                   help="show MAME window; leave running on failure")
    p.add_argument("--no-state",      action="store_true",
                   help="force cold-boot for this run")
    p.add_argument("--boot-state",    action="store_true",
                   help="cold-boot once, save 'shell_ready' state")
    p.add_argument("--update-goldens", action="store_true")
    p.add_argument("--window", "--show", action="store_true", dest="window",
                   help="show the visible MAME window (bgfx render).  Default is "
                        "headless/invisible (-video none + SDL dummy) so runs — "
                        "especially bulk/background ones — never steal focus.")
    # Deprecated: headless is now the default.  Accepted as a no-op so existing
    # CI invocations that still pass --headless keep working.
    p.add_argument("--headless",      action="store_true",
                   help=argparse.SUPPRESS)
    p.add_argument("--group",
                   help="run a named group from tools/mame_test/groups/<NAME>.txt "
                        "(one test name per line; '#' comments allowed). Combines "
                        "with any positional names.")
    p.add_argument("--manifest",
                   help="run a single manifest file by path, bypassing tests/ "
                        "discovery (used by the Phase-0 profiler driver).")
    p.add_argument("-j", "--jobs", type=int, default=None, metavar="N",
                   help="run N tests concurrently (default: half the logical CPUs, capped at 8; -j1 serialises).  Each test "
                        "already gets its own scratch dir, disk image, BRAM and "
                        "MAME config, so they do not collide -- but a test that "
                        "measures TIMING should declare \"serial\": true in its "
                        "manifest, because competing MAME instances change how "
                        "fast the emulated machine runs.  Serial tests run "
                        "alone after the parallel batch drains.")
    p.add_argument("--fresh",         action="store_true",
                   help="ignore the green-result cache (results.jsonl) and run "
                        "every selected test.  Without it, a test whose INPUTS "
                        "(disk image, boot state, manifest, staged files, "
                        "check_script, harness env) are byte-identical to a "
                        "recorded PASS is skipped -- so interrupted suites "
                        "resume where they died and unchanged trees re-verify "
                        "in seconds.  Failures are never cached.  release.sh "
                        "should pass --fresh: the release gate re-proves "
                        "everything.")
    args = p.parse_args()

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    if not DISK_BASE.exists():
        fatal(f"disk image {DISK_BASE} missing — run `ninja disk` first")
    sync_plugin()

    if args.boot_state:
        return 0 if boot_state() else 1

    if args.manifest:
        mpath = Path(args.manifest)
        if not mpath.exists():
            fatal(f"--manifest {mpath} not found")
        ok = run_one(mpath, debug=args.debug, headless=not args.window,
                     update=args.update_goldens, no_state=args.no_state)
        return 0 if ok else 1

    all_tests = discover_tests()
    if args.list:
        for t in all_tests:
            m = load_manifest(t)
            print(f"  {m['name']:24s} {m.get('description', '')}")
        return 0

    wanted = set(args.names)
    if args.group:
        gfile = HERE / "groups" / f"{args.group}.txt"
        if not gfile.exists():
            fatal(f"unknown group '{args.group}' (no {gfile})")
        for line in gfile.read_text().splitlines():
            line = line.split("#", 1)[0].strip()
            if line:
                wanted.add(line)
    if wanted:
        tests = [t for t in all_tests if t.stem in wanted or t.name in wanted]
        missing = wanted - {t.stem for t in tests} - {t.name for t in tests}
        if missing:
            fatal(f"unknown test(s): {', '.join(sorted(missing))}")
    else:
        tests = all_tests

    if not tests:
        print(DIM_("no tests to run"))
        return 0

    # Headless (invisible) by default; --window opts into the visible render.
    # --debug always shows the window regardless (handled in run_mame).
    headless = not args.window
    if args.jobs is None:
        args.jobs = _default_jobs()
    # Green-result cache: skip tests whose inputs are byte-identical to a
    # recorded PASS (see --fresh).  Keys are computed up front so a test's
    # own staging can't perturb them mid-run.
    shared_hash = _shared_inputs_hash(args.no_state)
    green = set() if args.fresh else _journal_green_keys()
    passed = failed = cached = 0
    skipped = []
    _print_lock = threading.Lock()

    def _do_one(t):
        """Run one test, capturing its output instead of printing it.

        Returns (kind, name, ok, why, text).  Nothing here writes to stdout or
        the journal: with --jobs several of these run at once, and interleaved
        half-lines from two MAME runs are worse than useless when a test fails.
        The caller replays `text` in one piece under the print lock.
        """
        m = load_manifest(t)
        name = m["name"]
        why = unmet_requirement(m)
        if why:
            return ("skip", name, False, why, "")
        key = _test_input_key(t, m, shared_hash)
        if key in green:
            return ("cached", name, True, key, "")
        buf = io.StringIO()
        _tls = sys.stdout if isinstance(sys.stdout, _ThreadStdout) else None
        try:
            if _tls: _tls.bind(buf)
            ok = run_one(t, debug=args.debug, headless=headless,
                         update=args.update_goldens, no_state=args.no_state)
        except KeyboardInterrupt:
            raise
        except Exception as e:
            # One test blowing up must not take the suite with it.  An escaping
            # exception ends the run mid-way with no summary, which is
            # indistinguishable from a suite that simply had fewer tests --
            # silent truncation, the failure mode this harness exists to avoid.
            # Count it as a FAILURE (never a skip: nothing was proven).
            buf.write(FAIL_(f"  ERROR {name}: {type(e).__name__}: {e}") + "\n")
            ok = False
        finally:
            if _tls: _tls.unbind()
        return ("ran", name, ok, key, buf.getvalue())

    def _finish(res):
        nonlocal passed, failed, cached
        kind, name, ok, key, text = res
        with _print_lock:
            if kind == "skip":
                print(BOLD_(f"\n→ {name}"), DIM_(f"⊘ SKIP: {key}"))
                skipped.append((name, key))
                return
            if kind == "cached":
                print(BOLD_(f"\n→ {name}"),
                      DIM_("↷ cached PASS (inputs unchanged; --fresh to force)"))
                cached += 1
                passed += 1
                return
            sys.stdout.write(text)
            sys.stdout.flush()
            _journal_append(name, key, ok)
            if ok: passed += 1
            else:  failed += 1

    # SERIAL TAIL.  A test that measures TIMING cannot share the machine with
    # other MAME instances competing for CPU -- that is not a hypothetical here,
    # a few thousand cycles of logging was enough to close the apple/fgx#89 race
    # outright.  Such a test declares `"serial": true` and runs alone after the
    # parallel batch drains.  A test that wants the boot save-state is serial
    # too: STATE_DIR is shared and regenerating it under concurrency would race.
    def _is_serial(t):
        m = load_manifest(t)
        return bool(m.get("serial")) or bool(m.get("use_state"))

    if args.jobs > 1:
        par = [t for t in tests if not _is_serial(t)]
        ser = [t for t in tests if _is_serial(t)]
        print(DIM_(f"running {len(par)} test(s) {args.jobs}-way parallel"
                   + (f", {len(ser)} serial" if ser else "")))
        # Only installed for -j>1, so the sequential path stays byte-identical.
        _real_stdout = sys.stdout
        sys.stdout = _ThreadStdout(_real_stdout)
        with ThreadPoolExecutor(max_workers=args.jobs) as ex:
            try:
                for res in ex.map(_do_one, par):
                    _finish(res)
            finally:
                sys.stdout = _real_stdout
        for t in ser:
            _finish(_do_one(t))
    else:
        for t in tests:
            _finish(_do_one(t))

    print()
    # Skips are listed INDIVIDUALLY, never just counted.  A silent skip is how a
    # suite reports green while covering less than it claims; naming each one
    # keeps "did not run" visibly different from "passed".
    if skipped:
        print(BOLD_("Skipped (unmet requirements, declared in the manifest):"))
        for name, why in skipped:
            print(f"  ⊘ {name}: {why}")
    summary = f"{passed} passed, {failed} failed"
    if cached:
        summary += f" ({cached} cached)"
    if skipped:
        summary += f", {len(skipped)} skipped"
    print(BOLD_(OK_(summary) if failed == 0 else FAIL_(summary)))
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
