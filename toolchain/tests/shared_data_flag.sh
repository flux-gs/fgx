#!/bin/sh
# --shared-data: code banks over one data bank, so an indirect call reads the
# target's bank from the pointer and leaves DBR on the data bank.  --module-bank,
# the control, moves DBR to the callee and restores it afterwards.
cd "$(dirname "$0")" || exit 1
FCC=../fcc
T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT
cat > "$T/t.c" <<'SRC'
int (*fp)();
int f(a) int a; { return (*fp)(a); }
SRC
fail=0
sec() { # count of $1 in function f's code of file $2
    grep -c -E "^ +$1( |\$)" "$2"
}
$FCC -fno-safepoints --pile --module-bank -o "$T/m.s" "$T/t.c" || fail=1
$FCC -fno-safepoints --pile --shared-data -o "$T/s.s" "$T/t.c" || fail=1
[ "$(sec PLB "$T/m.s")" -ge 2 ] || { echo "control: --module-bank lost its PLBs"; fail=1; }
[ "$(sec PLB "$T/s.s")" -eq 0 ] || { echo "--shared-data moved DBR"; fail=1; }
[ "$(sec RTL "$T/s.s")" -ge 2 ] || { echo "--shared-data lost the far call"; fail=1; }
grep -q 'LDA .*+2' "$T/s.s" || { echo "--shared-data does not read the bank from the pointer"; fail=1; }
# A pointer initializer in a module has no linker to patch it: its cell is one
# the image stamps with its own bank at init, like a function's.
cat > "$T/d.c" <<'SRC'
int g = 7; int arr[3]; char *p = "lit"; int *q = &g;
struct s { int a; int *b; } sv = { 1, &arr[1] };
SRC
for mode in --module-bank --shared-data; do
    $FCC -fno-safepoints --pile $mode -o "$T/d.s" "$T/d.c" || fail=1
    if grep -q -E 'FGX2_LONG_PTR|LIBC_DATA_PTR' "$T/d.data.s"; then
        echo "$mode: a pointer initializer has no stamped cell"; fail=1
    fi
    [ "$(grep -c MOD_FN_PTR "$T/d.data.s")" -eq 3 ] || { echo "$mode: expected 3 stamped cells"; fail=1; }
    grep -q 'MOD_FN_PTR.*arr+2' "$T/d.data.s" || { echo "$mode: lost the +2"; fail=1; }
done
[ "$fail" = 0 ] && echo "shared_data_flag: ok"
exit $fail
