#!/usr/bin/env bash
#==============================================================================
# yacc.sh -- the two HOST-side steps of a yacc-sourced FGX tool.
#
#   yacc.sh host          build tools/yacc/yacc  (2.11BSD yacc, host binary)
#   yacc.sh gen <name>    src/userland/<name>/<name>.y -> <name>.c
#
# The FGX2 compile/link of the generated .c is an ordinary tool build and stays
# in the ninja graph; only these two steps are peculiar enough to need a script.
#
# Extracted from lib/build_common.sh's build_host_yacc / build_userbin_yacc when
# the ninja graph took over.  build.sh DELETED the generated .c immediately after
# compiling it, which a build graph must not do -- ninja needs the output to
# persist so it can tell whether the edge is up to date.  It is gitignored, so
# only <name>.y is ever tracked.
#==============================================================================
set -eu
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

case "${1:-}" in
host)
    hostdir="build/yacc_host"
    srcdir="tools/yacc/src"
    skel="$ROOT/tools/yacc/yaccpar"
    [ -f "$skel" ] || { echo "yacc.sh: skeleton $skel missing" >&2; exit 2; }
    [ -f "$srcdir/y1.c" ] || { echo "yacc.sh: 2.11BSD yacc sources missing at $srcdir" >&2; exit 2; }
    mkdir -p "$hostdir"
    cp "$srcdir"/y1.c "$srcdir"/y2.c "$srcdir"/y3.c "$srcdir"/y4.c \
       "$srcdir"/dextern "$hostdir/"
    # PARSER is an ABSOLUTE path baked per checkout; the binary is gitignored.
    printf '#define PARSER "%s"\n#define MEDIUM\n' "$skel" > "$hostdir/files"
    # 2.11BSD yacc is K&R C.  Recent clang promotes several K&R patterns to hard
    # errors that -w does NOT suppress, so they must be downgraded by name -- but
    # those -W names do not exist on gcc, which rejects the flag outright.  Probe
    # each so the build stays compiler-portable (clang -> all, gcc -> none, where
    # -std=gnu89 -w already leaves K&R as warnings).
    krflags=""
    for f in -Wno-error=return-mismatch -Wno-error=int-conversion \
             -Wno-error=implicit-function-declaration -Wno-error=implicit-int; do
        if printf 'int main(void){return 0;}\n' \
           | cc "$f" -std=gnu89 -fsyntax-only -x c - 2>/dev/null; then
            krflags="$krflags $f"
        fi
    done
    # shellcheck disable=SC2086
    cc -std=gnu89 -w $krflags -o tools/yacc/yacc \
       "$hostdir"/y1.c "$hostdir"/y2.c "$hostdir"/y3.c "$hostdir"/y4.c
    ;;
gen)
    name="${2:?yacc.sh gen <name>}"
    d="src/userland/$name"
    [ -f "$d/$name.y" ] || { echo "yacc.sh: $d/$name.y does not exist" >&2; exit 2; }
    (
        cd "$d"
        "$ROOT/tools/yacc/yacc" "$name.y"
        # Strip fcc-incompatible '#line' and bare-'#' directives.  (A non-int
        # value stack is declared in the .y via a pointer typedef + a
        # single-token `#define YYSTYPE <typedef>`, which fcc handles directly --
        # no rewrite of generated code needed; see src/userland/expr/expr.y.)
        sed -E '/^# line /d; /^#[[:space:]]*$/d' y.tab.c > "$name.c"
        rm -f y.tab.c y.output
    )
    ;;
*)
    sed -n '3,12p' "$0" >&2
    exit 2
    ;;
esac
