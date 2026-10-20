#!/bin/bash
#==============================================================================
# fcc Track 1 size/speed metrics.  Deterministic, emulator-free.
#   tests/metrics.sh snapshot <label>           # -> /tmp/fcc_metrics_<label>.tsv
#   tests/metrics.sh compare  <baseTsv> <curTsv># -> before/after delta table
#==============================================================================
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)

snapshot() {
    label="$1"
    out="/tmp/fcc_metrics_${label}.tsv"
    : > "$out"
    tbytes=0; tlines=0; count=0
    while IFS= read -r bin; do
        s_file="${bin%.expected.bin}.expected.s"
        sz=$(wc -c < "$bin" | tr -d ' ')
        ln=0
        [ -f "$s_file" ] && ln=$(grep -cvE '^[[:space:]]*(;|\*|$)' "$s_file")
        printf '%s\t%s\t%s\n' "${bin#"$ROOT"/}" "$sz" "$ln" >> "$out"
        tbytes=$((tbytes + sz)); tlines=$((tlines + ln)); count=$((count + 1))
    done < <(find "$ROOT/tests" -name '*.expected.bin' | sort)
    printf '#TOTAL_BYTES\t%s\n#TOTAL_LINES\t%s\n#COUNT\t%s\n' \
        "$tbytes" "$tlines" "$count" >> "$out"
    echo "snapshot '$label': $count fixtures, $tbytes bytes, $tlines asm lines -> $out"
}

compare() {
    base="$1"; cur="$2"
    : > /tmp/fcc_metrics_delta.tsv
    awk -F'\t' '
        FNR==NR {
            if      ($1=="#TOTAL_BYTES") bb=$2;
            else if ($1=="#TOTAL_LINES") bl=$2;
            else if ($1=="#COUNT")       bc=$2;
            else                         b[$1]=$2;
            next
        }
        {
            if      ($1=="#TOTAL_BYTES") cb=$2;
            else if ($1=="#TOTAL_LINES") cl=$2;
            else if ($1=="#COUNT")       cc=$2;
            else { d=$2-b[$1]; if (d!=0) printf "%d\t%s\t%d -> %d\n", d, $1, b[$1], $2 >> "/tmp/fcc_metrics_delta.tsv" }
        }
        END {
            db=cb-bb; pb=(bb>0)?(db*100.0/bb):0;
            dl=cl-bl; pl=(bl>0)?(dl*100.0/bl):0;
            printf "fixtures:  %d -> %d\n", bc, cc;
            printf "bytes:     %d -> %d   (delta %d, %.2f%%)\n", bb, cb, db, pb;
            printf "asm lines: %d -> %d   (delta %d, %.2f%%)\n", bl, cl, dl, pl;
        }
    ' "$base" "$cur"
    echo "--- top 20 per-fixture byte shrinks (saved : fixture : before -> after) ---"
    sort -n /tmp/fcc_metrics_delta.tsv | head -20
}

cmd="${1:-}"; shift || true
case "$cmd" in
    snapshot) snapshot "$@" ;;
    compare)  compare  "$@" ;;
    *) echo "usage: tests/metrics.sh {snapshot <label> | compare <base.tsv> <cur.tsv>}" >&2; exit 2 ;;
esac
