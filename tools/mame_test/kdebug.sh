#!/usr/bin/env bash
# kdebug.sh — launch FGX in MAME's INTERACTIVE debugger (non-perturbing).
#
# Why: layout/size-sensitive Heisenbugs (e.g. the sed "read returns 0" bug)
# change or vanish the moment you add instrumentation to the kernel or a
# userland binary — editing source IS the perturbation.  This boots the
# UNMODIFIED disk image and drops you into MAME's debugger so you can set
# hardware breakpoints/watchpoints and inspect live, changing nothing.
# (See tools/mame_test/KPROBE.md for the watchpoint recipe + address map.)
#
# Usage:
#   ./tools/mame_test/kdebug.sh                       # boot to shell; you type the cmd
#   ./tools/mame_test/kdebug.sh "sed s/a/b/ /docs/x"  # autoboot the command after 12s
#
# Env overrides: FGX_KDEBUG_DISK (default disk/fgxufs.po), MAME, FGX_MAME_SUPPORT.
#   FGX_KDEBUG_PERSIST=1  boot the source image DIRECTLY (writes persist).  By
#   default kdebug boots a scratch COPY so MAME's read-write -hard1 writes (elvis
#   temp files, FS churn) never mutate/corrupt the source image over time.
#
# Opens two windows: the IIgs screen and the MAME debugger console.  Type
# debugger commands in the console; `go` (F5) resumes, breakpoints/watchpoints
# stop it.  Quit with the debugger's `exit` or close the window.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
MAME="${MAME:-/Applications/Ample.app/Contents/MacOS/mame64}"
SUP="${FGX_MAME_SUPPORT:-$HOME/Library/Application Support/Ample}"
SRC="${FGX_KDEBUG_DISK:-$REPO/disk/fgxufs.po}"
CMD="${1:-}"

[ -f "$SRC" ] || { echo "kdebug: disk $SRC missing — run ./build.sh disk" >&2; exit 1; }

# MAME boots -hard1 READ-WRITE, so it writes into whatever image it's given
# (elvis temp files, FS growth).  Booting the source directly slowly corrupts it
# (accumulated /var/tmp/ELV* + bitmap leaks).  Default: boot a scratch COPY so the
# source stays pristine.  FGX_KDEBUG_PERSIST=1 boots the source directly.
if [ "${FGX_KDEBUG_PERSIST:-0}" = "1" ]; then
    DISK="$SRC"
    echo "kdebug: PERSIST mode — booting $SRC directly (MAME writes MUTATE it)"
else
    DISK="${TMPDIR:-/tmp}/fgx_kdebug_run.po"
    cp "$SRC" "$DISK"
    echo "kdebug: booting a scratch copy (writes discarded; FGX_KDEBUG_PERSIST=1 to persist)"
fi

args=( apple2gs -skip_gameinfo -ramsize 8M
       -window -nounevenstretch
       -homepath "$SUP" -rompath "$SUP/roms" -artpath "$SUP/artwork"
       -nvram_directory "$SUP/nvram"
       -sl7 retronet -hard1 "$DISK" -natural
       -video bgfx -bgfx_path "$SUP/bgfx" -resolution 1280x800
       -debug )
if [ -n "$CMD" ]; then
    args+=( -autoboot_delay 12 -autoboot_command "$CMD"$'\n' )
fi

echo "kdebug: launching interactive debugger on $DISK"
[ -n "$CMD" ] && echo "        autoboot (after ~12s): $CMD" || echo "        (no autoboot — type your command in the IIgs window once booted)"
echo "        live kernel bank: in the debugger, 'print b@32C'"
echo "        recipe: tools/mame_test/KPROBE.md  (§ Interactive debugger)"
exec "$MAME" "${args[@]}"
