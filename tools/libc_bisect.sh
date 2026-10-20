#!/bin/bash
# libc_bisect.sh "sig1|sig2|..." -- bisect the libc pile SAFELY.
#
# Every guard here exists because its absence produced a WRONG answer on
# 2026-07-26.  Read docs/history/RESUME-2026-07-26-*.md before editing.
#
#   1. lib/libc_c.s is CHECKED IN and only rebuilt by `make libc_c`; plain `make`
#      leaves it alone, so an edit to libc_c.c silently tests the OLD pile.  We
#      run the right target and then ASSERT that at least one of the two
#      generated files actually changed -- a code-only change moves libc_c.s, a
#      data-only change moves ONLY libc_c_data.s, so checking just one is a trap.
#   2. bsh and elvis are cached by mtime against a fixed input list.  A binary
#      linked against a transient pile survives and poisons every later run while
#      looking up to date, so we DELETE them and force a relink.
#   3. The verdict is the smoke test (the failsafe group was deleted with the
#      rest of the suite on 2026-07-29).  NOTE: this is a weaker verdict than
#      the group gave -- see the caveat below.  sbrktest passed under
#      breakage that kills thirteen other tests.
set -u
cd "$(dirname "$0")/.."
REPO=$PWD
WIP=docs/history/wip-2026-07-26
TRAIN=$WIP/train.c
FNS=$WIP/fns.json

[ -f "$TRAIN" ] || { echo "missing $TRAIN"; exit 2; }

# The train's libc_c.c needs the train's HEADERS too (pwd.h supplies the 2.11BSD
# struct passwd and _PATH_PASSWD; sys/dir.h the rewinddir decl).  Apply them if
# they are not already in place, or the pile fails to compile and the guard below
# correctly refuses to run -- which is a confusing way to discover a missing
# header.
if ! grep -q _PATH_PASSWD toolchain/include/pwd.h 2>/dev/null; then
    (cd toolchain && git apply --include='include/pwd.h' --include='include/sys/dir.h' \
        "../$WIP/tc-wip2.patch") || { echo "header apply FAILED"; exit 2; }
    echo "applied the train headers (pwd.h, sys/dir.h)"
fi

python3 - "${1:-}" <<'PY'
import sys, json, pathlib
drop = [s for s in sys.argv[1].split("|") if s]
fns  = json.load(open("docs/history/wip-2026-07-26/fns.json"))
t    = open("docs/history/wip-2026-07-26/train.c").read()
for d in drop:
    body = fns.get(d)
    if body is None: sys.exit("unknown signature: %s" % d)
    if body not in t: sys.exit("already absent: %s" % d)
    t = t.replace(body, "", 1)
pathlib.Path("toolchain/lib/libc_c/libc_c.c").write_text(t)
print("libc_c.c = train minus %d function(s)" % len(drop))
PY
[ $? -eq 0 ] || exit 2

cd toolchain
before_code=$(shasum lib/libc_c.s      | cut -d' ' -f1)
before_data=$(shasum lib/libc_c_data.s | cut -d' ' -f1)
make libc_c 2>&1 | grep -iE "^lib.*error|\*\*\*" && { echo "PILE REGEN FAILED"; exit 3; }
after_code=$(shasum lib/libc_c.s      | cut -d' ' -f1)
after_data=$(shasum lib/libc_c_data.s | cut -d' ' -f1)
if [ "$before_code" = "$after_code" ] && [ "$before_data" = "$after_data" ]; then
    echo "GUARD: neither libc_c.s nor libc_c_data.s changed -- the pile did not"
    echo "       regenerate, so this run would test the PREVIOUS pile.  Aborting."
    exit 4
fi
cd "$REPO"

# Force bsh + elvis to relink against THIS pile (guard 2).
rm -f bin/sh.bin bin/elvis.bin

./build.sh disk 2>&1 | grep -iE "^.{0,12}Error" && { echo "DISK BUILD FAILED"; exit 5; }
python3 tools/mame_test/run.py --headless --no-state --fresh smoke 2>&1 | tail -2
