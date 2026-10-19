#!/bin/bash
# mod2ntp.sh — convert a ProTracker .mod to NinjaTracker+ .ntp using the
# upstream PHP converter. Host-side step of the FGX MOD player pipeline.
#
# Usage: tools/mod2ntp.sh <input.mod> [output_dir] [STREAM_ALLOW|STREAM_FORBIDDEN|STREAM_ENFORCE]
#
# Supported input: ProTracker M.K., 1CHN..9CHN, FLT4/FLT8. NOT Oktalyzer
# (OKTASONG) or other non-ProTracker formats — see re/shellplay/PHASE_A_NOTES.md.
set -euo pipefail

# NTP_SRC: a NinjaTrackerPlus distribution (NinjaForce), which carries the
# converter, ntpconverter.php.
: "${NTP_SRC:?set NTP_SRC to a NinjaTrackerPlus distribution (it carries ntpconverter.php)}"
CONV="$NTP_SRC/ntpconverter.php"

if ! command -v php >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    export PATH="$(brew --prefix php 2>/dev/null)/bin:$PATH"
  fi
fi
command -v php >/dev/null 2>&1 || { echo "error: php not found (brew install php)"; exit 1; }
[ -f "$CONV" ] || { echo "error: converter not found at $CONV (set NTP_SRC)"; exit 1; }

IN="${1:?usage: mod2ntp.sh <input.mod> [output_dir] [stream_config]}"
OUTDIR="${2:-$(dirname "$IN")}"
STREAM="${3:-STREAM_ALLOW}"
[ -f "$IN" ] || { echo "error: input not found: $IN"; exit 1; }

mkdir -p "$OUTDIR"
# Converter writes <name>.ntp next to the input; copy input into OUTDIR first
# so the .ntp lands there without disturbing the source tree.
base="$(basename "$IN")"
work="$OUTDIR/$base"
[ "$(cd "$(dirname "$IN")" && pwd)/$base" = "$(cd "$OUTDIR" && pwd)/$base" ] || cp "$IN" "$work"

# Silence PHP 8.x deprecation noise from the (older) converter; keep real errors.
php -d error_reporting=E_ALL\&~E_DEPRECATED "$CONV" "$work" "$STREAM"

ntp="${work%.*}.ntp"
[ "${work##*.}" = "$work" ] && ntp="$work.ntp"   # input had no extension
[ -f "$ntp" ] && echo "wrote: $ntp" || { echo "error: no .ntp produced"; exit 1; }
