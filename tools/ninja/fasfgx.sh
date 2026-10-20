#!/usr/bin/env bash
#==============================================================================
# fasfgx.sh -- build fas (the assembler) to RUN ON FGX.  -> tools/fas/fas_fgx
#
# A dynamic program: fcc compiles fas.c against libc.so's signatures and
# fgx_dyn links it against libc.so and libfgx.so (dropping libfgx if fas does
# not reference it).  Every stage is fatal.
#==============================================================================
set -eu
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT/tools/fas"

rm -f fas_fgx fas_fgx.s fas_fgx.data.s

"$ROOT/toolchain/fcc" --sigs "$ROOT/build/libc.sigs" \
    --data-segment fas_fgx.data.s -o fas_fgx.s "$ROOT/toolchain/src/as/fas.c"

python3 "$ROOT/toolchain/src/ld/fgx_dyn.py" --name fas --dir dyn.ld \
        --code fas_fgx.s --data fas_fgx.data.s --lib libc,libfgx --out fas_fgx

[ -s fas_fgx ] || { echo "fasfgx.sh: link produced no fas_fgx" >&2; exit 3; }
