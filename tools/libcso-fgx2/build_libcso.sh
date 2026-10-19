#!/bin/bash
# libcso: shared libc SP2's machine probe, statically linked against libc's
# library-mode compile (toolchain/src/ld/fgx_static.py).  $1 names the
# binary: libcso (libc's reached code capped at 8 KB a bank, so it spans
# several code banks), libcsofull (its heap room squeezed below its
# blocks' size, so _lib_init must refuse before main), or bytecatso
# (src/userland/bytecat, the byte loop timed against bytecat).
set -eu
cd "$(dirname "$0")"
REPO="$(cd ../.. && pwd)"
name="$1"
case "$name" in
  libcso) src=libcso/libcso.c; extra="--libc-bank-cap 8192" ;;
  libcsofull) src=libcso/libcso.c; extra="--squeeze" ;;
  bytecatso) src=bytecat/bytecat.c; extra="" ;;
  *) echo "build_libcso.sh: libcso, libcsofull or bytecatso" >&2; exit 2 ;;
esac
"$REPO/toolchain/fcc" --sigs "$REPO/build/libc.sigs" \
    --data-segment "$name.data.s" -o "$name.s" "$REPO/src/userland/$src"
python3 "$REPO/toolchain/src/ld/fgx_static.py" --name "$name" --dir "$name.ld" \
    --code "$name.s" --data "$name.data.s" --out "$name.bin" $extra
if [ "$name" = libcso ]; then
    python3 -c "import json,sys; n=len(json.load(open('$name.ld/static.json'))['segments'])-2; sys.exit(0 if n >= 2 else 'libcso: libc spans %d bank(s), the probe needs 2' % n)"
fi
