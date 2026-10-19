#!/usr/bin/env bash
#==============================================================================
# gate.sh -- build the OS, prove it boots, record the verdict LOCALLY.
#
# THE GATE IS A BOOT SMOKE TEST PLUS THE MEMORY/FORK CONTRACT.  `smoke` boots
# disk/fgxufs.po, waits for a shell prompt, runs `ls /`, and checks the listing came
# back: kernel starts, init runs, a shell reaches a prompt, it can execute a
# binary, the binary is correct, and control returns to the prompt.  Alongside it
# run eleven seconds-long fixtures covering the heap (heapcap, mbig, mallocmax)
# and snapshot fork (bigfork, bigforkx, fkiso, fknest, fkbg, fkbadex, sbrktest,
# pipegrow) -- see GATE_TESTS below for why those in particular.
#
# WHY IT IS ONLY THAT (2026-07-29).  The previous gate ran ~310 MAME
# tests.  Across months it cost thousands of hours and found essentially no OS
# defects -- its failures were test-suite debt, environment gaps and harness
# timing.  Its last full run spent two hours producing 62 timeouts that were
# entirely self-inflicted (a leaked -nothrottle MAME starving the next test's
# wall-clock budget) while every assertion still passed.  A suite whose failures
# do not correlate with product breakage is not a gate; it is a tax.  The whole
# corpus is deleted -- git history has it -- and acceptance testing gets designed
# from scratch, deliberately, later.
#
# WHAT STILL RUNS, because it is seconds and it catches what a boot cannot:
#   - the kernel source checks, as build edges (MX-flag leaks, baked kernel
#     addresses, provenance, syscall-table drift, W5100 patch-site drift).  All
#     five fail at RUNTIME and silently if wrong; none is visible to `ls`.
#   - fcc's fixture goldens, when toolchain/ changed (~5 min, 546 fixtures).
#   - the multibank sweep and the runtime fixture oracle, on the same trigger
#     (2026-08-02).  The goldens pin emitted ASSEMBLY; these two are the only
#     things that EXECUTE fcc's output under the kernel, and neither ran
#     automatically before -- which is how #11 got past a documented exit
#     criterion.
#
# THE VERDICT IS A LOCAL ARTIFACT.  .gate/<sha>.json is what release.sh reads.
# Posting to GitHub is an OPTIONAL MIRROR; a failed post is not a failed gate,
# and an unreachable GitHub does not block a release.  The OS must stay buildable and
# gateable with no upstream instance.
#
# NO STATUS IS NOT PASS.  A gate that never ran leaves no receipt, and
# release.sh treats absent exactly like red.  That distinction is the whole
# point: the v1.13 net regression shipped because a skipped gate read as an
# acceptable one.
#
# Usage:
#   tools/gate.sh              build + smoke test
#   tools/gate.sh --no-tests   build only (writes a receipt, marked so)
#==============================================================================
set -u
cd "$(cd "$(dirname "$0")/.." && pwd)"

MODE=smoke
for a in "$@"; do
    case "$a" in
        --no-tests) MODE=build-only ;;
        --full)     ;;   # accepted and ignored: there is one gate now
        *) echo "gate: unknown flag '$a'" >&2; exit 2 ;;
    esac
done

mkdir -p .gate

# Serialise concurrent gates.  `mkdir` is the portable atomic lock -- flock is
# not present on macOS, which is where this actually runs.
#
# A CONTENDED GATE EXITS 75, NOT 0 (apple/fgx#263).  It used to exit 0 with the
# reason on stderr alone, so a caller reading $? -- the obvious thing to read --
# was told the gate had PASSED when it had not run at all.  That nearly shipped
# a false green while landing !262: the pre-push hook's background gate still
# held the lock, and only grepping for the verdict line as well caught it.  The
# contention is routine BY CONSTRUCTION -- the hook spawns a gate on every
# feature-branch push, and the natural next action after pushing is to run one
# -- so this fails closed like the rest of the harness, where even a checker's
# rc=2 "inconclusive" counts as red.  75 is EX_TEMPFAIL: a wrapper can still
# tell "busy, retry" from "the gate said no", and a caller that reads nothing
# but $? is no longer lied to.  The line goes to STDOUT as well as stderr,
# because every caller in this repo redirects `> log 2>&1` and reads the tail.
LOCKDIR="${FGX_GATE_LOCK:-.gate.lock}"

# The lock decides a VERDICT, so it proves it can still fail: re-run ourselves
# against a lock dir that is already held and require 75 plus SKIPPED on stdout.
# Restoring the old `exit 0` turns this red, which is the whole point -- the bug
# it replaces was invisible precisely because a skip and a pass looked alike.
# The child skips this block (its FGX_GATE_LOCK is set); that is also what ends
# the recursion.
if [ -z "${FGX_GATE_LOCK:-}" ]; then
    _lt="$(mktemp -d)"
    # A SELF-TEST THAT CANNOT REACH ITS SUBJECT PASSES FOR THE WRONG REASON.
    # If the temp lock never got made, the child would report SKIPPED about a
    # path it could not create -- the right answer from a rig that tested
    # nothing -- so the directory is checked here and the child's line must
    # NAME it below.
    mkdir -p "$_lt/held" || { echo "gate: SELF-TEST could not create its lock \
under $_lt" >&2; exit 1; }
    _lo="$(FGX_GATE_LOCK="$_lt/held" tools/gate.sh 2>/dev/null)"; _lrc=$?
    rm -rf "$_lt"
    if [ "$_lrc" != 75 ] || ! printf '%s' "$_lo" | grep -q "SKIPPED.*$_lt/held"; then
        _m="gate: SELF-TEST FAILED -- a contended gate must exit 75 and say \
SKIPPED on stdout; got rc=$_lrc"
        echo "$_m"; echo "$_m" >&2
        exit 1
    fi
fi

if ! mkdir "$LOCKDIR" 2>/dev/null; then
    _m="gate: SKIPPED -- another gate holds $LOCKDIR.  NOTHING RAN, and a skip \
is NOT a pass; retry when it finishes (exit 75)."
    echo "$_m"; echo "$_m" >&2
    exit 75
fi
trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT
# The self-test child exists to test the lock and nothing else: it must never
# fall through into a ten-minute gate run.
[ -n "${FGX_GATE_LOCK:-}" ] && exit 0

SHA="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
# The receipt is keyed by the WORKING TREE, not just the commit: a dirty tree
# must not inherit a clean commit's verdict.
TREE="$(git status --porcelain 2>/dev/null | shasum | cut -d' ' -f1)"
RECEIPT=".gate/${SHA}.json"
# APPEND-ONLY, BECAUSE THE RECEIPT IS NOT (apple/fgx#262).  .gate/<sha>.json is
# overwritten by the next run of the same SHA, so a red re-run to green leaves a
# clean record of something that did not happen -- which is exactly how a flake
# hides.  Every verdict lands here as well, and a green receipt carries the
# count of reds seen on that SHA before it.
HISTORY=".gate/history.jsonl"
SUITE_LOG=".gate/${SHA}.smoke.log"
START=$(date +%s)

note() { printf '==> %s\n' "$*"; }
fail_out() {
    local why="$1"
    python3 - "$RECEIPT" "$SHA" "$TREE" "$MODE" "$why" "$HISTORY" <<'PY'
import json, sys, time
p, sha, tree, mode, why, hist = sys.argv[1:7]
rec = {"sha": sha, "tree": tree, "mode": mode, "ok": False,
       "why": why, "ts": int(time.time())}
json.dump(rec, open(p, "w"), indent=1)
with open(hist, "a") as f:
    f.write(json.dumps(rec) + "\n")
PY
    note "GATE FAILED: $why  (receipt: $RECEIPT)"
    [ -f "$SUITE_LOG" ] && note "  smoke output kept: $SUITE_LOG"
    exit 1
}

# A checker proves it can still FAIL before its silence is trusted: "found
# nothing" and "stopped looking" are indistinguishable otherwise.
note "self-testing the checkers"
python3 tools/ninja/putdeps.py --selftest >/dev/null 2>&1 \
    || fail_out "checker self-test failed: putdeps.py"
python3 toolchain/tools/stack_check.py --self-test >/dev/null 2>&1 \
    || fail_out "checker self-test failed: stack_check.py"
python3 tools/check_shtmp0_across_fs.py --self-test >/dev/null 2>&1 \
    || fail_out "checker self-test failed: check_shtmp0_across_fs.py"
# stack_measure's call-site argument parser (0.3): an unrecognised cleanup reads
# as "no arguments", which SHRINKS every reservation downstream of it.  That is
# the silent-corruption direction, so it proves it can still read each shape.
python3 toolchain/src/ld/stack_measure.py --self-test >/dev/null 2>&1 \
    || fail_out "checker self-test failed: stack_measure.py"
# The campaign's two measurement tools.  Both report MAXIMA, so a pattern that
# silently stopped matching would report a smaller window and a lower &local
# count -- the reassuring direction, and the wrong one.
python3 tools/stack_reach.py --self-test >/dev/null 2>&1 \
    || fail_out "checker self-test failed: stack_reach.py"
python3 tools/stack_exile_cost.py --self-test >/dev/null 2>&1 \
    || fail_out "checker self-test failed: stack_exile_cost.py"
python3 tools/check_soft_exile.py --self-test >/dev/null 2>&1 \
    || fail_out "checker self-test failed: check_soft_exile.py"
python3 toolchain/src/ld/fgx_gc.py --self-test >/dev/null 2>&1 \
    || fail_out "checker self-test failed: fgx_gc.py"
python3 tools/check_tzlimits.py --self-test >/dev/null 2>&1 \
    || fail_out "checker self-test failed: check_tzlimits.py"
python3 tools/check_data_budget.py --self-test >/dev/null 2>&1 \
    || fail_out "checker self-test failed: check_data_budget.py"
python3 tools/check_vacuous_assertions.py --self-test >/dev/null 2>&1 \
    || fail_out "checker self-test failed: check_vacuous_assertions.py"
python3 tools/check_libc_link_sites.py --self-test >/dev/null 2>&1 \
    || fail_out "checker self-test failed: check_libc_link_sites.py"
python3 tools/check_port_shim_widths.py --self-test >/dev/null 2>&1 \
    || fail_out "checker self-test failed: check_port_shim_widths.py"
# flakes.py reads the journal this suite writes, and a rate that cannot come
# out wrong is not a measurement: its self-test feeds it a corpus whose answer
# is known by construction (one true flake, one merely-broken-then-fixed test).
python3 tools/mame_test/flakes.py --self-test >/dev/null 2>&1 \
    || fail_out "checker self-test failed: flakes.py"
# The tick invariant's checker carries its own three arms -- healthy, a
# half-rate callback regime, and a missing region -- because a checker that
# cannot go red is not coverage, and this one's whole job is to notice a change
# nothing else in the suite can see.
python3 tools/mame_test/ticksprobe_check.py --self-test >/dev/null 2>&1 \
    || fail_out "checker self-test failed: ticksprobe_check.py"
# The cursor-position checker's eight arms include BOTH defects it was written
# for, at the numbers they were measured at on 2026-09-01 -- a stranded record
# three columns behind the caret, and a pixel block AttrBuf cannot explain.  A
# checker that cannot reproduce the defect it exists for is a checker nobody
# has watched go red.
python3 tools/mame_test/curtrack_check.py --self-test >/dev/null 2>&1 \
    || fail_out "checker self-test failed: curtrack_check.py"
# THE CORPUS HAS A CEILING, AND THIS IS THE ONLY THING THAT LOOKS AT THE SUM.
# The four questions in docs/testing.md are asked of ONE test at a time, and
# the cost they are meant to bound only exists in aggregate -- which is how 337
# individually-justified manifests passed the bar and the corpus still reached
# 216 minutes of declared budget.  gate_budget.py sums GATE_TESTS' declared
# `timeout_s' against a ratchet, so adding a gate test means taking one out.
# It also catches a name whose manifest is GONE: run.py fatals on an unknown
# test, so `nodevboot' -- retired in bce6524e9 with its name left behind here --
# had quietly made this whole step unable to start.
python3 tools/mame_test/gate_budget.py --self-test >/dev/null 2>&1 \
    || fail_out "checker self-test failed: gate_budget.py"
python3 tools/mame_test/gate_budget.py >/dev/null 2>&1 \
    || fail_out "$(python3 tools/mame_test/gate_budget.py 2>&1 | head -3)"
# fgxfs is the UFS campaign's ORACLE: the independent implementation every claim
# FGX makes about a volume it wrote gets checked against.  Its self-test carries
# seven mutation arms, so a green run means fsck can still FAIL -- which is the
# only property that makes it an oracle rather than a second opinion from the
# same source.
python3 tools/fgxfs.py --self-test >/dev/null 2>&1 \
    || fail_out "checker self-test failed: fgxfs.py"
# ...and the thing that finally POINTS the oracle at a volume FGX wrote.  The
# sentence above has been true of the tool and not of the loop: fgxfs fscked
# volumes it made itself, and no image the 65816 had touched was ever handed to
# it.  ufsfsck_check.py is that hand-off, and its own self-test carries the two
# arms it needs -- a truncated volume must be REJECTED, and finding no volume at
# all must FAIL rather than pass, which is this checker's real failure mode.
python3 tools/mame_test/ufsfsck_check.py --self-test >/dev/null 2>&1 \
    || fail_out "checker self-test failed: ufsfsck_check.py"
python3 tools/check_fs_sleep_invariant.py --self-test >/dev/null 2>&1 \
    || fail_out "checker self-test failed: check_fs_sleep_invariant.py"
# kequ resolves the bank-0 layout for four B3 checkers, following aliases from
# include/kernel.s into the generated include/config.s.  When it is wrong they
# all assert about a machine that does not exist -- which is what happened the
# day the layout started being derived.
python3 tools/mame_test/kequ.py >/dev/null 2>&1 \
    || fail_out "checker self-test failed: tools/mame_test/kequ.py"
# The harness's own manifest-key guard (apple/fgx#24), which also validates
# every tracked manifest -- so a typo'd or misplaced key fails the GATE rather
# than silently disabling whatever it configured.
python3 tools/mame_test/run.py --self-test >/dev/null 2>&1 \
    || fail_out "checker self-test failed: run.py manifest keys"

# genconfig derives the whole of bank 0's layout from kernel.nproc, and its
# self-test PINS the result so a change to that arithmetic cannot quietly
# re-lay-out the bank.  It was never wired in, and its pins had been failing
# since the per-pid kernel stacks moved to the language card -- a check nobody
# runs looks exactly like a check that passes, and the same stale numbers had
# reached include/kernel.s's layout comment (apple/fgx#172).
python3 tools/ninja/genconfig.py --selftest >/dev/null 2>&1 \
    || fail_out "checker self-test failed: genconfig bank-0 layout pins"

# A MAME assertion whose needle also appears in the command MAME types matches
# the shell's ECHO of that command, so it passes on a run that produced no
# output at all.  Three instances got as far as green-for-weeks -- wide60
# (recorded in its own header), ttysprobe's misspelled expect key (#24), and
# mid40st (#34), which had NEVER once depended on the shell printing anything.
# The property is mechanically checkable, so it is checked here rather than
# left to whoever reviews the next manifest.
note "MAME assertions not satisfiable by their own command line"
python3 tools/check_vacuous_assertions.py \
    || fail_out "vacuous MAME assertion(s) -- see above"

# A link site that still PUTs the WHOLE 42-member libc pile.  Carving libc into
# members grew the pile ~86 KB, and the consumer list was wrong three times:
# tests/multibank had ALREADY silently regressed past the 64 KB ceiling,
# run_runtime.py's mirrored link built 240 fixtures and staged 0, and fas still
# FIT -- with 2,782 bytes of headroom and nothing measuring it.  Only the first
# of the three produced a signal on its own.
note "no link site still PUTs the whole libc pile"
python3 tools/check_libc_link_sites.py \
    || fail_out "unconverted libc link site(s) -- see above"

# A port shim that re-declares a libc function NARROWER than libc declares it
# has no runtime symptom to test for: the generated code just stores one word
# where it computed two, and the damage surfaces later as an unrelated race.
# Build time is the only moment this is catchable.  See apple/fgx#55.
note "no port shim narrows a libc function"
python3 tools/check_port_shim_widths.py \
    || fail_out "port shim declaration width(s) -- see above"

note "no errno parked in _shTmp0 crosses an Fs_ call"
python3 tools/check_shtmp0_across_fs.py \
    || fail_out "an errno in _shTmp0 is clobbered by an Fs_ call (apple/fgx#289)"

# The FS layer's shared singletons are safe only because nothing in that layer
# sleeps.  Nothing in the tree said so, so nothing stopped a future change from
# breaking it silently -- and UFS 1.3 (Reno's vfs_bio.c, sleeping buffer locks)
# is a change that will.  This turns the emergent property into a stated one.
note "the FS layer still never sleeps (its singletons depend on it)"
# 2 and 1 are DIFFERENT ANSWERS and the receipt has to say which.  2 is the
# checker naming a file that has left the tree, so it stopped before reading
# anything; 1 is the invariant actually broken.  Collapsing them wrote "FS/block
# layer sleeps" into .gate/history.jsonl for a run that never looked.
python3 tools/check_fs_sleep_invariant.py
case $? in
    0) ;;
    2) fail_out "check_fs_sleep_invariant.py is stale: it names a file that no longer exists (see above) -- this is NOT a finding about the FS layer" ;;
    *) fail_out "FS/block layer sleeps -- see above" ;;
esac

note "no two fixed wait channels share a value"
python3 tools/check_wchans.py \
    || fail_out "two WCHAN_* constants are one channel -- see above"

# /etc/rc's modload line and /etc/modload.conf are ONE LIST WRITTEN TWICE, and
# only rc's copy is read on a UFS root.  They diverged by one name for long
# enough that the filesystem self-test stopped running and nothing said so --
# the manifest's `lacks' arms all passed, because the module that would have
# printed the failure was never loaded (apple/fgx#384).
note "/etc/rc loads what /etc/modload.conf says it loads"
python3 tools/check_modload_lists.py \
    || fail_out "rc.in and modload.conf name different modules -- see above"

# The staging prune moved OUT of the retired ProDOS image builder and into a
# tool of its own.  Its --self-test is the only thing that exercises the case
# that would be a disaster -- an empty staged list, which means "the graph
# produces nothing" and would otherwise prune the whole staging tree.
note "the staging prune still refuses to prune everything"
python3 tools/prune_staged.py --self-test > /dev/null \
    || fail_out "tools/prune_staged.py --self-test FAILED -- see above"

note "regenerating build.ninja"
python3 tools/ninja/gen.py >/dev/null || fail_out "build.ninja generation failed"

note "building (ninja all)"
ninja all >/tmp/fgx_gate_build.log 2>&1 || {
    tail -20 /tmp/fgx_gate_build.log
    fail_out "build failed"
}

# Checks that read what the build produced -- the generated kernel C, the
# linked binaries and the boot image -- run here, after it.  Before it they
# fail on a fresh clone, and the real DP check would scan a tree with no
# generated C in it.

# The DP-across-sleep gate guards a property that is TRUE EVERYWHERE today, so
# without a self-test it would pass identically whether it worked or did
# nothing.  Its first version did exactly that: removing the apple/fgx#100 fix
# left it reporting clean.
python3 tools/check_dp_sleep_safety.py --self-test >/dev/null 2>&1 \
    || fail_out "checker self-test failed: check_dp_sleep_safety.py"
note "no shared DP cell is live across a task switch"
python3 tools/check_dp_sleep_safety.py || fail_out "DP scratch is live across a sleep"
# Shared libc SP5 step 3's central property -- sh static, tcsh/vi dynamic --
# is pinned by nothing else automatic.  test_shells.py has no self-test of its
# own (it reads the built binaries' FGX3 header directly, which is already
# the ground truth), so it runs here unconditionally rather than guarded by
# --self-test.
python3 toolchain/tests/dyn/test_shells.py >/dev/null 2>&1 \
    || fail_out "shell link-mode check failed: test_shells.py"
# The pre-stage bank window: /fgxunix's segment table names the modules the
# BOOT PROGRAM delivers, and stage 2 bounds its bank cursor by nothing, so one
# module too many used to land on the kernel heap before a console existed.
# check_preload_banks.py held that line while the list was a text file; the
# image's builder holds it now, and refuses a table whose segments run past
# either bank region OR past the end of a bank -- neither of which stage 2 can
# notice at boot.  Fourteen arms, the boundary cases included.
python3 tools/mkfgxunix.py --self-test >/dev/null 2>&1 \
    || fail_out "checker self-test failed: mkfgxunix.py"
# FIVE CHECKERS THAT HAD SELF-TESTS NOTHING RAN.  Each of these grades a gate
# test's result, each ships arms that prove it can go RED, and none of them was
# in this list -- so the property that makes them worth running was itself
# unchecked.  Found by asking which files define `--self-test' and are not
# named here (2026-09-06).
#
#   bootstk_check   4 arms: the measured headroom, a chain that ate the floor,
#                   and the TWO deceptions apple/fgx#195 was arrived at through
#                   -- a repainted slice carrying the $C5C5 canary, and an
#                   all-paint slice.  Both must be REFUSED, because 512 B spare
#                   is not a very good pass, it is no reading.
#   bootstk_chain   16 arms over synthetic listings and a synthetic stack: that
#                   a call site's pushed value is `off + size - 1', that the two
#                   data shapes are named rather than counted as frames, and the
#                   two refusals -- an all-paint slice and a canaried one.  It
#                   reads no fixture and boots nothing; it is here because a
#                   diagnostic that decodes wreckage into confident symbols is
#                   worse than none, which is what its first run did.
#   fsckro_check    4 arms: unchanged-and-still-broken, a spindle that CHANGED
#                   under `fsck -n', and a volume that is identical but CLEAN --
#                   which would make the screen assertion vacuous.
#   modimage_check  5 gate cases.
#   ufsboot_check   the boot chain's memory assertions.
#
# fsckfix_check.py went with the five fsck corruption-case manifests it served:
# deep validation of a VERBATIM 2.11BSD port this tree is not developing.
# fsckro_check stays and is the better of the two, because it DISCRIMINATES --
# `fsck -n' on a broken volume must find the fault and write NOTHING, and a
# read-only checker that silently writes is how a volume is destroyed by the
# tool meant to save it.
for _c in bootstk_check bootstk_chain fsckro_check modimage_check ufsboot_check; do
    python3 "tools/mame_test/${_c}.py" --self-test >/dev/null 2>&1 \
        || fail_out "checker self-test failed: ${_c}.py"
done

# Every fcc fixture, the oracle, the bench and the multibank sweep link through
# fixture_link.py; its test carries its own negative control (tcops without
# M38's recipe must fail on tgetent).
python3 toolchain/tests/test_fixture_link.py >/dev/null 2>&1 \
    || fail_out "fixture link check failed: test_fixture_link.py"

# Bank-0 campaign 1.3: a function whose locals were exiled to the data bank must
# not ALSO reach them on the hardware stack.  Half-exiled is worse than not
# exiled -- writes land in one bank and reads in the other, and a wrong base used
# CONSISTENTLY still computes the right answer, so no runtime test sees it.  This
# ran after the build because it reads the built assembly; it is a no-op while
# src/softscc/ is empty.  It caught fcc matching the C name against a list of
# EMITTED symbols, which silently left 18 of bsh's 52 cycle members behind.
python3 tools/check_soft_exile.py >/tmp/fgx_gate_exile.log 2>&1 || {
    cat /tmp/fgx_gate_exile.log
    fail_out "soft-frame exile is incomplete (see above)"
}

# bsh's sourced-script ceiling is its DATA bank, not its stack: the `.` builtin
# parses the whole file into the stak arena before running a line, and past the
# ceiling the read truncates in SILENCE.  Its bank-0 reservation is deliberately
# sized to trip the stack guard FIRST, so a runaway still says something.  This
# fails if that ordering ever inverts -- trading a loud limit for a deeper silent
# one is the regression srcdepth_loud exists to catch, and it would pass.
python3 tools/check_data_budget.py >/tmp/fgx_gate_budget.log 2>&1 || {
    cat /tmp/fgx_gate_budget.log
    fail_out "data-bank budget (see above)"
}

# fcc's fixture gate: ~5 min, so it runs ONLY when fcc's own source changed.
# Re-testing an unchanged compiler is pure waste.
#
# The trigger is a CONTENT HASH of fcc's sources, recorded when the fixtures
# last passed.  It is not `git status`, which I tried first and which was wrong
# in both directions: one untracked file under toolchain/ (socket.h) made it
# match on EVERY run, and a clean tree after a commit made it match on NONE --
# so it fired constantly while fcc was untouched, and would have stayed silent
# on a commit that rewrote the code generator.
#
# Hashed: the compiler/assembler/linker/libc sources, the build tooling, and the
# fixtures themselves (a new or edited fixture must run).  Excluded: build
# products -- the fcc/fas binaries, __pycache__, *.expected.bin -- because those
# change as a RESULT of a run and would re-trigger it forever.
#
# It asks GIT what the sources are rather than walking the filesystem.  A
# filesystem walk was my second wrong answer here: the fixture runner creates
# and deletes <name>.s, <name>.data.s, fcc_output.s and seg1_layout.s inside the
# fixture dirs as it goes (595 of them were on disk mid-run), so the hash moved
# on every run and any interrupted run moved it permanently -- retriggering
# forever, which is the exact waste this is supposed to prevent.  Tracked files
# cannot contain scratch, because the scratch is untracked.
#
# KNOWN GAP: an UNTRACKED source is invisible here, so editing one will not
# retrigger.  toolchain/include/socket.h is untracked today; it should be
# committed or deleted.  The alternative -- counting untracked files -- is what
# made the previous two attempts fire unconditionally, since most of the scratch
# is untracked too.
fcc_source_hash() {
    # src/kernel/vfs is here because a fixture REACHES OUT OF toolchain/ into
    # it: M37/vfslayout.c includes the real kernel VFS headers rather than
    # redeclaring their structures, so that the tree holds one definition of a
    # vnode instead of two that agree until someone edits one.
    #
    # That include makes those headers fixture sources, and a hash that did not
    # cover them would skip the fixtures after a change to the very headers the
    # fixture exists to pin -- the layout could move and the check that guards
    # it would report "unchanged since its fixtures last passed".
    git ls-files -- toolchain src/kernel/vfs \
      | grep -E '\.(c|h|py|s|json)$|/Makefile$' \
      | LC_ALL=C sort | xargs shasum 2>/dev/null | shasum | cut -d' ' -f1
}

# ...AND THE ORACLE NEEDS MORE THAN THAT, because unlike the goldens it BOOTS.
#
# fcc_source_hash covers what fcc compiles.  The runtime oracle also has to
# build a volume and start a machine from it, and those inputs are elsewhere:
# run_runtime.py drives tools/make_ufsboot.sh (line 559), which drives
# tools/fgxfs.py.  A change to either can stop the oracle booting while fcc
# itself is untouched.
#
# THAT IS NOT HYPOTHETICAL.  The oracle was dead from 2026-09-04 to 2026-09-06
# -- it booted a ProDOS image the tree had stopped producing -- and the gate
# said "fcc unchanged since the sweep + oracle last passed" for the whole two
# days, because nothing under toolchain/ or src/kernel/vfs/ had moved.  Three
# fixture regressions sat behind that skip.
#
# Only the oracle's stamp takes these: the goldens are host-only and never boot
# anything, so a disk-script edit must not cost them a four-minute rerun.  That
# is the same reason the two stamps are separate at all.
fcc_runtime_hash() {
    printf '%s\n' "$FCC_HASH"
    git ls-files -- tools/make_ufsboot.sh tools/fgxfs.py \
      | LC_ALL=C sort | xargs shasum 2>/dev/null
}
FCC_STAMP=".gate/fcc-fixtures.stamp"
FCC_HASH="$(fcc_source_hash)"
if [ -f "$FCC_STAMP" ] && [ "$(cat "$FCC_STAMP")" = "$FCC_HASH" ]; then
    note "fcc unchanged since its fixtures last passed -- skipping them"
elif [ ! -x toolchain/tests/run.sh ]; then
    note "fcc fixture runner absent -- skipping"
else
    # The library and linker self-tests first: seconds, and they fail on the
    # class the fixtures cannot see -- a shared library, a link path or a pile
    # that no golden diffs.  `piles` AS WELL AS `test-libs` (apple/fgx#33):
    # every pile is regenerated against this compiler, so the dirty-tree
    # comparison below can see each of them.
    note "library + linker self-tests and the piles (make test-libs piles)"
    LIB_LOG=".gate/${SHA}.libs.log"
    (cd toolchain && make -s test-libs piles) >"$LIB_LOG" 2>&1 || {
        grep -E '^  FAIL' "$LIB_LOG" | head -5
        fail_out "library checks failed (see $LIB_LOG)"
    }

    # ...AND REBUILD, because that step just rewrote declared build INPUTS
    # (apple/fgx#160).  The piles and the .so files are inputs of the
    # `tclibs' and `libso' edges, so when make actually regenerates one those
    # edges go dirty AFTER the `ninja all` the MAME tests are about to run
    # against, and every program and image downstream of a library whose
    # bytes change goes with it.
    #
    # The `fgx.po is STALE` guard below then fails the gate, which is the guard
    # working.  The cost is a whole wasted run and a failure that reads like a
    # regression in whatever was being tested.  It is latent rather than
    # constant because make keys on MTIME: `make libc_*` rewrites lib/*.s with
    # fresh timestamps even when the bytes are identical.
    #
    # A step that rewrites a build input has to be followed by the build.  This
    # is that, rather than moving the step earlier: the surrounding block is
    # the fcc-fixture stage and reordering it would put five minutes of goldens
    # in front of the compile.
    ninja all >>/tmp/fgx_gate_build.log 2>&1 || {
        tail -20 /tmp/fgx_gate_build.log
        fail_out "build failed after the pile regeneration"
    }

    # The libc piles are build outputs, not tracked files, so
    # there is no committed copy to compare the regeneration against: what the
    # build above produced IS what this compiler emits (apple/fgx#385).
    note "fcc SOURCE changed -- fixtures (544, ~5 min)"
    FCC_LOG=".gate/${SHA}.fcc.log"
    bash toolchain/tests/run.sh >"$FCC_LOG" 2>&1 || {
        # Lead with the COUNT.  This printed five FAIL lines and no total, so a
        # 144-failure run read as five failures -- the number was in the log the
        # whole time and the gate simply never showed it.
        note "  $(grep -E '[0-9]+ passed, [0-9]+ failed' "$FCC_LOG" | tail -1)"
        grep -E '^FAIL ' "$FCC_LOG" | head -10
        n=$(grep -c '^FAIL ' "$FCC_LOG")
        [ "$n" -gt 10 ] && note "  ... and $((n - 10)) more (see $FCC_LOG)"
        fail_out "fcc fixtures: $(grep -cE '^FAIL ' "$FCC_LOG") failed (see $FCC_LOG)"
    }
    FCC_OUT="$(grep -E '[0-9]+ passed, [0-9]+ failed' "$FCC_LOG" | tail -1)"
    note "  ${FCC_OUT:-fcc fixtures OK}"
    printf '%s' "$FCC_OUT" | grep -qE '^[1-9][0-9]* passed' \
        || fail_out "fcc fixture gate ran ZERO fixtures: ${FCC_OUT:-no summary}"
    # The NEGATIVE half.  Everything above asserts what fcc EMITS, which means
    # it must accept the input first -- so no gate here covered a REJECTION
    # until apple/fgx#85, and a `die()` could stop being reachable with the
    # suite still green.  Its own --self-test runs first, because a negative
    # harness that cannot go red reads as coverage of every diagnostic in the
    # compiler while asserting nothing.
    REJ_LOG=".gate/${SHA}.fccreject.log"
    bash toolchain/tests/run_reject.sh --self-test >"$REJ_LOG" 2>&1 || {
        sed 's/^/    /' "$REJ_LOG"
        fail_out "fcc reject-gate SELF-TEST failed -- the negative gate cannot go red"
    }
    bash toolchain/tests/run_reject.sh >>"$REJ_LOG" 2>&1 || {
        grep -E '^FAIL |^ +' "$REJ_LOG" | head -12
        fail_out "fcc rejects: $(grep -cE '^FAIL ' "$REJ_LOG") case(s) fcc failed to refuse (see $REJ_LOG)"
    }
    note "  $(grep -E '^reject: ' "$REJ_LOG" | tail -1)"
    # --sections (fgx_gc's units) marks every function and data item of the
    # library piles and changes nothing else: stripped of its markers, the
    # output is the plain output.
    SEC_LOG=".gate/${SHA}.sections.log"
    (cd toolchain && python3 tests/sections.py) >"$SEC_LOG" 2>&1 || {
        sed 's/^/    /' "$SEC_LOG" | tail -20
        fail_out "fcc --sections: see $SEC_LOG"
    }
    note "  $(tail -1 "$SEC_LOG")"
    # Record the stamp only now that they have actually PASSED, so a red run is
    # retried rather than remembered as green.
    printf '%s\n' "$FCC_HASH" > "$FCC_STAMP"
fi

# The gate's tests.  `smoke` is the boot contract; the rest are the MEMORY AND
# FORK contract, added 2026-08-02 after issue #11.
#
# Why these and not others: #11 was a 512 KB-to-one-bank heap regression plus a
# broken malloc(80000L), and it landed GREEN because mbig -- a fixture whose own
# header calls it a train-2 M-4 EXIT CRITERION -- was in no gate, and neither
# were fkiso/fknest/fkbg/fkbadex/sbrktest/pipegrow, the direct coverage for
# snapshot fork.  An exit criterion nothing runs is not a criterion.  All of
# them are seconds, and the gate is the only thing that always runs.
#
# `stkhwm` and `mutstk` join them for the bank-0 stack campaign
# (docs/history/plans/bank0-stack.md).  Every claim that campaign makes about reservations
# rests on the high-water-mark instrument, so the instrument silently dying
# would not fail anything -- it would just make the next milestone's table read
# "everything got smaller".  `mutstk` is the unguarded mutual-recursion shape:
# measured on a pre-0.2 kernel it printed one line and the machine stopped dead,
# with nothing on screen and nothing in the log.  `mutstk_deep` is its
# counterpart: 0.2's floor check now fires FIRST for anything that syscalls, so
# without it fcc's prologue guard would be covered by no test at all.
#
# `softexec` joins for #14.  It is the only test of the NON-FORK exec path --
# `exec cmd`, which took a separate arm that could not load an FGX2/FGX3 binary
# at all, so it was broken disk-wide while every fork+exec test stayed green.
# It also execs 61 times in a row, which is the part that needs to be in a gate
# rather than run once: the fix frees the outgoing image, and a per-exec bank or
# stack-page leak passes any single-exec test and starves the machine later, in
# something unrelated.
# `czcorrupt` joins for #17, and it covers a CLASS rather than a tool: 2.11BSD
# code that used the MMU as an input validator.  uncompress armed
# signal(SIGSEGV, oops) to catch a runaway LZW decode stack -- its own comment
# says "wild pointer -- assume bad input" -- and FGX cannot deliver that signal,
# so the port dropped the detector and a corrupt .Z walked off de_stack into the
# malloc arena in SILENCE.  Cheap, and it guards both directions: a valid .Z
# must still round-trip, so a too-tight bound fails here too.
#
# `unixdgram' GUARDS THE TRANSPORT syslog(3) NOW DEPENDS ON, and it is the first
# case here that RAISED the budget ratchet instead of taking another's slot --
# deliberately, because nothing among the other 44 duplicates any part of
# AF_UNIX, so every retiree would have been new coverage traded for old.  See
# gate_budget.py's ratchet note for the three candidates that were weighed.
#
# IT GOES RED, AND THAT IS MEASURED RATHER THAN ASSERTED.  Four mutations have
# been run against it and each broke exactly one case: removing the carry guard
# on the record length gives `wrap-errno 55' where EMSGSIZE is required; dropping
# the close arm gives `leak-connect round=7 errno=23', ENFILE on the eighth round
# against NPIPE 8; keeping `v_un' across unp_detach gives `stale-connected to a
# closed socket'; and a bind that does not hold its vnode hangs the run, which is
# what the defect itself does to a logger.
#
# WHAT ONLY THIS CASE SEES: that an AF_UNIX descriptor takes no W5100 socket --
# the interleaved AF_INET open is the detector, three borrowed slots being
# exactly the three the chip has; that a 16-bit length cannot wrap past the ring
# ceiling, which was an unprivileged machine-wide syslog DoS; that close(2) frees
# the receive ring, which only a bound socket owns and which the loopback
# teardown declines to release; that a name stops naming a socket that has
# closed; and that a name made in /dev after a bind does not panic the machine.
# The socket cases beside it (`sockleak', `sockemfile') cover loopback and the
# chip, and neither reaches the unp transport at all.
GATE_TESTS="smoke blkprobe heapcap mbig mallocmax bigfork bigforkx fkiso \
            fknest fkbg fkbadex sbrktest pipegrow srcdepth_loud \
            mutstk mutstk_deep heapkill softfork softexec czcorrupt coninv \
            rename sockleak sockemfile trunkfree devnode ptyflush ptyoutq \
            ptypkt ptyremote ptysrsel ptyswsel dbgbank curtrack devpty \
            vccurstype trapquiet bootstk ticksprobe ufsboot \
            statenoent kslots ssansi unixdgram"

# `ssansi' HOLDS THE SECOND SIGHT CARD'S SLOT, AND IS THE ONLY THING THAT SEES
# A COLOUR THE IIGS SCREEN CANNOT SHOW.  It took `sscon''s place under the
# budget ratchet and asserts all of sscon's contract -- the module's `cells at'
# log line, the shell's prompt on the IIgs screen, the card drawing -- and the
# card's cells besides.  The console's cells hold ANSI colour indexes and
# eight-bit bytes, and the SHR folds both to what it can draw -- four slots,
# seven-bit glyphs -- so a regression that folds them before they are stored
# leaves every SHR test, the framebuffer hashes included, green.  The card
# shows the stored values as they are, and ssansi asserts six attribute bytes
# and five code page 437 cells against a fixture built so each row can land
# on one value only.  It goes red for either fold (measured).  One boot, 30 s
# declared, as sscon's was.

# `statenoent' IS HERE FOR AN ERRNO, WHICH IS A CLASS AND NOT A CASE
# (apple/fgx#345).  stat(2) of a name that is not there answered EIO on a
# mounted UFS root, because Fs_Stat's root arm fell through to an FST that is
# not registered and that FST answers the legacy resolver's errno to
# everything.  The suite could not see it: stat(1) exits 1 either way, so every
# check on `$?' passed, and the wrong answer was in the STRING.
#
# The class is a path syscall whose correct errno is produced and then replaced
# by a fallback.  Fs_Open's arm had the same shape and was fixed for it in
# apple/fgx#318 -- elvis lost the filename it was editing -- so this is the
# second sighting, which is what makes it worth a gate slot rather than a
# manifest.  2 seconds.

# curtrack IS BESIDE vccursor BECAUSE vccursor CANNOT SEE WHAT IT SEES
# (apple/fgx#287).  That
# one counts inverse AttrBuf cells and asserts there is exactly one, on screen;
# the two defects measured 2026-09-01 both pass that count.  One left exactly
# one inverse cell three columns behind the caret; the other left AttrBuf
# perfect and an inverse block's PIXELS on the screen with nothing behind them.
# So curtrack asserts a POSITION rather than a count, and reads the SHR
# framebuffer as well as the buffer -- which is the only way the second one is
# visible to anything but a human looking at the screen.  Sixteen
# terminal-adjacent tests were green through both.  One boot.

# ufsboot IS THE BOOT CHAIN ON A 2.11BSD VOLUME (UFS 2.3), and it is in the
# gate for the reason floppy_boot WAS (that one is parked -- see below): it is
# the only thing that runs stage 1's
# baked block list and stage 2's UFS reader at all, so leaving it out would
# mean the whole second reader is exercised by nothing.  It costs one boot.
# It asserts on MEMORY rather than on the screen -- the kernel halts for want
# of a root it can mount until 2.4 -- so read tests/ufsboot.json before
# treating a red here as a screen problem.

# mountprobe IS GONE FROM THIS LIST (2026-09-05) AND ITS OWN NOTE PREDICTED
# THE SHAPE OF WHY.  It read: "What it would do without the volume is worse
# than skipping: dev_mountcase scans, finds nothing, and returns 0, which on
# the console is indistinguishable from seventeen passes."  That is what had
# been happening, from a cause the note did not have -- not a missing volume,
# but `dev_mount' returning at `if (root_status == 1)' before the scan, which
# it has done on every boot since the root became UFS.  MEASURED: the probe's
# own boot klog holds 1,159 bytes of log and not one `fs: /dev' line, so its
# only assertion -- `klog_lacks "fs: /dev SELF-TEST FAILED"' -- was passing
# vacuously.
#
# mount(2) IS THEREFORE UNCOVERED IN THIS GATE UNTIL mount(8) LANDS, and that
# is the honest state rather than a regression: the coverage it is losing was
# already zero.  The replacement is a userland test -- `mount /dev/sd1 /mnt;
# ls /mnt' -- which is a better instrument for the same claim, being the way a
# person uses it.  bsd211probe went with it; that one could not run here at
# all, `disk/bsd211root.po' being absent from the tree.



# ticksprobe IS A CHECK ON THE INSTRUMENT, NOT ON THE OS, and that is the
# argument for it.  The harness schedules every timed action -- each injected
# keystroke, the dump, the hard cut-off -- by counting `emu.register_frame_done'
# callbacks.  If MAME ever coalesces or skips those, the counter runs slow, the
# guest gets its input at different EMULATED moments, and every log in both runs
# still prints the same frame numbers, because those numbers ARE the counter.
# Nothing else in the suite could notice.  It was the leading explanation for
# apple/fgx#265 and apple/fgx#266 until it was measured and ruled out -- 4943
# guest ticks at plugin frame 5101, idle and under this suite alike -- and a
# measurement nothing re-runs is one that quietly stops being true.  Cheap: one
# boot to a prompt, no workload.

# floppy_boot IS OUT OF THE LIST, AND THE FLOPPY IS PARKED (2026-09-06):
# "if we pursue a floppy image later it will be with a specific purpose".  The
# rest of this note is kept because it is the argument for putting it BACK, and
# whoever un-parks the image will want it.
#
#   floppy_boot IS HERE BECAUSE THE RESCUE FLOPPY BROKE IN SILENCE.  It is the
#   only test that builds and boots disk/fgx-floppy.po, it was never gated, and
#   by 2026-08-29 the floppy did not build AT ALL on main -- `make_floppy' died
#   adding /bin/mkdir, which is apple/fgx#208, and nothing reported it because
#   the floppy is its own ninja edge and no fixture booted it.  The image is
#   also a RELEASE artifact, so a silent overflow ships as a missing download
#   rather than a failed build.  It needs no env of its own, unlike `mdboot'
#   (apple/fgx#257), so it can simply join the list.
#
# THE OVERFLOW IT WATCHED FOR IS BACK AND MEASURED: apple/fgx#340 puts the image
# over by `rm' + `sync', 75,261 bytes, found by dropping binaries until it
# built.  So this is not a gate that would pass if restored today -- the payload
# is the open question, and the payload follows from what the floppy is FOR.

# THE READ SIDE JOINED IN ONE PASS (apple/fgx#232), and the sweep that added it
# is the argument for it: eleven tty fixtures were green, unwatched and outside
# GATE_TESTS, and running them three times each found `ptyintr' RED 3 of 3 --
# a defect nothing had reported because nothing ran it.  The ten that were
# stable are here; ptyintr is filed as apple/fgx#251 instead.
#
# `rdstop' IS THE ONE WITH A KNOWN SENSITIVITY, said out loud rather than
# discovered later: it drives its ^Z from outside with `raw_inject' on frames
# RELATIVE TO THE AUTOBOOT PASTE, so a change in kernel SIZE moves the boot and
# with it where the injection lands -- which is how it went green once without
# anyone fixing anything (apple/fgx#232, 2026-08-26).  It is in the gate anyway:
# it is the only cover in the tree for a blocking tty read resuming through the
# no-handler ERESTART arm, and the gate is where a flake gets seen rather than
# where it gets hidden.
#
# `wireacc' and `wirelogin' are NOT here and cannot be: they need the Uthernet II
# slot and a host network on 192.168.2.x.  `wirelogin' is apple/fgx#227's only
# wire-level witness, so that gap is real and is recorded on the issue.
#
# `ptyrec` guards the RECORD-MODE class, and it is here because the gate was
# MEASURED BLIND to it (2026-08-22).  A pty master answers a read with a whole
# record and _Sys_Read must dispatch its op ONCE; with that turned off, all 34
# tests below stayed green, telnet_loopback stayed green, and ptykey stayed
# green -- ptykey WRITES to a master and never reads one, and telnet_loopback's
# manifest declines to assert the `login:' prompt, which is the only output a
# master read produces.  So the one path apple/fgx#198 is about had no witness
# anywhere.  Its failure mode is a HANG, not a wrong answer, which is the other
# reason it belongs in a gate rather than in a drawer.
#
# `devnode` is the ONLY test that can tell the real /dev from the synthesized
# one, which is exactly why it is here rather than left to the suite.  Both
# namespaces answer to `/dev/null' during the transition, so every ordinary use
# of a device passes whichever road it walked -- the same "two roads, one
# answer" shape that made a dead per-type table look alive at UFS 1.7d I2c until
# a mutation was tried.  It walks a name only the MOUNT can serve
# (`/dev/./console': the registry's suffix scan stops at the '/' and looks up
# `.'), so a green result is evidence.  It has demonstrated it can fail twice:
# forcing dev_open to ENXIO drops the write needle, and turning the read site's
# far-ops branch into a fall-through raises `cat: read error'.
# `ptykey` guards a CLASS too, and the same way: SYS_GETKEY/SYS_POLLKEY take no
# fd, so for as long as they existed a program on a pty read the PHYSICAL
# CONSOLE -- vi over telnet, more's SPACE, ping's ^C, all of it (apple/fgx#151).
# The fixture writes one byte into a pty from the master and types another at
# the console, and the program on the pty must see only its own.  It is the
# only test that can tell those two apart, and it stayed RED through the whole
# campaign until the last branch closed the gate, so it has already
# demonstrated it can fail.
#
# `shexport` is here because `export' in /bin/sh never reached a child's
# environment (apple/fgx#153) and the entire suite was green: not one test read
# an exported variable from a separate BINARY, so a shell that only remembered
# the name looked exactly like one that passed it on.  It guards a CLASS in the
# compiler, not the shell -- fcc lost the return STRUCT ID of a function whose
# signature came from the --sigs sidecar, and with the id gone `f(x)->m |= v'
# fell into the K&R global-member pun, whose '->' arm dereferences a base that
# is already the pointer.  Every --sigs build (bsh, tcsh, elvis) can hit it, and
# it miscompiles in SILENCE, which is why the guard has to be a behaviour test
# on the machine rather than a golden.
#
# `sockleak` + `sockemfile` are the two loopprobe modes, and they were outside
# the gate while every socket defect this month landed in the code they cover.
# Both need no hardware and no peer -- one process does the whole closed loop --
# so the only thing keeping them out was that nobody had put them in.  Between
# them they carry every negative assertion the socket layer has: that a
# descriptor gives its W5100 slot back (#132), that a claim refuses a live
# socket (#133) and that the chip path refuses a loopback one (#139), that dup2
# tears a socket down (#134), and that an accept which fails on resources leaves
# the connection ACCEPTABLE (#145).  Each of those was a silent defect that the
# rest of the suite was green through.
#
# `selwild` is 8 seconds and guards the thing a card-less machine cannot
# otherwise notice: bind(0.0.0.0) must serve LOOPBACK.  BSD's wildcard means
# every local address and 127.0.0.1 is one whether or not an Ethernet card is
# fitted, but listen() went to the W5100 unconditionally, so on the standard
# harness -- which reports `uthernet2: absent' -- a server binding INADDR_ANY
# simply did not exist (apple/fgx#127, #128).  Its card-bearing sibling
# `selwildhw' guards apple/fgx#144 and is NOT here: it needs -sl1 uthernet2,
# which forces real-time MAME pacing, and it costs 2m27s against this gate's
# 73.  Run it by name when the loopback/wire seam is touched.
#
# `dupfile` guards SILENT DATA LOSS, which is the reason it is here and not on
# the on-demand list.  Fs_Close has four arms and three of them gate teardown on
# the FCB refcount; the regular-file arm did not, so closing one of two fds on a
# file made the module clear its FST_InUse and a write through the survivor
# landed in a slot nobody owned -- returning the right count, growing the file's
# EOF by exactly that much, and putting ZEROS on disk (apple/fgx#138).  Both the
# caller's return check and a reader's size check saw success.  `duptest' could
# not see it: it dups STDOUT, a chardev, and chardevs have had the gate all
# along.  Three shapes, all three measured red before the fix.
#
# `trunkfree` guards the OTHER half of the block-release walk.  `_pul_freeSap`
# is shared by unlink and by a shrink, and the two differ in exactly the way
# that turns a leak into CORRUPTION: unlink frees the index block, so nothing is
# left pointing at the released data, while a partial shrink KEEPS it and must
# zero the slots it frees.  The suite exercises unlink constantly and exercised
# a shrink's reclamation not at all (apple/fgx#68).  Needs no hardware.
#
# `alrmintr` guards a CLASS: a signal source that posts the pending bit without
# waking a blocked target.  alarm(2) did exactly that for as long as it has
# existed (apple/fgx#152) and no test could see it, because the only in-tree
# user of alarm-as-timeout was an FGX ttyread() that polled the keyboard ring
# instead -- so the syscall's blocking case was never once exercised.  The test
# fails by HANGING, which is the honest failure for "the task never woke".

# `coninv` is here because the whole 25-row screen went inverse video on the
# first scroll for days and NOTHING in the suite saw it: every console
# assertion in the harness reads CHARBUF, and CHARBUF was the one buffer the
# corruption missed.  It guards a class -- an MVN leaves DBR = the destination
# bank, so any absolute (DBR-relative) read before the next _DBRK silently
# comes from the wrong bank -- and it guards the only observable the text
# assertions structurally cannot see: what the pixels are actually coloured.

# `rename` is here for apple/fgx#29, and it is 2.7 s.  rename(2) HUNG THE
# MACHINE on every call -- same directory, cross directory, files, directories,
# from the shell or from a bare C probe -- and nothing in the suite exercised
# rename or mv at all, so it survived indefinitely.  The cause was not in the FS
# code it appeared to be in: _Mod_RegistryAppend wrote its entry-offset scratch
# DBR-relative while DBR was the MODULE bank, smashing four bytes of the loaded
# module's own image.  Only prodos.mod is long enough for that window to land on
# code, and it landed inside _fop_rename, which is why booting, opening, reading,
# writing, creating and unlinking all stayed green.  So this also guards the
# LOADER: a boot cannot see a module whose image is corrupt in a routine the
# boot never calls.

RESULT="build only"
if [ "$MODE" = build-only ]; then
    note "tests SKIPPED (--no-tests)"
else
    # A test whose manifest names an EXPERIMENTAL slot device (secondsight,
    # microdrive: in no published MAME or Ample) runs only on a MAME that has
    # it, so a stock install can run a clean gate.  The skip is printed, and
    # FGX_GATE_EXPERIMENTAL=1 makes a missing device a failure instead.
    GATE_MAME="${MAME:-/Applications/Ample.app/Contents/MacOS/mame64}"
    GATE_SLOTS="$("$GATE_MAME" -listslots apple2gs 2>/dev/null || true)"
    RUN_TESTS=""
    for t in $GATE_TESTS; do
        missing=""
        for dev in secondsight microdrive; do
            grep -qw "$dev" "tools/mame_test/tests/$t.json" 2>/dev/null \
                && ! printf '%s\n' "$GATE_SLOTS" | grep -qw "$dev" \
                && missing="$missing $dev"
        done
        if [ -z "$missing" ]; then
            RUN_TESTS="$RUN_TESTS $t"
        elif [ "${FGX_GATE_EXPERIMENTAL:-0}" = 1 ]; then
            fail_out "$t needs the experimental MAME device(s)$missing, which $GATE_MAME lacks"
        else
            note "  $t SKIPPED: needs the experimental MAME device(s)$missing"
        fi
    done
    GATE_TESTS="$RUN_TESTS"
    NTESTS=$(printf '%s\n' $GATE_TESTS | wc -l | tr -d ' ')
    note "tests ($NTESTS: boot, heap, fork, shell)"
    # --fresh deliberately: the green cache would let the gate skip itself, and
    # "cached PASS" is not evidence that THIS tree boots.
    python3 tools/mame_test/run.py --headless --no-state --fresh $GATE_TESTS \
        >"$SUITE_LOG" 2>&1
    OUT="$(tail -1 "$SUITE_LOG")"
    note "  $OUT"
    printf '%s' "$OUT" | grep -q "^${NTESTS} passed, 0 failed" || {
        grep -E '✗|FAIL|ERROR' "$SUITE_LOG" | head -8
        fail_out "gate tests failed: $OUT (see $SUITE_LOG)"
    }
    RESULT="$OUT"
fi


# --- fcc RUNTIME correctness: the multibank sweep + the fixture oracle -------
#
# The golden suite above pins EMITTED ASSEMBLY, not behaviour.  These two are
# the only things in the tree that actually EXECUTE fcc's output under the
# kernel, and until now neither ran automatically -- the oracle's own docstring
# calls itself the pre-commit gate for compiler work, and it was a thing you had
# to remember to type.  That is the same shape as issue #11: mbig was a
# documented exit criterion sitting in no gate, so a regression walked past it.
#
# Trigger is the SAME content hash the goldens use, and deliberately so: it
# covers toolchain/lib, i.e. libc, which is where #11 actually happened.  Kernel
# changes are not in the trigger -- GATE_TESTS above covers boot, heap, fork,
# pipes and signals in seconds, and putting an 8-minute oracle behind every
# kernel edit would buy little and cost constantly.
#
# Separate stamp from the goldens: a green golden run is not evidence that the
# compiled code RUNS, so the two must be able to disagree about what they have
# verified.
RUNTIME_STAMP=".gate/fcc-runtime.stamp"
RUNTIME_HASH="$(fcc_runtime_hash | shasum | cut -d' ' -f1)"
if [ "$MODE" = build-only ]; then
    note "sweep + oracle SKIPPED (--no-tests)"
elif [ -f "$RUNTIME_STAMP" ] && [ "$(cat "$RUNTIME_STAMP")" = "$RUNTIME_HASH" ]; then
    note "fcc unchanged since the sweep + oracle last passed -- skipping them"
else
    note "fcc SOURCE changed -- multibank sweep (43 far-pointer constructs)"
    MB_LOG=".gate/${SHA}.multibank.log"
    python3 toolchain/tests/multibank/run_multibank.py >"$MB_LOG" 2>&1 || {
        grep -E '^==> (per-construct|FAIL)' "$MB_LOG" | tail -3
        fail_out "multibank sweep failed (see $MB_LOG)"
    }
    note "  $(grep -E '^==> PASS' "$MB_LOG" | tail -1 | sed 's/^==> //')"

    note "fcc SOURCE changed -- runtime fixture oracle (change-scoped)"
    OR_LOG=".gate/${SHA}.oracle.log"
    python3 toolchain/tests/run_runtime.py >"$OR_LOG" 2>&1 || {
        grep -E '^ +(wrong-exit|no-marker|crash|HARNESS)' "$OR_LOG" | head -8
        fail_out "runtime oracle: $(grep -E 'oracle-validated pass' "$OR_LOG" | tail -1) (see $OR_LOG)"
    }
    note "  $(grep -E 'oracle-validated pass' "$OR_LOG" | tail -1 | sed 's/^ *//')"
    # AND WHAT IT DID NOT COVER.  run_runtime.py prints a NOTE whenever its
    # scoping is narrower than a reader would assume -- "the other 346 are NOT
    # covered" -- and this line used to grep out the pass count and drop that.
    # The tool was honest and the gate threw the honesty away: UFS 1.12d's
    # vnodepool regression sat under a green gate that had printed 238/238 over
    # a 240-of-586 sample the broken fixture was not in.  A count without its
    # denominator is not a result.
    grep -E '^==> NOTE:' "$OR_LOG" | sed 's/^==> /  /' | fold -s -w 76 | \
        while IFS= read -r l; do note "  $l"; done
    # A run that selected nothing is not evidence -- but leaving it at that was
    # not enough, and apple/fgx#77 and #78 are what it cost.
    #
    # The trigger fires on fcc AND libc.  Change-scoping, though, keys on
    # FIXTURE sources and goldens, so a change to either of those two selects
    # exactly zero fixtures -- the oracle announces itself, runs nothing, and
    # the gate goes green.  Not stamping means the next gate retries and selects
    # zero again.  Forever.
    #
    # That is the LIBC CONTRACT case and it is not hypothetical: system(3)
    # changed to return the wait status (#61) and signal() gained a real
    # disposition table (#58).  Both left a fixture asserting the OLD contract,
    # and neither was caught, because no fixture source had changed.  They sat
    # wrong for weeks and were found by reading, not by the gate.
    #
    # So an empty selection is not "nothing to do" -- it is the precise signal
    # that what changed was the compiler or the library rather than a test, and
    # that is when the WHOLE oracle has to run.
    #
    # Residual, named rather than left to be discovered: a libc contract change
    # committed together with an unrelated fixture edit still selects only that
    # fixture.  Closing that means always running --all when the trigger fires,
    # which costs a few minutes on every fcc commit; this buys most of the
    # protection for none of it.
    if grep -q 'fcc fixtures selected -- nothing to run' "$OR_LOG"; then
        note "  change-scoping selected zero -- fcc/libc changed, running --all"
        python3 toolchain/tests/run_runtime.py --all >"$OR_LOG" 2>&1 || {
            grep -E '^ +(wrong-exit|no-marker|crash|HARNESS)' "$OR_LOG" | head -8
            fail_out "runtime oracle (--all): $(grep -E 'oracle-validated pass' "$OR_LOG" | tail -1) (see $OR_LOG)"
        }
        note "  $(grep -E 'oracle-validated pass' "$OR_LOG" | tail -1 | sed 's/^ *//')"
    # AND WHAT IT DID NOT COVER.  run_runtime.py prints a NOTE whenever its
    # scoping is narrower than a reader would assume -- "the other 346 are NOT
    # covered" -- and this line used to grep out the pass count and drop that.
    # The tool was honest and the gate threw the honesty away: UFS 1.12d's
    # vnodepool regression sat under a green gate that had printed 238/238 over
    # a 240-of-586 sample the broken fixture was not in.  A count without its
    # denominator is not a result.
    grep -E '^==> NOTE:' "$OR_LOG" | sed 's/^==> /  /' | fold -s -w 76 | \
        while IFS= read -r l; do note "  $l"; done
    fi
    printf '%s\n' "$RUNTIME_HASH" > "$RUNTIME_STAMP"

    # Both harnesses stage fixture binaries under disk_src/tests/, and the
    # image builder copies the whole tree at image time -- so a gate run would
    # otherwise leave the boot volume carrying test scratch that a clean build
    # does not have.  Put it back the way a clean build leaves it: ALL of it,
    # not the disk target alone.  The rebuild rewrites the far-bank listing and
    # the module files, and the kernel, build-identity and bank-packing checks
    # stamp against those; left unstamped, `ninja -n` has work to do and
    # run.py refuses the next suite as testing a stale image.
    rm -rf disk_src/tests
    ninja all >/dev/null 2>&1 || fail_out "rebuild after the sweep failed"
fi

ELAPSED=$(( $(date +%s) - START ))
python3 - "$RECEIPT" "$SHA" "$TREE" "$MODE" "$RESULT" "$ELAPSED" "$HISTORY" <<'PY'
import json, os, sys, time
p, sha, tree, mode, result, secs, hist = sys.argv[1:8]
reds = 0
if os.path.exists(hist):
    for line in open(hist):
        try: r = json.loads(line)
        except ValueError: continue
        if r.get("sha") == sha and not r.get("ok"):
            reds += 1
rec = {"sha": sha, "tree": tree, "mode": mode, "ok": True,
       "result": result, "seconds": int(secs), "reds_before": reds,
       "ts": int(time.time())}
json.dump(rec, open(p, "w"), indent=1)
with open(hist, "a") as f:
    f.write(json.dumps(rec) + "\n")
if reds:
    print("==> NOTE: this SHA has been RED %d time(s) before -- a green here "
          "does not undo that (%s)" % (reds, hist))
PY
note "GATE GREEN in ${ELAPSED}s  (receipt: $RECEIPT)"

# --- optional mirror: GitHub commit status ---------------------------------
# Best-effort only.  See the header: correctness never depends on this landing.
if [ "${FGX_GATE_POST:-0}" = 1 ] && command -v gh >/dev/null 2>&1; then
    gh api "repos/{owner}/{repo}/statuses/${SHA}" -X POST \
        -f state=success -f context=local-gate \
        -f "description=gate green (${ELAPSED}s)" >/dev/null 2>&1 \
        && note "mirrored to GitHub commit status" \
        || note "GitHub mirror failed (not a gate failure)"
fi
