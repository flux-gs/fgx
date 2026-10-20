#!/bin/bash
# fas test harness — byte-eq vs .expected.bin goldens (Merlin32 oracle).
# Mirrors tools/fcc/tests/run.sh.
set -e
cd "$(dirname "$0")"

cc -O -Wall -o ../fas ../fas.c

fail=0
pass=0
failed=()
for s in M*/*.s; do
    [ -e "$s" ] || continue
    name="${s%.s}"
    # Skip Merlin32 link wrappers (used only to generate goldens).
    case "$name" in *.link) continue ;; esac
    if ../fas "$s" -o "$name.actual.bin" 2>"$name.actual.err"; then
        if cmp -s "$name.actual.bin" "$name.expected.bin"; then
            rm -f "$name.actual.bin" "$name.actual.err"
            pass=$((pass + 1))
        else
            fail=$((fail + 1))
            failed+=("$name")
        fi
    else
        fail=$((fail + 1))
        failed+=("$name (assembly error)")
    fi
done

# fcc corpus sweep (M10): each fcc fixture's .expected.s is renamed
# fcc_output.s (as the link wrapper expects), fas assembles via the
# .link.s, and the output is compared to the Merlin-built golden.
if [ "${FAS_FCC_SWEEP:-1}" = "1" ] && [ -d ../../fcc/tests ]; then
    fcc_pass=0
    fcc_fail=0
    fcc_failed=()
    for c in ../../fcc/tests/M*/*.c; do
        [ -f "$c" ] || continue
        cname=$(basename "$c" .c)
        cdir=$(dirname "$c")
        expected_s="$cdir/$cname.expected.s"
        link_s="$cdir/$cname.link.s"
        expected_bin="$cdir/$cname.expected.bin"
        [ -f "$expected_s" ] || continue
        [ -f "$link_s" ] || continue
        [ -f "$expected_bin" ] || continue
        cp "$expected_s" "$cdir/fcc_output.s"
        if ../fas "$link_s" -o "$cdir/$cname.actual.bin" 2>"$cdir/$cname.actual.err"; then
            if cmp -s "$cdir/$cname.actual.bin" "$expected_bin"; then
                rm -f "$cdir/$cname.actual.bin" "$cdir/$cname.actual.err"
                fcc_pass=$((fcc_pass + 1))
            else
                fcc_fail=$((fcc_fail + 1))
                fcc_failed+=("fcc/$cname")
            fi
        else
            fcc_fail=$((fcc_fail + 1))
            fcc_failed+=("fcc/$cname (assembly error)")
        fi
        rm -f "$cdir/fcc_output.s"
    done
    echo "$pass passed, $fail failed (fas own); $fcc_pass passed, $fcc_fail failed (fcc sweep)"
    if [ $fail -gt 0 ] || [ $fcc_fail -gt 0 ]; then
        echo "Failures:"
        for f in "${failed[@]}";     do echo "  $f"; done
        for f in "${fcc_failed[@]}"; do echo "  $f"; done
        exit 1
    fi
    exit 0
fi

echo "$pass passed, $fail failed"
if [ $fail -gt 0 ]; then
    echo "Failures:"
    for f in "${failed[@]}"; do echo "  $f"; done
    exit 1
fi
