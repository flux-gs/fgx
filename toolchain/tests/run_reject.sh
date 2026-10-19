#!/bin/bash
#==============================================================================
# fcc NEGATIVE gate -- the programs fcc must REFUSE.
#
# WHY THIS EXISTS.  Every other fcc gate asserts what the compiler EMITS: the
# .expected.s goldens diff generated code, run_runtime.py checks what that code
# computes.  All of them require fcc to accept the input first.  So until this
# file, *every rejection fcc is supposed to make was unverified* -- a `die()`
# could be deleted, or silently stop being reachable, and the whole suite would
# stay green.  That is how apple/fgx#85 lived: `T.md.pre = 5`, where struct mid
# has no member `pre`, compiled to a store at the offset of a DIFFERENT member
# and cost twenty minutes of suspecting the compiler change under test.
#
# A `.c` fixture cannot assert a compile FAILURE -- it is only built if it
# compiles -- which is why this is a separate runner rather than another M-dir.
#
# FIXTURE FORMAT.  Every tests/reject/<name>.c starts with:
#
#     /* expect: <substring of the required diagnostic> */
#
# and may follow it with /* flags: <fcc flags> */ on line 2.
#
# The case passes only when fcc exits NON-ZERO *and* its stderr contains that
# substring.  Both halves matter: exit status alone would accept a crash or an
# unrelated parse error, and would have accepted "died for the wrong reason"
# right through a refactor that moved the check somewhere it no longer guards
# the case.
#
# THE RUNNER IS ITSELF TESTED.  `./run_reject.sh --self-test` feeds it two
# programs it MUST report as failures -- one fcc accepts, one fcc rejects with
# a different message -- because a negative harness that cannot go red is worth
# less than no harness: it reads as coverage of every rejection in the compiler
# while asserting nothing.  Run it before trusting a green result.
#
# Exits 0 on full success, 1 on any failure.
#==============================================================================

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
FCC="${FCC:-$HERE/../fcc}"
DIR="$HERE/reject"

if [ ! -x "$FCC" ]; then
    echo "fcc not built. Run: make -C $(dirname "$FCC")" >&2
    exit 2
fi

# Compile one .c and judge it. Prints a PASS/FAIL line; returns 0/1.
# $1 = path to the .c, $2 = display name.
check_one() {
    local src="$1" name="$2"
    local want err rc out

    want=$(sed -n '1s|.*/\* *expect: *\(.*[^ ]\) *\*/.*|\1|p' "$src")
    if [ -z "$want" ]; then
        echo "FAIL $name (no '/* expect: ... */' on line 1 -- a case with no"
        echo "     expected diagnostic passes on any error at all)"
        return 1
    fi

    # A REAL output path, not /dev/null: fcc derives its data-segment file from
    # -o, so `-o /dev/null` makes it die on "/dev/null.data.s: Operation not
    # permitted" -- non-zero exit for a reason that has nothing to do with the
    # case. Caught by the self-test, which is the only reason this comment
    # exists rather than a permanently green-for-the-wrong-reason gate.
    # An optional second line, /* flags: <fcc flags> */, compiles the case
    # with them (--libso's refusals need the library mode).  A plain string:
    # this runs under `set -u', where bash 3.2 calls an empty array unbound.
    local flags
    flags=$(sed -n '2s|.*/\* *flags: *\(.*[^ ]\) *\*/.*|\1|p' "$src")
    out=$(mktemp -d); err=$(mktemp); rc=0
    "$FCC" $flags "$src" -o "$out/out.s" >/dev/null 2>"$err" || rc=$?

    if [ "$rc" -eq 0 ]; then
        echo "FAIL $name (fcc ACCEPTED it; expected a diagnostic: $want)"
        rm -rf "$err" "$out"; return 1
    fi
    if ! grep -qF -- "$want" "$err"; then
        echo "FAIL $name (rejected, but for the wrong reason)"
        echo "     wanted: $want"
        sed 's/^/     got:    /' < "$err" | head -4
        rm -rf "$err" "$out"; return 1
    fi
    rm -rf "$err" "$out"
    echo "PASS $name"
    return 0
}

# --- self-test: the runner must FAIL these two, or it is not a gate ---------
if [ "${1:-}" = "--self-test" ]; then
    tmp=$(mktemp -d /tmp/fcc_reject_self.XXXXXX)
    trap 'rm -rf "$tmp"' EXIT
    rc=0

    # (a) a program fcc ACCEPTS, claiming it should be rejected.
    cat > "$tmp/accepts.c" <<'EOF'
/* expect: no such field */
struct s { int a; };
struct s S;
int f() { S.a = 1; return 0; }
EOF
    # (b) a program fcc rejects, but with a DIFFERENT diagnostic.
    cat > "$tmp/wrongmsg.c" <<'EOF'
/* expect: a diagnostic fcc never emits */
int f() { return nosuchvariable; }
EOF
    for t in accepts wrongmsg; do
        if check_one "$tmp/$t.c" "$t" >/dev/null 2>&1; then
            echo "SELFTEST FAIL: '$t' was reported as a PASS -- this runner" >&2
            echo "  cannot go red, so a green result from it means nothing" >&2
            rc=1
        fi
    done
    if [ "$rc" -eq 0 ]; then
        echo "run_reject selftest: OK (red on an accepted program, and on a"
        echo "  rejection carrying the wrong diagnostic)"
    fi
    exit "$rc"
fi

# --- main -------------------------------------------------------------------
pass=0; fail=0; failed=()
shopt -s nullglob
cases=("$DIR"/*.c)
if [ "${#cases[@]}" -eq 0 ]; then
    echo "no cases in $DIR -- an empty negative gate is green by vacuum" >&2
    exit 1
fi

for src in "${cases[@]}"; do
    name=$(basename "$src" .c)
    if [ $# -gt 0 ] && ! printf '%s\n' "$@" | grep -qx "$name"; then
        continue
    fi
    if check_one "$src" "$name"; then
        pass=$((pass+1))
    else
        fail=$((fail+1)); failed+=("$name")
    fi
done

echo "----"
echo "reject: $pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
    printf 'failed: %s\n' "${failed[*]}"
    exit 1
fi
exit 0
