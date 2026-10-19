#!/bin/bash
# ldload(8), statically linked against libc's library-mode compile
# (toolchain/src/ld/fgx_static.py): it runs before any shared library is
# resident, so it cannot itself be dynamic.
set -eu
cd "$(dirname "$0")"
REPO="$(cd ../.. && pwd)"
"$REPO/toolchain/fcc" --sigs "$REPO/build/libc.sigs" \
    --data-segment ldload.data.s -o ldload.s "$REPO/src/userland/ldload/ldload.c"
python3 "$REPO/toolchain/src/ld/fgx_static.py" --name ldload --dir ldload.ld \
    --code ldload.s --data ldload.data.s --out ldload.bin
