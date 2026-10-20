#!/usr/bin/env bash
# mk_fgxa.sh — build a member-level FGX archive (.fgxa) for an optional
# library (multi-archive-linker P2, 2026-07-19).
#
# Compiles each member .c STANDALONE (its own TU) into the archive so the
# linker can dead-strip at member granularity: a tool pulls only the members
# its symbols transitively need (fgx_ar extract).  The shared libc/libfgx
# bank is untouched — this is only for the per-tool seg3 optional tier
# (termcap, curses, later libm/libutil), where member strip is a pure win
# and costs no sharing (seg3 was never shared).
#
# Usage:
#   mk_fgxa.sh <lib> <out.fgxa> <cc-and-flags> <public-file|-> <aggregate.c|-> <member.c...>
#
#   <lib>          library name (curses, termlib, …)
#   <out.fgxa>     output archive directory (e.g. lib/curses.fgxa)
#   <cc-and-flags> the fcc invocation prefix, e.g.
#                  "./fcc --pile-far-extern -DNOSCCS -Ilib/libcurses_c"
#   <public-file>  file of symbol names to always export (globals a tool may
#                  reference that no member does), or "-" for none
#   <aggregate.c>  the library umbrella .c (its #include "member.c" lines);
#                  recorded so `fgx_ar select` builds a filtered subset TU
#   <member.c...>  the member source files
#
# Emits <out.fgxa>/{index.json, <stem>.s, <stem>.data.s ...}.  The member .s /
# .data.s are the archive members build_common PUTs into seg3 / seg1 after
# extraction; index.json is the ranlib-analogue symbol table.
set -euo pipefail

lib="$1"; out="$2"; cc="$3"; public="$4"; aggregate="$5"; shift 5
here="$(cd "$(dirname "$0")/.." && pwd)"   # toolchain root

rm -rf "$out"; mkdir -p "$out"
spaths=()
for src in "$@"; do
    stem="$(basename "${src%.c}")"
    # Each member is its own TU -> matching .s / .data.s label sets.
    # $cc is a multi-word command prefix; intentional word-split.
    # shellcheck disable=SC2086
    $cc "$src" -o "$out/$stem.s" --data-segment "$out/$stem.data.s" \
        >/dev/null 2>"$out/$stem.err" || {
            echo "mk_fgxa: $lib member '$src' failed to compile:" >&2
            grep -iE "error|fatal|panic" "$out/$stem.err" | head -3 >&2
            exit 2; }
    [[ -s "$out/$stem.s" ]] || { echo "mk_fgxa: $lib member '$src' produced no .s" >&2; exit 2; }
    rm -f "$out/$stem.err"
    spaths+=("$out/$stem.s")
done

pub_arg=()
[[ "$public" != "-" ]] && pub_arg=(--public "$public")
agg_arg=()
[[ "$aggregate" != "-" ]] && agg_arg=(--aggregate "$aggregate")
# ${arr[@]+...} guards the empty-array expansion under `set -u` on bash 3.2.
python3 "$here/src/ld/fgx_ar.py" -v index --lib "$lib" --out "$out" \
    --cc "$cc" ${agg_arg[@]+"${agg_arg[@]}"} ${pub_arg[@]+"${pub_arg[@]}"} "${spaths[@]}"
