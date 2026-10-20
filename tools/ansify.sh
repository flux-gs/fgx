#!/usr/bin/env bash
# SPDX-License-Identifier: BSD-2-Clause
# SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
#
# ansify.sh -- mechanically ANSI-fy a K&R C source (a 2.11BSD port input) with
# cproto, and validate the result against the host clang reference.
#
# Why this exists
# ---------------
# 2.11BSD sources are K&R C (its compiler was PCC).  fcc + our ports go more
# smoothly with ANSI prototypes: explicit parameter types at every call site
# kill the fn-ptr empty-`()` arg-width bug class (a real fcc footgun).  cproto
# automates the two things we were otherwise hand-writing per tool (see od.c):
#   1. the forward-prototype block, and
#   2. the K&R -> ANSI rewrite of the function *definitions*.
#
# What it does NOT do: cproto does not touch the constructs that actually cost
# fcc time -- implicit-int locals (`register c;`), bare `return;` in an int
# function, varargs, the regex/pointer machines.  Those stay manual; this just
# removes the mechanical transcription.  Treat the output as a *starting point*
# to feed to fcc, not a finished port.
#
# Usage
# -----
#   tools/ansify.sh INPUT.c [OUTPUT.c]   ANSI-fy -> OUTPUT.c (default: INPUT.ansi.c),
#                                        then syntax-check it with the clang oracle.
#   tools/ansify.sh --check FILE.c       only run the clang reference build (no rewrite).
#
# Requires: cproto (`brew install cproto`), clang.

set -euo pipefail

# ---------------------------------------------------------------------------
# The clang "oracle" flag set.  Modern clang promotes several legacy K&R-isms
# to HARD ERRORS -- bare `return;` in a non-void function, implicit int,
# implicit function declarations, int<->pointer conversions.  2.11BSD source
# trips all of these, so the reference build must downgrade them to warnings.
# Reuse this set whenever you build a BSD original as the behaviour oracle.
# ---------------------------------------------------------------------------
CLANG_KR_FLAGS=(
    -std=gnu89 -w
    -Wno-error=return-mismatch
    -Wno-error=implicit-int
    -Wno-error=implicit-function-declaration
    -Wno-error=int-conversion
    -Wno-error=return-type
)

die() { printf 'ansify: %s\n' "$*" >&2; exit 2; }

need() {
    command -v "$1" >/dev/null 2>&1 || die "$1 not found${2:+ ($2)}"
}

clang_check() {
    # Syntax/type-check only (no link): "does the clang oracle accept it?"
    local f="$1"
    need clang
    if clang "${CLANG_KR_FLAGS[@]}" -fsyntax-only "$f" 2>/tmp/ansify_clang.$$; then
        echo "  clang oracle: OK ($f parses + type-checks)"
        rm -f /tmp/ansify_clang.$$
        return 0
    else
        echo "  clang oracle: REJECTED -- remaining issues:" >&2
        sed 's/^/    /' /tmp/ansify_clang.$$ >&2 | head -40 || true
        rm -f /tmp/ansify_clang.$$
        return 1
    fi
}

ansify() {
    local in="$1" out="$2"
    need cproto "brew install cproto"
    [ -f "$in" ] || die "input not found: $in"
    [ "$in" = "$out" ] && die "refusing to overwrite the input in place; pick a different OUTPUT"

    cp "$in" "$out"

    # 1. Rewrite K&R function definitions to ANSI, in place in OUTPUT.
    #    -E 0 disables cproto's preprocessor so it never tries to read (and
    #    choke on) the system headers; the K&R parameter decls it needs are
    #    inline in the source anyway.  cproto edits the file in place and prints
    #    the prototype list to stdout (which we discard here).
    cproto -a -E 0 "$out" >/dev/null 2>/dev/null || true

    # 2. Generate the forward-prototype block from the (now ANSI) definitions
    #    and splice it in after the last top-of-file #include.  Forward decls
    #    for already-defined-first functions are harmless (identical redecl).
    local protos; protos="$(cproto -E 0 "$out" 2>/dev/null | grep -E '^[A-Za-z].*\);$' || true)"
    local last_inc; last_inc="$(grep -nE '^[[:space:]]*#[[:space:]]*include' "$out" | tail -1 | cut -d: -f1)"
    if [ -n "$protos" ] && [ -n "$last_inc" ]; then
        {
            head -n "$last_inc" "$out"
            printf '\n/* ANSI forward prototypes (tools/ansify.sh via cproto) */\n'
            printf '%s\n' "$protos"
            tail -n +"$((last_inc + 1))" "$out"
        } > "$out.tmp" && mv "$out.tmp" "$out"
    fi

    echo "ansify: $in -> $out"
    echo "  cproto: converted definitions to ANSI + inserted forward prototypes"
    clang_check "$out" || echo "  (note: clang issues above are the manual fcc-porting surface cproto can't fix)"
    echo "  next: feed $out to fcc; expect to hand-fix implicit-int / bare-return / varargs as needed"
}

# ---- arg parsing ----------------------------------------------------------
case "${1:-}" in
    ""|-h|--help)
        sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    --check)
        [ $# -ge 2 ] || die "usage: ansify.sh --check FILE.c"
        clang_check "$2"
        ;;
    *)
        IN="$1"
        OUT="${2:-${IN%.c}.ansi.c}"
        ansify "$IN" "$OUT"
        ;;
esac
