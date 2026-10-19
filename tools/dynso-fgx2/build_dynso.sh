#!/bin/bash
# The shared libc machine probes: a program linked dynamically
# (toolchain/src/ld/fgx_dyn.py).  $1 names the binary.  Bound on the host
# (toolchain/src/ld/fgx_bind.py): dynso, cursso (libcurses, libtermlib,
# libc) and dyntruebound.  Unbound, for the machine's binder: dynsodyn
# (dynso with its shared-library checks), dynsomisdyn (the same linked
# against a libc.so whose core is two bytes larger, so its CRC and every
# data address differ and the machine binds it by name), dyntrue (true(1)),
# curssodyn (cursso), and fitover and fitunder (fitso, its data 50 and 150
# bytes under the link-time limit).
# The bind's trace is kept beside the binary.
set -eu
cd "$(dirname "$0")"
REPO="$(cd ../.. && pwd)"
LD="$REPO/toolchain/src/ld"
name="$1"
case "$name" in
  dynso) src=dynso/dynso.c; libs=libc ;;
  dynsodyn) src=dynso/dynso.c; libs=libc; def=-DDSO_SHARED ;;
  dynsomisdyn)
    rm -rf mis
    mkdir -p mis
    python3 "$LD/fgx_libso.py" --core-pad 2 --out mis/libc.so.1.0 --dir mis/ld
    src=dynso/dynso.c; libs=libc; def=-DDSO_SHARED; so="--so libc=mis/libc.so.1.0" ;;
  dyntrue|dyntruebound) src=dyntrue/dyntrue.c; libs=libc ;;
  cursso|curssodyn) src=cursso/cursso.c; libs=libcurses ;;
  fitover|fitunder) src=fitso/fitso.c; libs=libtermlib ;;
  dynmulti) src=dynmulti/dynmulti.c; libs=libc ;;
  dyntabseg) src=dyntabseg/dyntabseg.c; libs=libc ;;
  dynrebind) src=dynrebind/dynrebind.c; libs=libc ;;
  *) echo "build_dynso.sh: dynso, cursso, dynsodyn, dynsomisdyn, dyntrue, dyntruebound, curssodyn, fitover, fitunder, dynmulti, dyntabseg or dynrebind" >&2; exit 2 ;;
esac
# dynmulti spans three code segments (fgx_dyn --code-seg); dyntabseg's one
# code segment is filled until the binder's tables need a segment of their
# own (shared libc SP5 spec 4.1).  Both are bound on the machine.
case "$name" in
  dynmulti)
    for f in dynmulti dynmulti2 dynmulti3; do
        "$REPO/toolchain/fcc" --sigs "$REPO/build/libc.sigs" \
            --data-segment "$f.data.s" -o "$f.s" "$REPO/src/userland/dynmulti/$f.c"
    done
    python3 "$LD/fgx_dyn.py" --name dynmulti --dir dynmulti.ld --code dynmulti.s \
        --code-seg dynmulti2.s --code-seg dynmulti3.s \
        --data dynmulti.data.s,dynmulti2.data.s,dynmulti3.data.s --lib libc \
        --out dynmulti.dyn || exit 1
    cp dynmulti.dyn dynmulti.bin; exit 0 ;;
  dyntabseg)
    "$REPO/toolchain/fcc" --sigs "$REPO/build/libc.sigs" \
        --data-segment dyntabseg.data.s -o dyntabseg.s "$REPO/src/userland/dyntabseg/dyntabseg.c"
    pad() { sed "s/PADSIZE/$1/" "$REPO/src/userland/dyntabseg/pad.s" > pad.s; }
    pad 1
    rep=$(python3 "$LD/fgx_dyn.py" --name dyntabseg --dir dyntabseg.ld \
        --code dyntabseg.s,pad.s --data dyntabseg.data.s --lib libc --out dyntabseg.dyn) || exit 1
    s0=$(echo "$rep" | sed -n 's/.*seg0 \([0-9]*\) bytes.*/\1/p')
    [ -n "$s0" ] || { echo "build_dynso.sh: $rep" >&2; exit 2; }
    pad $((65535 - s0 - 64))            # leaves 64 bytes: too few for the tables
    python3 "$LD/fgx_dyn.py" --name dyntabseg --dir dyntabseg.ld \
        --code dyntabseg.s,pad.s --data dyntabseg.data.s --lib libc --out dyntabseg.dyn || exit 1
    cp dyntabseg.dyn dyntabseg.bin; exit 0 ;;
esac
# fitso's two arrays take all but `margin' bytes of the room fgx_dyn reports
# for a link at one byte each: its summary names the data's size and LIM.
fitlink() {
    "$REPO/toolchain/fcc" --sigs "$REPO/build/libc.sigs" $1 \
        --data-segment "$name.data.s" -o "$name.s" "$REPO/src/userland/$src"
    python3 "$LD/fgx_dyn.py" --name "$name" --dir "$name.ld" --code "$name.s" \
        --data "$name.data.s" --lib "$libs" --out "$name.dyn"
}
case "$name" in
  fitover|fitunder)
    margin=150
    [ "$name" = fitover ] && margin=50
    rep=$(fitlink "-DPAD1=1 -DPAD2=1") || exit 1
    end=$(echo "$rep" | sed -n 's/.* data \([0-9]*\) bytes.*/\1/p')
    lim=$(echo "$rep" | sed -n 's/.*LIM \$\([0-9A-F]*\)$/\1/p')
    [ -n "$end" ] && [ -n "$lim" ] || { echo "build_dynso.sh: $rep" >&2; exit 2; }
    gap=$((0x$lim - end - margin))
    def="-DPAD1=$((1 + gap / 2)) -DPAD2=$((1 + gap - gap / 2))" ;;
esac
"$REPO/toolchain/fcc" --sigs "$REPO/build/libc.sigs" ${def:-} \
    --data-segment "$name.data.s" -o "$name.s" "$REPO/src/userland/$src"
rep=$(python3 "$LD/fgx_dyn.py" --name "$name" --dir "$name.ld" --code "$name.s" \
    --data "$name.data.s" --lib "$libs" --out "$name.dyn" ${so:-}) || exit 1
echo "$rep"
case "$name" in
  fitover|fitunder)                     # the margin, from the image's own report
    end=$(echo "$rep" | sed -n 's/.* data \([0-9]*\) bytes.*/\1/p')
    [ $((0x$lim - end)) -eq $margin ] || {
        echo "build_dynso.sh: $name's data ends $end, not $margin under \$$lim" >&2; exit 2; } ;;
esac
# Bound on the machine (shared libc SP4): the dynamic image is the binary.
case "$name" in
  dynsodyn|dynsomisdyn|dyntrue|curssodyn|fitover|fitunder|dynrebind)
    cp "$name.dyn" "$name.bin"; exit 0 ;;
esac
python3 "$LD/fgx_bind.py" --prog "$name.dyn" --out "$name.bin" --trace > "$name.trace"
grep -q "prebound" "$name.trace" && ! grep -q "by name" "$name.trace"
