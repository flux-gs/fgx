#!/bin/bash
# mame-capture.sh — headless, timed, SILENT MAME run that captures the emulated
# audio (incl. the Ensoniq DOC) to a WAV for offline analysis with
# doc_wav_probe.py. The audio-free playback oracle for the FGX MOD player.
#
# Validated 2026-05-27: boots FGX in ~5s wall (-seconds_to_run, -nothrottle,
# -video none); the IIgs boot beep appears in the WAV (~-53 dBFS at -volume -32),
# confirming the DOC reaches the wavwrite tap. NOTE: MAME -volume attenuates the
# wavwrite output too.
#
# Usage: tools/modplayer/mame-capture.sh <disk.po> <out.wav> [seconds] [--loud]
#   default: -volume -32 (quiet enough to be inaudible; tone still detectable).
#   --loud : -volume 0 (full-scale WAV) + mutes macOS output for the run and
#            restores it after (use for clean pitch detection of a real tone).
set -euo pipefail

DISK="${1:?usage: mame-capture.sh <disk.po> <out.wav> [seconds] [--loud]}"
OUT="${2:?output wav path required}"
SECS="${3:-8}"
MODE="${4:-}"

# MAME binary + support dir; override via $MAME / $FGX_MAME_SUPPORT.
. "$(dirname "$0")/../../lib/mame_env.sh"
SUP="$SUPPORT_DIR"
[ -f "$DISK" ] || { echo "error: disk not found: $DISK"; exit 1; }

VOL="-32"
RESTORE_MUTE=""
if [ "$MODE" = "--loud" ]; then
  VOL="0"
  # Mute macOS output so a full-scale capture stays silent; restore on exit.
  RESTORE_MUTE="$(osascript -e 'output muted of (get volume settings)' 2>/dev/null || echo false)"
  osascript -e 'set volume output muted true' 2>/dev/null || true
  trap 'osascript -e "set volume output muted '"$RESTORE_MUTE"'" 2>/dev/null || true' EXIT
fi

# Avoid stale fgxdebug test config hijacking the run (feedback_fgxdebug_config_hijack).
rm -f /tmp/fgx_debug_config.json "$OUT"

"$MAME" apple2gs -skip_gameinfo -ramsize 8M \
  -video none -seconds_to_run "$SECS" -nothrottle \
  -sound coreaudio -volume "$VOL" \
  -wavwrite "$OUT" \
  -homepath "$SUP" -rompath "$SUP/roms" -artpath "$SUP/artwork" \
  -bgfx_path "$SUP/bgfx" -nvram_directory "$SUP/nvram" -pluginspath "$SUP/plugins" \
  -sl7 retronet -hard1 "$DISK"

[ -f "$OUT" ] && echo "captured: $OUT" || { echo "error: no WAV produced"; exit 1; }
