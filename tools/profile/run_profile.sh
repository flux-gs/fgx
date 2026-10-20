#!/bin/bash
# Phase-0 profiler driver.  Builds a tool (optionally with an alternate fcc),
# runs it under MAME with PC-sampling, and emits a category profile + the
# whole-tool wall-clock (emu.time of the armed window).
#
# Usage:
#   tools/profile/run_profile.sh <tool> [tag]
#       Build <tool> with the CURRENT toolchain/fcc, run, profile.  tag (default
#       "cur") labels the output artifacts under tools/profile/out/.
#   FCC_BIN=/path/to/fcc tools/profile/run_profile.sh <tool> <tag>
#       Install FCC_BIN as toolchain/fcc first (asserting it is executable and
#       printing its --version), build with it, then RESTORE the original
#       toolchain/fcc.  Use this for an old-vs-new before/after.
#
# tools: sed | fas
#
# The tool is built by the ninja edge that ships it (bin/sed.bin; fas is
# tools/fas/fas_fgx, the fasfgx rule), so the profile measures the binary on
# the disk image.  The listing is the link's seg0 table (dyn.ld/ for a dynamic
# tool, static.ld/ for a static one); the
# report attributes samples by that one table, so time spent in a shared
# library (libc.so and the rest) comes out unattributed.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/profile/out"; mkdir -p "$OUT"
TOOL="${1:?usage: run_profile.sh <tool> [tag]}"
TAG="${2:-cur}"

TARGET="bin/${TOOL}.bin"; LST=""
case "$TOOL" in
  sed)
    PRODOS_DIR="/FGX/BIN"; PRODOS_NAME="SED"
    CMD="sed -f /docs/heavy.sed /docs/big.txt > /root/profout"
    EXTRA_STAGE='{"host":"tools/profile/workloads/big.txt","prodos_dir":"/FGX/DOCS","name":"BIG.TXT"},
                 {"host":"tools/profile/workloads/heavy.sed","prodos_dir":"/FGX/DOCS","name":"HEAVY.SED"},' ;;
  fas)
    TARGET="tools/fas/fas_fgx"; LST="tools/fas/dyn.ld/seg0_Output.txt"
    PRODOS_DIR="/FGX/USR/BIN"; PRODOS_NAME="FAS"
    CMD="fas /docs/big.s -o /root/bigout"
    EXTRA_STAGE='{"host":"tools/profile/workloads/big.s","prodos_dir":"/FGX/DOCS","name":"BIG.S"},' ;;
  *) echo "unknown tool: $TOOL (expected sed|fas)"; exit 2 ;;
esac

cd "$ROOT"

# --- build the tool, optionally with an alternate fcc -----------------------
RESTORE_FCC=""
if [ -n "${FCC_BIN:-}" ]; then
  [ -x "$FCC_BIN" ] || { echo "FCC_BIN $FCC_BIN not executable"; exit 3; }
  cp toolchain/fcc "$OUT/.fcc.restore.$$"; RESTORE_FCC="$OUT/.fcc.restore.$$"
  cp "$FCC_BIN" toolchain/fcc; chmod +x toolchain/fcc
fi
echo "fcc: $(./toolchain/fcc --version 2>&1 | head -1)"

ninja "$TARGET"
rc=$?
[ $rc -eq 0 ] || { echo "build failed"; [ -n "$RESTORE_FCC" ] && cp "$RESTORE_FCC" toolchain/fcc; exit $rc; }

# The link directory is the edge's own `dir`, so a stale dyn.ld/ or static.ld/
# left by a tool that changed link mode is never read.
[ -n "$LST" ] || LST="$(awk -v e="build ${TARGET}:" 'index($0, e) == 1 { f = 1; next }
  f && /^  dir = / { print $3 "/seg0_Output.txt"; exit } f && !/^  / { exit }' build.ninja)"
[ -n "$LST" ] && [ -f "$LST" ] || { echo "no seg0 listing for $TARGET"; [ -n "$RESTORE_FCC" ] && cp "$RESTORE_FCC" toolchain/fcc; exit 4; }

cp "$TARGET" "$OUT/${TOOL}_${TAG}.bin"
cp "$LST" "$OUT/${TOOL}_${TAG}.lst"
echo "built $TARGET ($(wc -c < "$TARGET") bytes) -> $OUT/${TOOL}_${TAG}.bin"

# restore the original fcc immediately after building
[ -n "$RESTORE_FCC" ] && { cp "$RESTORE_FCC" toolchain/fcc; rm -f "$RESTORE_FCC"; echo "restored toolchain/fcc"; }

# --- run under MAME with PC-sampling ---------------------------------------
MAN="$OUT/run_${TOOL}_${TAG}.json"
cat > "$MAN" <<JSON
{ "name":"prof_${TOOL}_${TAG}",
  "command":"$CMD",
  "timeout_s":150, "pc_sample":true,
  "stage_files":[
    $EXTRA_STAGE
    {"host":"$OUT/${TOOL}_${TAG}.bin","prodos_dir":"$PRODOS_DIR","name":"$PRODOS_NAME","replace":true}
  ],
  "expect":{"screen_lacks":["BRK","PANIC","Cannot","not found"]} }
JSON
python3 tools/mame_test/run.py --manifest "$MAN" || { echo "MAME run failed"; exit 5; }
cp "/tmp/fgx_test_prof_${TOOL}_${TAG}/pc_samples.json" "$OUT/${TOOL}_${TAG}_samples.json"

# --- profile ----------------------------------------------------------------
python3 tools/profile/profile_report.py \
  --samples "$OUT/${TOOL}_${TAG}_samples.json" \
  --listing "$OUT/${TOOL}_${TAG}.lst" \
  --tool "${TOOL}_${TAG}" --out "$OUT/${TOOL}_${TAG}_report.md"
echo "wrote $OUT/${TOOL}_${TAG}_report.md"
