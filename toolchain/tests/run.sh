#!/bin/bash
#==============================================================================
# fcc test runner — fast-loop fixture gate (FGX2 one-mode, P3-2.6).
#
# For each <name>.c under tests/M*/:
#   1. fcc --data-segment <name>.data.s <name>.c -o <name>.s   (one-mode)
#   2. diff <name>.s      <name>.expected.s          (textual, code seg)
#      diff <name>.data.s <name>.expected.data.s     (textual, data seg)
#   3. link the fixture binary: fixture_link.py, which runs fgx_static over
#      fcc_output.s / fcc_output.data.s (crt0_lib, libfgx's program-mode
#      compile, libc's library-mode compile, plus the M-dir's _link.json)
#   4. cp fixture_fgx -> <name>.expected.bin         (BUILD PRODUCT, gitignored)
#
# The .bin is NOT a golden and is NOT committed: it is fgx_static applied to
# the .expected.s and the committed libraries, all of which are committed
# TEXT — so it carries no information the repo does not already hold, while a
# one-line libc change rewrote all ~550 of them (33 MB of binary churn per change).
# fcc's output is pinned by the .expected.s/.expected.data.s diffs above;
# assembler correctness by src/as/tests (byte-eq vs the Merlin32 oracle);
# runtime behaviour by tests/run_runtime.py against tests/oracle.json.  The
# .bin is left on disk because run_runtime.py stages it onto the sweep disk and
# metrics.sh/bench measure its size.
#
# REGEN=1 ./run.sh   rewrites the .expected.s/.expected.data.s goldens from the
# current fcc instead of diffing (per-milestone regen).
#
# ./run.sh [name ...]        run (or REGEN) only the named fixtures — the
#                            fast dev loop (task #60).  NOTE: after a CODEGEN
#                            or pile/runtime change, goldens beyond the named
#                            set are stale too — finish with one full REGEN.
# PARALLEL=N ./run.sh        per-M-dir parallel workers (default 8; fixtures
#                            within one M-dir share scratch names so the dir
#                            is the unit).  PARALLEL=1 restores serial.
#
# Exits 0 on full success; 1 on any failure.
# Each fixture's intermediates are removed after the test (whether pass or
# fail) so the source tree stays clean.
#==============================================================================

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
FCC="$HERE/../fcc"
LINK="$HERE/fixture_link.py"
REGEN="${REGEN:-0}"

if [ ! -x "$FCC" ]; then
    echo "fcc not built. Run: make -C $(dirname "$FCC")" >&2
    exit 2
fi

if ! command -v merlin32 >/dev/null 2>&1; then
    echo "merlin32 not on PATH" >&2
    exit 2
fi

for l in libfgx libtermlib; do
    if [ ! -f "$HERE/../../build/static_libs/$l.s" ]; then
        echo "build/static_libs/$l.s not built. Run: ninja" >&2
        exit 2
    fi
done

pass=0
fail=0
failed_names=()

cleanup() {
    local dir="$1"
    local name="$2"
    rm -f "$dir/$name.s" "$dir/$name.data.s" \
          "$dir/fcc_output.s" "$dir/fcc_output.data.s" "$dir/fixture_fgx" \
          "$dir/.diff.out" "$dir/.link.err"
    rm -rf "$dir/.ld"
}

# Link the staged fcc_output.s / fcc_output.data.s in $dir into
# $dir/fixture_fgx through fixture_link.py (fgx_static).  Returns non-zero and
# leaves the linker's output in .link.err on failure.
link_fixture() {
    local dir="$1"
    (
        cd "$dir" || exit 1
        if ! python3 "$LINK" --mdir . --scratch .ld --code fcc_output.s \
                --data fcc_output.data.s --out fixture_fgx >.link.err 2>&1; then
            echo "STAGE link: fixture_link.py failed" >>.link.err
            exit 1
        fi
    )
}

process_dir() {
    local m_dir="$1"
    for c in "$m_dir"*.c; do
        [ -f "$c" ] || continue
        name=$(basename "$c" .c)
        if [ -n "${RUN_NAMES:-}" ]; then
            case " $RUN_NAMES " in
                *" $name "*) ;;
                *) continue ;;
            esac
        fi
        dir="${m_dir%/}"
        expected_s="$dir/$name.expected.s"
        expected_ds="$dir/$name.expected.data.s"
        expected_bin="$dir/$name.expected.bin"

        if [ "$REGEN" != "1" ] && { [ ! -f "$expected_s" ] || [ ! -f "$expected_ds" ]; }; then
            echo "SKIP $name (missing fixture files)"
            continue
        fi

        # 1. fcc compile (run from the fixture dir so the file-comment baked
        # into output uses just `<name>.c`, not a longer path).
        #
        # Bank-0 stack campaign 1.3: an optional COMMITTED `<name>.softscc`
        # sidecar names the functions this fixture compiles with soft
        # (data-bank) frames.  Without one FCC_SOFT_SCC is empty, soft_scc_load
        # returns immediately and codegen is bit-for-bit unchanged -- which is
        # why the other 547 goldens do not move.  It is a SOURCE file, never a
        # generated one: the linker's committed SCC list is a separate artifact,
        # and a fixture that read THAT would tie the compiler gate to a
        # link-time fact and re-open the build-writes-its-own-inputs trap.
        softscc=""
        [ -f "$dir/$name.softscc" ] && softscc="$name.softscc"
        # $name.sigs -- the --sigs sidecar, for the fixtures that are ABOUT it.
        # softscc's shape exactly, and for its reason: the flag changes what
        # fcc KNOWS before parsing, so a fixture cannot reach it from the C.
        # The file is a SOURCE file (three lines of libc's own signature
        # table), never generated -- reading build/libc.sigs here would tie the
        # compiler gate to a whole-libc artifact that moves every time libc
        # does, and every golden with it.
        # A PLAIN STRING AND NOT AN ARRAY: this script runs under `set -u',
        # and bash 3.2 -- which is what /bin/bash is on macOS -- treats an
        # EMPTY array's "${a[@]}" as an unbound variable.  That failed all 608
        # other fixtures at once while the new one passed.  Fixture names are
        # identifiers, so the unquoted split is safe.
        sigsarg=""
        [ -f "$dir/$name.sigs" ] && sigsarg="--sigs $name.sigs"
        # A directory's fixtures may all compile with extra flags (M42: the
        # libc.so library mode, --libso), named in its _fcc.flags.  A plain
        # string for the same reason as sigsarg.
        dirflags=""
        [ -f "$dir/_fcc.flags" ] && dirflags=$(cat "$dir/_fcc.flags")
        if ! (cd "$dir" && FCC_SOFT_SCC="$softscc" \
                           "$FCC" --data-segment "$name.data.s" \
                                  $sigsarg $dirflags \
                                  "$name.c" -o "$name.s" 2>"$dir/.diff.out"); then
            echo "FAIL $name (fcc exit non-zero)"
            sed 's/^/    /' < "$dir/.diff.out"
            fail=$((fail+1))
            failed_names+=("$name")
            cleanup "$dir" "$name"
            continue
        fi

        if [ "$REGEN" != "1" ]; then
            # 2. textual diffs (code + data segments)
            if ! diff -u "$dir/$name.s" "$expected_s" > "$dir/.diff.out" 2>&1; then
                echo "FAIL $name (.s mismatch)"
                sed 's/^/    /' < "$dir/.diff.out"
                fail=$((fail+1))
                failed_names+=("$name")
                cleanup "$dir" "$name"
                continue
            fi
            if ! diff -u "$dir/$name.data.s" "$expected_ds" > "$dir/.diff.out" 2>&1; then
                echo "FAIL $name (.data.s mismatch)"
                sed 's/^/    /' < "$dir/.diff.out"
                fail=$((fail+1))
                failed_names+=("$name")
                cleanup "$dir" "$name"
                continue
            fi
        fi

        # 3. assemble + link the FGX2 fixture binary.
        cp "$dir/$name.s" "$dir/fcc_output.s"
        cp "$dir/$name.data.s" "$dir/fcc_output.data.s"
        if ! link_fixture "$dir"; then
            stage_line=$(grep -m1 '^STAGE ' "$dir/.link.err" 2>/dev/null)
            echo "FAIL $name (${stage_line:-assemble/link error})"
            [ -f "$dir/.link.err" ] && tail -12 "$dir/.link.err" | sed 's/^/    /'
            [ -f "$dir/error_output.txt" ] && head -20 "$dir/error_output.txt" | sed 's/^/    /'
            fail=$((fail+1))
            failed_names+=("$name")
            cleanup "$dir" "$name"
            continue
        fi

        # 4. publish the linked binary as a build product (gitignored) for
        # run_runtime.py / metrics.sh.  No cmp: see the header note.
        cp "$dir/fixture_fgx" "$expected_bin"

        if [ "$REGEN" = "1" ]; then
            cp "$dir/$name.s" "$expected_s"
            cp "$dir/$name.data.s" "$expected_ds"
            echo "REGEN $name"
        else
            echo "PASS $name"
        fi
        pass=$((pass+1))

        cleanup "$dir" "$name"
    done
}

# --- Dispatcher (task #60) --------------------------------------------------
# Internal per-dir mode: `run.sh --dir <M-dir>` processes one fixture dir
# (RUN_NAMES/REGEN arrive via the environment) and prints PASS/FAIL/REGEN
# lines.  The parent spreads M-dirs over PARALLEL worker groups; each group
# runs its dirs serially into its own output file, so multi-line FAIL diffs
# never interleave.  Counts are tallied from the collected lines.
if [ "${1:-}" = "--dir" ]; then
    process_dir "$2"
    if [ "$fail" -gt 0 ]; then exit 1; fi
    exit 0
fi

RUN_NAMES="$*"
export RUN_NAMES REGEN
PARALLEL="${PARALLEL:-8}"

outroot=$(mktemp -d /tmp/fcc_run_sh.XXXXXX)
trap 'rm -rf "$outroot"' EXIT

w=0
for m_dir in "$HERE"/M*/; do
    [ -d "$m_dir" ] || continue
    echo "$m_dir" >> "$outroot/group$((w % PARALLEL)).list"
    w=$((w+1))
done

for g in "$outroot"/group*.list; do
    [ -f "$g" ] || continue
    (
        while IFS= read -r d; do
            "$0" --dir "$d"
        done < "$g"
    ) > "${g%.list}.out" 2>&1 &
done
wait

cat "$outroot"/group*.out 2>/dev/null
pass=$(cat "$outroot"/group*.out 2>/dev/null | grep -Ec '^(PASS|REGEN) ' || true)
fail=$(cat "$outroot"/group*.out 2>/dev/null | grep -Ec '^FAIL ' || true)

echo
echo "$pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
    printf 'Failures:'
    cat "$outroot"/group*.out | grep -E '^FAIL ' | awk '{printf " %s", $2}'
    echo
    exit 1
fi

# P3-3: static n,S-vs-depth gate (the load-bearing net for the hardware-stack
# conversion — the exit-code oracle waves a balanced-stack g_s_delta bias
# through; only this catches it).  Runs over the goldens just verified (or,
# under REGEN=1, just rewritten — a regen must never bless a bias).
echo
if ! python3 "$HERE/../tools/stack_check.py" --self-test >/dev/null; then
    echo "stack_check self-test FAILED" >&2
    exit 1
fi
if ! python3 "$HERE/../tools/stack_check.py" "$HERE"; then
    echo "stack_check FAILED" >&2
    exit 1
fi
# T5-C: libc_c.s and libfgx.s, the whole-library .s files, get the same
# static stack net (the batch-13 depth-ledger bug lived exactly here).
if ! python3 "$HERE/../tools/stack_check.py" "$HERE/../lib/libc_c.s"; then
    echo "stack_check FAILED on lib/libc_c.s" >&2
    exit 1
fi
if ! python3 "$HERE/../tools/stack_check.py" "$HERE/../lib/libfgx.s"; then
    echo "stack_check FAILED on lib/libfgx.s" >&2
    exit 1
fi
# Optional-tier libraries (multi-archive-linker P2): these whole-pile .s are the
# curses/termcap WHOLE-GRAPH STACK-CHECK AGGREGATES, not link piles.  Programs
# link libtermlib.so and libcurses.so, but the aggregate is stack-checked here
# because it walks the ENTIRE call graph in one unit -- per-member checks would
# miss cross-member recursion depth.  Do NOT delete these
# as "dead piles": libcurses.s has no linker consumer yet still guards curses
# stack-safety; libtermlib.s guards termcap, which vi and tcsh link
# dynamically as libtermlib.so.  Kept in sync with the
# archive members by the Makefile `archives` target.  See
# docs/history/plans/2026-07-19-pile-retirement-scoping.md (in the FGX repo).
if ! python3 "$HERE/../tools/stack_check.py" "$HERE/../lib/libtermlib.s"; then
    echo "stack_check FAILED on lib/libtermlib.s" >&2
    exit 1
fi
if ! python3 "$HERE/../tools/stack_check.py" "$HERE/../lib/libcurses.s"; then
    echo "stack_check FAILED on lib/libcurses.s" >&2
    exit 1
fi
exit 0
