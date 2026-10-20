#!/bin/bash
#==============================================================================
# gen_softscc.sh - regenerate the committed soft-frame member lists.
#
# Bank-0 stack campaign 1.3.  A function in a recursion cycle gets its locals
# in the task's DATA bank instead of the 65816's bank-0 hardware stack, which
# is what turns bsh's ~121 bytes per sourced command into ~19.  WHICH functions
# recurse is a whole-program fact, so it is computed from the built assembly by
# `stack_measure.py --emit-scc` -- the same call graph the stack model walks, so
# the two cannot disagree about what a cycle is.
#
# THE FILES ARE COMMITTED SOURCE, NOT BUILD PRODUCTS.  fcc reads one at COMPILE
# time; the graph is only knowable at LINK time.  Regenerating into the same
# build that consumes it is the build-writes-its-own-inputs trap (three
# instances in one day on 2026-07-28), and it always looks like the dependency
# graph merely being conservative.  So: run this by hand, read the diff, commit
# it.  The generator is deterministic -- running it twice must produce
# byte-identical files, and `ninja -n` must then report no work to do.
#
# OPT-IN IS THE FILE'S EXISTENCE.  tools/ninja/gen.py wires FCC_SOFT_SCC for a
# binary iff src/softscc/<binary>.txt exists, so there is exactly one list.  To
# opt a binary in, generate its file; to opt out, delete it.
#
# WHY NOT EVERY BINARY.  Each converted access costs +3 code bytes and each
# soft function ~+26 (prologue guard + epilogue release), and a code segment is
# a hard 64 KB.  Measured 2026-08-02: tcsh needs ~19,023 B and has ~3,998 B free
# across seg0-seg6, so it stays hard-stack until it has an eighth code bank.
# bsh needs ~5,819 B against 9,096 B free, and bsh is the binary that actually
# fails (issue #9).  Check before adding one:  tools/stack_exile_cost.py
#
# Usage:  tools/gen_softscc.sh              regenerate every existing list
#         tools/gen_softscc.sh sh elvis     regenerate (or create) these
#==============================================================================
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/src/softscc"
MEASURE="$ROOT/toolchain/src/ld/stack_measure.py"

mkdir -p "$OUT"

names=("$@")
if [ ${#names[@]} -eq 0 ]; then
    for f in "$OUT"/*.txt; do
        [ -e "$f" ] || continue
        names+=("$(basename "$f" .txt)")
    done
fi
if [ ${#names[@]} -eq 0 ]; then
    echo "no lists to regenerate and none named; see --help in the header" >&2
    exit 1
fi

rc=0
for b in "${names[@]}"; do
    d="$ROOT/tools/$b-fgx2"
    # A missing build dir must FAIL, not silently write an empty list: an empty
    # FCC_SOFT_SCC means "nothing is soft", so a botched run would quietly
    # revert the binary to hard frames and every test would still pass.
    if [ ! -d "$d" ]; then
        echo "!! $b: no $d -- build first (ninja)" >&2
        rc=1
        continue
    fi
    ss=()
    for f in "$d"/*.s; do
        case "$f" in *.link.s|*.data.s) continue ;; esac
        [ -e "$f" ] && ss+=("$f")
    done
    if [ ${#ss[@]} -eq 0 ]; then
        echo "!! $b: no compiler output in $d -- build first (ninja)" >&2
        rc=1
        continue
    fi
    tmp="$OUT/.$b.txt.new"
    if ! python3 "$MEASURE" --emit-scc "${ss[@]}" > "$tmp"; then
        echo "!! $b: stack_measure --emit-scc failed" >&2
        rm -f "$tmp"
        rc=1
        continue
    fi
    n=$(grep -vc '^#' "$tmp")
    if [ "$n" -eq 0 ]; then
        echo "   $b: no recursion cycles -- removing (nothing to exile)"
        rm -f "$tmp" "$OUT/$b.txt"
        continue
    fi
    if [ -f "$OUT/$b.txt" ] && cmp -s "$tmp" "$OUT/$b.txt"; then
        echo "   $b: $n members (unchanged)"
        rm -f "$tmp"
    else
        mv "$tmp" "$OUT/$b.txt"
        echo "   $b: $n members -> src/softscc/$b.txt (CHANGED -- read the diff)"
    fi
done
exit $rc
