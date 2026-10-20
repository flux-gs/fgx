#!/usr/bin/env bash
# lib/mame_env.sh - resolve the MAME emulator binary + its support directory.
#
# Sourced by the mame-*.sh launchers and build.sh's screenshot path so the
# machine-specific paths live in ONE place and are overridable — FGX shouldn't
# be pinned to one developer's Mac.  Override either via the environment:
#
#   MAME              path to a mame64 binary (an Apple IIgs-capable build, e.g.
#                     the Ample MAME fork).  Default: a macOS Ample install,
#                     falling back to mame64/mame on $PATH.
#   FGX_MAME_SUPPORT  the emulator support dir holding roms/, bgfx/, artwork/,
#                     nvram/, plugins/.  Default: the macOS Ample support dir.
#
# On a non-default setup:
#   export MAME=/path/to/mame64 FGX_MAME_SUPPORT=/path/to/support
# (or just put mame64/mame on $PATH and export FGX_MAME_SUPPORT).
#
# Sets two shell variables for the caller: MAME and SUPPORT_DIR.  If no MAME
# binary can be found it prints guidance and returns/exits 1.

# --- support dir: env override -> macOS Ample default ---
SUPPORT_DIR="${FGX_MAME_SUPPORT:-$HOME/Library/Application Support/Ample}"

# --- MAME binary: env -> Ample app default (if executable) -> $PATH ---
if [ -z "${MAME:-}" ]; then
    _fgx_ample_mame="/Applications/Ample.app/Contents/MacOS/mame64"
    if [ -x "$_fgx_ample_mame" ]; then
        MAME="$_fgx_ample_mame"
    else
        MAME="$(command -v mame64 || command -v mame || true)"
    fi
    unset _fgx_ample_mame
fi

if [ -z "${MAME:-}" ] || [ ! -x "$MAME" ]; then
    echo "error: no MAME binary found." >&2
    echo "  Set \$MAME to an Apple IIgs-capable mame64 (e.g. the Ample fork)," >&2
    echo "  and \$FGX_MAME_SUPPORT to its support dir (roms/bgfx/artwork/nvram/plugins)," >&2
    echo "  or put mame64/mame on your \$PATH." >&2
    return 1 2>/dev/null || exit 1
fi
