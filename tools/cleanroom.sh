#!/usr/bin/env bash
#==============================================================================
# cleanroom.sh -- build FGX from a FRESH CLONE, with no local state.
#
# The local gate runs in the developer's own environment: unsandboxed, with a licensed
# merlin32 and whatever else happens to be lying around.  It proves "it works
# here", NOT "it works from a clean checkout".  This is the only check that
# proves the second thing -- which is why the Linux CI job is load-bearing
# rather than vestigial.
#
# Since the vendored source moved from the gitignored examples/ into the
# committed vendor/, a clean clone can now build bsh, elvis and tcsh too --
# previously it could not, and that gap silently staged jsh as /bin/sh.
#
# It is a SCRIPT, not a CI-only capability, so it runs offline and can be run
# before pushing.  CI merely calls it.
#
# Usage: tools/cleanroom.sh [dest-dir]
#==============================================================================
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-${TMPDIR:-/tmp}/fgx-cleanroom.$$}"

fail=0
ok()  { printf '  \033[0;32mPASS\033[0m %s\n' "$1"; }
bad() { printf '  \033[0;31mFAIL\033[0m %s\n' "$1"; fail=$((fail+1)); }

echo "==> cleanroom: $SRC -> $DEST"
rm -rf "$DEST"

# Clone from the local path, NOT the network.  Since the monorepo merge there is
# no submodule, so this needs no second repository and no upstream at all --
# which is the property being tested.  (Before the merge this was impossible:
# .gitmodules used a relative URL, so a clone always had to reach a sibling
# fcc repo.)
if ! git clone -q "file://$SRC" "$DEST" 2>/dev/null; then
    bad "git clone failed"; exit 1
fi
ok "cloned with no --recurse-submodules"

cd "$DEST" || exit 1
[ -f .gitmodules ] && bad "a .gitmodules reappeared -- the clone is not self-contained" \
                   || ok "no .gitmodules (self-contained checkout)"
[ -f toolchain/Makefile ] && ok "toolchain present in-tree" \
                          || bad "toolchain/ missing"

if ! make -C toolchain fcc fas >/dev/null 2>&1; then
    bad "toolchain build failed"; exit 1
fi
ok "fcc + fas built from source"

if ! python3 tools/ninja/gen.py >/dev/null 2>&1; then
    bad "build.ninja generation failed"; exit 1
fi
ok "build.ninja generated"

if ! ninja all >"$DEST/build.log" 2>&1; then
    bad "ninja all failed"
    tail -20 "$DEST/build.log" | sed 's/^/      /'
    exit 1
fi
ok "ninja all"

[ -s bin/fgx.bin ] && ok "kernel built ($(wc -c < bin/fgx.bin | tr -d ' ') bytes)" \
                   || bad "bin/fgx.bin missing"
[ -s disk/fgxroot.fs ] && ok "disk image built" || bad "disk/fgxroot.fs missing"

# vendor/ is committed now, so a clean clone MUST be able to build the shells.
# Their absence used to be expected; it is now a failure.
n=$(ls bin/*.bin 2>/dev/null | wc -l | tr -d ' ')
echo "  $n userland binaries"
for sh_bin in bin/sh.bin bin/elvis.bin bin/tcsh.bin; do
    [ -s "$sh_bin" ] && ok "$(basename "$sh_bin") built from vendor/ source" \
                     || bad "$(basename "$sh_bin") MISSING -- vendor/ should make this buildable"
done

# `ninja release` is what CI ACTUALLY RUNS (.github/workflows/build.yml).  It is
# now the SAME target as the default build -- `release' names disk/fgxroot.fs,
# there being one image -- but it is still run here, because what CI runs and
# what this script proves buildable have to be the same command.  Two clean-tree
# bugs shipped straight past this script when they were not: verify_disk
# checking a hardcoded image `ninja release` never built, and make_floppy
# requiring the deleted jsh.
if ! ninja release >>"$DEST/build.log" 2>&1; then
    bad "ninja release failed (this is what CI runs)"
    tail -20 "$DEST/build.log" | sed 's/^/      /'
    exit 1
fi
ok "ninja release"
[ -s disk/fgxroot.fs ] && ok "release image built" || bad "disk/fgxroot.fs missing"
# PARKED 2026-09-06 -- `ninja release' no longer builds the 800K floppy, so a
# clean room has none to find.  Kept commented rather than deleted: if the image
# comes back for a specific purpose, this check comes back with it.  The reason
# it went is apple/fgx#340 -- the payload is 75,261 bytes over an 800K volume.
# [ -s disk/fgx-floppy.po ]  && ok "800K floppy built"   || bad "disk/fgx-floppy.po missing"

echo
if [ "$fail" -eq 0 ]; then
    echo "cleanroom: all checks passed  ($DEST)"
    exit 0
fi
echo "cleanroom: $fail check(s) FAILED  ($DEST)"
exit 1
