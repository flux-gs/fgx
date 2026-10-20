#!/usr/bin/env bash
#==============================================================================
# tz.sh -- the HOST-side steps of the time zone files.
#
#   tz.sh host        build build/tz_host/zic from vendor/tzcode-2026d
#   tz.sh zones ZONE  compile vendor/tzdata-2026d into
#                     disk_src/usr/share/zoneinfo, copy ZONE to
#                     disk_src/etc/localtime, check the limits
#
# zic.c needs two headers its Makefile generates, version.h and tzdir.h; they
# are written here with the values that Makefile would use for an FGX root.
# The host's own zic is not used, so the zone files depend on the tree and not
# on the machine that builds them.
#
# THE ZONE FILES ARE 1970-2038 AND "FAT".  -r @0/@2147483647 keeps the range a
# signed 32-bit time_t holds, which sizes libc's tables (tzfile.h's TZ_MAX_*;
# tools/check_tzlimits.py holds the two together).  -b fat keeps each file's
# version-1 block populated: libc's tzload is 4.3BSD-Reno's, and that block is
# the whole of what it reads.
#==============================================================================
set -eu
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
CODE=vendor/tzcode-2026d
OUT=build/tz_host

case "${1:-}" in
host)
    mkdir -p "$OUT"
    printf '#define PKGVERSION "(tzcode) "\n#define TZVERSION "%s"\n#define REPORT_BUGS_TO "tz@iana.org"\n' \
        "$(cat $CODE/version)" > "$OUT/version.h"
    printf '#define TZDEFAULT "/etc/localtime"\n#define TZDIR "/usr/share/zoneinfo"\n' \
        > "$OUT/tzdir.h"
    ${CC:-cc} -O2 -I"$OUT" -I"$CODE" -o "$OUT/zic" "$CODE/zic.c"
    ;;
zones)
    Z="${2:-UTC}"
    DST=disk_src/usr/share/zoneinfo
    D=vendor/tzdata-2026d
    # The wipe is the prune: a zone a newer tzdata drops does not survive.
    # The stamp goes first, so a run that fails after the wipe leaves ninja
    # nothing that says the tree is current.
    rm -f build/.zoneinfo_staged
    rm -rf "$DST"
    mkdir -p "$DST"
    # The Etc zones first and without -r: -r writes a "-00" placeholder
    # type ahead of each zone's own (zic(8)), and gmtime's gmtsub names its
    # zone with the GMT file's FIRST abbreviation (4.3BSD-Reno ctime.c).
    # These zones have no transitions, so -r has nothing to trim.  The rest
    # follow, and backward's links (UTC, Zulu, GMT0, ...) link to these.
    "$OUT/zic" -b fat -d "$DST" $D/etcetera
    "$OUT/zic" -b fat -r @0/@2147483647 -d "$DST" \
        $D/africa $D/antarctica $D/asia $D/australasia $D/europe \
        $D/northamerica $D/southamerica $D/backward
    # posixrules: the rules a POSIX TZ string without its own takes
    # (tzparse, TZDEFRULES).  US/Pacific, as 4.3BSD-Reno's
    # share/zoneinfo/Makefile installs it (POSIXRULES, lines 17 and 134);
    # this zic calls -p obsolete, which it is for tzcode's own localtime.
    "$OUT/zic" -b fat -r @0/@2147483647 -d "$DST" -p US/Pacific 2>/dev/null
    [ -f "$DST/posixrules" ] || { echo "tz.sh: no posixrules" >&2; exit 2; }
    [ -f "$DST/$Z" ] || { echo "tz.sh: FGX_TZ=$Z is not a zone" >&2; exit 2; }
    # A copy, not a link, so the time zone works before /usr does (2.11BSD
    # patch #469's advice for /etc/localtime).
    cp "$DST/$Z" disk_src/etc/localtime
    python3 tools/check_tzlimits.py "$DST"
    touch build/.zoneinfo_staged
    ;;
*)
    echo "usage: tz.sh host | tz.sh zones ZONE" >&2
    exit 2
    ;;
esac
