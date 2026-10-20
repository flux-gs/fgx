#!/bin/sh
# Run a filesystem probe gate, and leave the tree exactly as it was found.
#
#   sh tools/tryprobe.sh              the block layer   (kernel.ufsprobe)
#   sh tools/tryprobe.sh ufsvnprobe   reading vnode ops (kernel.ufsvnprobe)
#   sh tools/tryprobe.sh ufswprobe    writing vnode ops (kernel.ufswprobe)
#   sh tools/tryprobe.sh ufsdevprobe  device files      (kernel.ufsdevprobe)
#   sh tools/tryprobe.sh vnopsprobe   the file/vnode glue (kernel.vnopsprobe)
#
# THREE GATES SINCE UFS 1.12b, because ufs.mod is one 64 KB bank and the two
# halves of the probe stopped fitting in it together: the shipping module is
# 29,372 bytes, the single-gate probe build was 61,287 of 65,536, and 1.12a's
# shipping code alone is 4,612.  They are MUTUALLY EXCLUSIVE -- the ERR in
# include/kernelc.s refuses both being set -- so this script runs ONE, and
# running both means running it twice.  Neither is a superset of the other:
# ufsprobe owns the superblock, the allocators and bmap; ufsvnprobe owns the
# mount, the inode hash, read, lookup and readdir; ufswprobe owns write, fsync,
# readlink, truncate, setattr and the unlink-while-open release.
#
# kernel.ufsprobe IS OFF BY DEFAULT AND MUST STAY THAT WAY: the probe writes to
# a disk on the boot path, and since 1.11a it also churns the whole vnode pool
# to force a recycle -- 34 extra breads that pushed BOOT past the MAME suite's
# frame budget and failed 33 of 34 tests when the flag was left on in
# cfg/system.cfg.  So this flips it on, runs, and flips it back.
#
# gen.py FIRST.  build.ninja has no self-regen edge, so a C file added to
# tools/ninja/gen.py's source lists has NO BUILD RULE until gen.py is re-run --
# and the .s files are TRACKED, so the stale one assembles happily and `ninja`
# says "no work to do".  That is how ufs_inode.c and ufs_vnops.c were edited for
# a whole session with none of the edits reaching the machine (apple/fgx#171).
#
#-----------------------------------------------------------------------------
# EVERY STEP IS CHECKED, AND THAT IS NEW (apple/fgx#184).
#
# The first version of this script discarded the exit status of every command in
# it.  A Fable review of apple/fgx#183 read it and found three ways that turns a
# broken run into a plausible result, all of them silent:
#
#   1. If gen_mod_bankpatch.py DIES -- which it does, deliberately, when the
#      scan finds no cells -- the error went to /dev/null and the OLD table
#      stayed in place.  `ninja -n` then reports "no work to do", because a
#      stale table already consumed by the build is self-consistent to ninja.
#      At run time _Mod_StampFnPtrs (kc_sys.s) writes the module's bank byte at
#      every address in that table, before any C runs: with addresses from a
#      different layout that is one byte of corruption at N arbitrary offsets in
#      the image -- deterministic per build, and MOVING whenever code size
#      changes.  Which is indistinguishable from the fault #183 was chasing.
#
#   2. If run.py fails, its status was discarded and the grep below read the
#      PREVIOUS run's dump.txt.  A green could be inherited from an earlier
#      build entirely.
#
#   3. If the `for i in 1 2 3` ninja loop never succeeded, nothing said so.
#
# So: every step is checked, the tables are VERIFIED with --check after the
# build rather than assumed, and the dump is deleted before the run so a stale
# one cannot be read as this run's answer.
#
# EXCEPT THE RUN STEP, WHICH #184 DID NOT REACH AND #273 IS (2026-08-31).  All
# three findings above are about BUILD steps, and the sentence "every step is
# checked" was written from them -- so the one step whose result anybody reads
# kept both of its leaks for another seven weeks.  run.py's status went to
# /dev/null, and the verdict grep's failure was absorbed by an `|| echo' that
# reports to a human and returns 0 to the shell.  A probe that PANICKED before
# running a case exited 0.  Found by apple/fgx#272 doing exactly that.
#
# THE LESSON IS THE HEADER, NOT THE CODE: a file that announces its own rigour
# is the last place anyone looks for this, so the claim has to say which steps
# it covers rather than "every".
#
# WHAT "HANG" MEANS, HONESTLY.  It means the dump contained neither verdict
# string.  The PC printed with it is ONE SAMPLE taken when the frame budget
# expired, and $7D/D9FA -- the address it usually shows -- is the poll
# instruction of Blk_Read's wait loop, which is where a wedged machine, a
# retrying one and a merely slow one all sample.  It is a censored observation,
# not proof of a wedge.  Set TRYPROBE_TIMEOUT to raise the budget and tell them
# apart: if a 30-second "HANG" becomes a case number at 120, it was slow.
set -u
cd "$(dirname "$0")/.."

TIMEOUT="${TRYPROBE_TIMEOUT:-}"

# The fn-ptr patch tables are CONFIG-DEPENDENT: with the probe compiled in, the
# module is bigger and every cell moves, so the committed tables (which are the
# SHIPPING config's) stop matching.  Save them, let the build regenerate them,
# put them back.
#
# ufsdir.mod IS THE FOURTH AND WAS MISSING FROM THIS LIST until UFS 1.12d.  It
# became a module at 1.13a, when ufs.mod was split at a measured seam, and this
# script was not updated with it -- so a gate build in which ufs_vnops.c or
# ufs_lookup.c changes size regenerates three tables and leaves the fourth at
# the SHIPPING config's addresses.  That is failure mode 1 in the header above,
# exactly: _Mod_StampFnPtrs then writes a bank byte at N wrong offsets in
# ufsdir.mod's image before any C runs.  It went unnoticed because ninja's own
# --check edge fails the build rather than passing it -- the loud failure was
# doing the guard's job by accident.  Naming it here is what makes it work on
# purpose.
UFSTAB=src/modules/ufs/fnptr_patchsites.s
VFSTAB=src/modules/vfs/fnptr_patchsites.s
UPTAB=src/modules/ufsprobe/fnptr_patchsites.s
UDTAB=src/modules/ufsdir/fnptr_patchsites.s
# WHICH GATE.  The knob, the manifest and the test name all follow from it, so
# there is one place to add a third.
PROBE="${1:-ufsprobe}"
case "$PROBE" in
    ufsprobe)   KNOB=kernel.ufsprobe   ;;
    ufsvnprobe) KNOB=kernel.ufsvnprobe ;;
    ufswprobe)  KNOB=kernel.ufswprobe  ;;
    ufsdevprobe) KNOB=kernel.ufsdevprobe ;;
    vnopsprobe) KNOB=kernel.vnopsprobe ;;
    *) echo "tryprobe: unknown probe '$PROBE' (ufsprobe | ufsvnprobe | ufswprobe | ufsdevprobe | vnopsprobe)" >&2; exit 1 ;;
esac
# THE VERDICT PATTERN IS PER PROBE.  It was hardcoded to the ufs strings, so
# a probe that reports anything else printed `NO VERDICT' on a run that had
# gone perfectly -- which reads as a wedged machine rather than a grep that
# does not know the answer it is looking at.
VERDICT="${VERDICT:-ufs: BROKEN, case [0-9]*\|ufs: ok}"
CFG=tools/mame_test/tests/$PROBE.json
grep -q "^$KNOB = 0" cfg/system.cfg || \
    { echo "tryprobe: $KNOB is not 0 in cfg/system.cfg -- refusing to run, because
        this script restores it to 0 on exit and would be turning OFF a setting
        somebody else turned on" >&2; exit 1; }
cp $UFSTAB /tmp/.fgx_ufstab.$$ ; cp $VFSTAB /tmp/.fgx_vfstab.$$
cp $UPTAB /tmp/.fgx_uptab.$$ ; cp $UDTAB /tmp/.fgx_udtab.$$
cp $CFG /tmp/.fgx_cfg.$$

# RESTORE REBUILDS THE IMAGE, NOT JUST THE CONFIG.
#
# This used to end at `ninja include/config.s', which regenerates the config
# header and NOTHING ELSE.  The sources went back to the shipping config and
# `disk/fgxroot.fs' stayed as this script had left it: a PROBE kernel, ~9.5 KB of
# test code compiled into the tty bank, with nothing anywhere saying so.  The
# tree was left needing a build, which only `ninja -n' would have told you.
#
# THAT IS NOT THEORETICAL.  2026-08-29: a probe image sat in `disk/fgxroot.fs' after
# a gate run, was wrapped by hand with mdttool, and was flashed to the CF card of
# a real IIgs -- and the boot failure that followed was investigated as a kernel
# regression.  `tools/gate.sh' runs this script six times, so the window is open
# after every gate.
#
# IT IS ALSO A RECURRENCE.  Measured 2026-08-10, same class by a different route:
# `git stash; ninja; run a test; git stash pop' leaves `disk/fgxroot.fs' holding the
# OTHER kernel, and a probe went red four runs running against a fix that was in
# the tree but not in the image.  The lesson recorded then was REBUILD
# IMMEDIATELY, and this is that lesson applied to the one operation in the repo
# that changes the config behind your back.
#
# A FAILED REBUILD IS LOUD.  If it cannot converge, the tree is left holding a
# probe image and the user has to know: that is the exact state this function
# exists to prevent, so it must not fail quietly the way the old one-liner did.
restore() {
    cp /tmp/.fgx_ufstab.$$ $UFSTAB ; cp /tmp/.fgx_vfstab.$$ $VFSTAB
    cp /tmp/.fgx_uptab.$$ $UPTAB ; cp /tmp/.fgx_udtab.$$ $UDTAB
    cp /tmp/.fgx_cfg.$$ $CFG
    rm -f /tmp/.fgx_ufstab.$$ /tmp/.fgx_vfstab.$$ /tmp/.fgx_uptab.$$ \
          /tmp/.fgx_udtab.$$ /tmp/.fgx_cfg.$$
    sed -i.tryprobe "s/^$KNOB = 1/$KNOB = 0/" cfg/system.cfg && rm -f cfg/system.cfg.tryprobe
    # gen.py first, for the same reason the build path runs it first: a source
    # list change has no build rule until it is re-run.
    python3 tools/ninja/gen.py >/dev/null 2>&1
    # Three passes for the same reason the build path takes them -- the restored
    # tables are the shipping config's and have to be consumed.
    _rb=0
    for _i in 1 2 3; do ninja >/dev/null 2>&1 && { _rb=1; break; }; done
    if [ "$_rb" != 1 ] || ! ninja -n 2>&1 | grep -q "no work to do"; then
        echo "tryprobe: *** THE SHIPPING IMAGE WAS NOT REBUILT ***" >&2
        echo "  cfg/system.cfg is back to the shipping config, but disk/fgxroot.fs" >&2
        echo "  still holds the $PROBE kernel -- test code on the boot path." >&2
        echo "  DO NOT flash or wrap it.  Run 'ninja' and check it succeeds." >&2
        return 1
    fi
}
trap 'restore' EXIT INT TERM

die() { echo "tryprobe: $*" >&2; exit 1; }

# -i with an attached suffix is the one spelling BSD and GNU sed both read.
sed -i.tryprobe "s/^$KNOB = 0/$KNOB = 1/" cfg/system.cfg && rm -f cfg/system.cfg.tryprobe
[ -n "$TIMEOUT" ] && python3 - "$CFG" "$TIMEOUT" <<'PY'
import json, sys
p, t = sys.argv[1], int(sys.argv[2])
d = json.load(open(p)); d['timeout_s'] = t
json.dump(d, open(p, 'w'), indent=1)
PY

python3 tools/ninja/gen.py >/dev/null 2>&1 || die "gen.py FAILED"

# THE FIRST PASS IS EXPECTED TO FAIL, and hardening this script's exit checks
# is how that got established: flipping the config changes both modules' sizes,
# so the COMMITTED tables (the shipping config's) are stale by construction and
# ninja's own --check edge refuses them.  That refusal is the point -- the pass
# has to get far enough to LINK the modules and produce their listings, which is
# what the regeneration below reads.  So the thing to assert is not that ninja
# succeeded but that the listings exist and are newer than the module sources.
for i in 1 2 3; do ninja >/dev/null 2>&1 && break; done
for l in build/module_ufs_Output.txt build/module_vfs_Output.txt \
         build/module_ufsprobe_Output.txt build/module_ufsdir_Output.txt; do
    [ -f "$l" ] || die "$l missing -- the first pass did not reach the module link"
    [ "$l" -nt src/kernel/vfs/ufs_vnops.c ] || \
        die "$l is OLDER than the C it should describe -- the first pass failed
        before relinking, so the table below would be regenerated from a stale
        listing (apple/fgx#184)"
done

# Regenerate the tables for THIS config, then build again to consume them.
python3 tools/gen_mod_bankpatch.py build/module_ufs_Output.txt $UFSTAB --bank 07 \
    || die "ufs fn-ptr table regeneration FAILED -- the image would run with the
        shipping config's table and _Mod_StampFnPtrs would write the module's
        bank byte at N wrong addresses"
python3 tools/gen_mod_bankpatch.py build/module_vfs_Output.txt $VFSTAB --bank 06 \
    || die "vfs fn-ptr table regeneration FAILED (see above)"
# ufsprobe.mod carries the probe C since UFS 1.12c, so its table moves with the
# gate exactly as the other two do.  --allow-empty because at the SHIPPING
# config this module has no &function cells at all, which is expected here and
# nowhere else.
python3 tools/gen_mod_bankpatch.py build/module_ufsprobe_Output.txt $UPTAB --bank 08 --allow-empty \
    || die "ufsprobe fn-ptr table regeneration FAILED (see above)"
python3 tools/gen_mod_bankpatch.py build/module_ufsdir_Output.txt $UDTAB --bank 09 \
    || die "ufsdir fn-ptr table regeneration FAILED (see above)"

# THIS one must genuinely succeed: the tables now match, so a failure here is a
# real build error rather than the expected staleness above.
built=0
for i in 1 2 3; do ninja >/dev/null 2>&1 && { built=1; break; }; done
[ "$built" = 1 ] || die "second ninja pass FAILED three times -- a real build error"

ninja -n 2>&1 | grep -q "no work to do" || die "BUILD INCOMPLETE"

# SAY WHAT THIS CONFIG COSTS, because nothing else can (apple/fgx#233).  Each
# probe config is the shipping bank plus one probe file, and the number that
# matters -- how much of the 65,280-byte tty bank is left -- exists only while
# THIS config is built.  The restore below puts the shipping config back, so a
# reader who wants it afterwards has to rebuild.
#
# IT USED TO BE INVISIBLE AT EXACTLY THE MOMENT IT MATTERED.  When a half went
# over the ceiling, merlin32 reported `Object code size > 64 KB' against a line
# in a GENERATED file and this script swallowed it, so the failure named neither
# the bank nor the budget.  Printing the headroom on every run means the last
# green number is always in the log next to the config that produced it.
echo "== $PROBE: kernel bank headroom =="
python3 tools/check_kernel_ceiling.py || die "over a bank ceiling with $KNOB on"

# AND VERIFY, rather than trusting that the regeneration above converged.  The
# table is PUT last so one pass is meant to be enough; this is what says so.
python3 tools/gen_mod_bankpatch.py build/module_ufs_Output.txt $UFSTAB --bank 07 --check \
    || die "ufs fn-ptr table DRIFTED from the built image"
python3 tools/gen_mod_bankpatch.py build/module_vfs_Output.txt $VFSTAB --bank 06 --check \
    || die "vfs fn-ptr table DRIFTED from the built image"
python3 tools/gen_mod_bankpatch.py build/module_ufsprobe_Output.txt $UPTAB --bank 08 --allow-empty --check \
    || die "ufsprobe fn-ptr table DRIFTED from the built image"
python3 tools/gen_mod_bankpatch.py build/module_ufsdir_Output.txt $UDTAB --bank 09 --check \
    || die "ufsdir fn-ptr table DRIFTED from the built image"

# ONE BUILD, N RUNS.  Set TRYPROBE_RUNS to repeat.  This exists because the
# whole of apple/fgx#183's "band" table -- twelve pad sizes, ok/bad/ok/bad --
# was built from ONE run per build, and an intermittent fault at p~0.5 produces
# a table that looks exactly like a band.  Repeating the SAME image is the
# control that tells a position dependency from a lottery, and it costs a
# minute against a build's ten.
RUNS="${TRYPROBE_RUNS:-1}"
i=1
while [ "$i" -le "$RUNS" ]; do
    # THE SCRATCH VOLUME IS REBUILT PER RUN, and it is now belt-and-braces
    # rather than the only thing standing between two runs.  run.py stages every
    # spindle into the per-test scratch directory and hands MAME the COPY, so
    # the tracked image is not what the guest writes any more.  This used to
    # read "MAME gets the image BY PATH with no per-run copy", which was true
    # and was the reason run 2 of a wedged build read a volume run 1 half-wrote.
    # Kept because it costs a second and guarantees a pristine SOURCE whatever
    # else has been pointed at the file.
    rm -f disk/ufsscratch.fs
    ninja disk/ufsscratch.fs >/dev/null 2>&1 || die "run $i: scratch volume build FAILED"
    # The dump goes FIRST, so a stale one cannot be read as this run's answer.
    rm -f "/tmp/fgx_test_$PROBE/dump.txt"
    # THE RUN STEP IS CHECKED NOW, AND IT WAS THE ONE STEP #184 DID NOT COVER
    # (apple/fgx#273).  The header above describes at length how every step in
    # this script came to be checked -- and it fixed the BUILD steps, leaving
    # the one whose result anybody actually reads.  Both leaks were real and
    # independent: run.py's status went to /dev/null with no `||', so a manifest
    # assertion going red (PANIC is in every one of these manifests' screen_lacks)
    # was invisible; and the verdict grep had its failure absorbed by `|| echo',
    # which tells a human and returns 0 to the shell.  Being the last command of
    # the loop body, that echo was the script's exit status.  A probe that
    # PANICKED before running a single case therefore reported success.
    _runrc=0
    python3 tools/mame_test/run.py "$PROBE" --fresh >/dev/null 2>&1 || _runrc=$?
    [ -f "/tmp/fgx_test_$PROBE/dump.txt" ] || die "run $i: run.py produced no dump"
    printf 'run %d/%d: ' "$i" "$RUNS"
    _verdict=1
    grep -a -o "$VERDICT" /tmp/fgx_test_$PROBE/dump.txt || {
        _verdict=0
        echo "NO VERDICT at frame $(sed -n '1p' /tmp/fgx_test_$PROBE/dump.txt | tr -d 'frame: ') -- one PC sample: $(sed -n '2p' /tmp/fgx_test_$PROBE/dump.txt)"
    }
    # Whatever the manifest dumped, verbatim.  With TRYPROBE_REGIONS set this
    # prints the memory_regions block, which is the only instrument that
    # survives a boot with no console (apple/fgx#183).  BEFORE the die below, so
    # a failing run is the one that still gets its instruments printed.
    [ -n "${TRYPROBE_REGIONS:-}" ] && \
        grep -a -A 6 "$TRYPROBE_REGIONS" /tmp/fgx_test_$PROBE/dump.txt
    [ "$_verdict" = 1 ] \
        || die "run $i: the probe reported no verdict (diagnostic above)"
    # AND THE MANIFEST'S OWN VERDICT, which is not the same question.  VERDICT
    # matches `ufs: BROKEN, case N' as well as `ufs: ok' -- deliberately, since a
    # case number is the most useful thing on the screen -- so the grep above
    # succeeds on a RED probe.  run.py is what knows that BROKEN is in
    # screen_lacks.
    [ "$_runrc" = 0 ] \
        || die "run $i: run.py FAILED (rc=$_runrc) -- a manifest assertion went red; see /tmp/fgx_test_$PROBE/dump.txt"
    i=$((i + 1))
done
