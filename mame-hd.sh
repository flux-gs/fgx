#!/bin/bash
# FGX MAME launcher.
#
# Boots disk/fgxufs.po by default, on a slot-7 A2retroNET SmartPort card, a
# device in stock MAME and Ample. Pass disk image(s) to override: the first is
# the boot disk, and any additional images appear under /mnt/<volname>/. Any
# hard-disk card skips MAME's 3.5" floppy seek/transfer timing, ~4-6x faster
# end-to-end for small commands.
#
# EXPERIMENTAL: -microdrive and -secondsight need MAME devices that are not in
# any published MAME or Ample release (they exist only in an unpublished,
# patched MAME build).  A stock MAME refuses them; this script checks first and
# says so.
#
# Flags (mix freely with disk args; anything starting with '-' is a flag, else a
# disk image):
#   -debug         open the MAME debugger and load the fgxdebug plugin
#                  (tools/mame_test/plugins/fgxdebug, copied into the support
#                  dir's plugins/ first, as tools/mame_test/run.py does).
#                  Without -debug the plugin is not loaded, so a MAME install
#                  that has never run the test harness boots too.
#   -serial        attach the IIgs serial port to a MAME terminal window
#                  (adds a second screen for the terminal)
#   -socat         attach the serial port to a TCP socket (null_modem -bitb
#                  socket.localhost:25232) so socat can bridge it
#   -fl IMG        boot a floppy IMG from the built-in drive; the drive is
#                  auto-selected by image size: ~140K -> 5.25" Disk II (slot 6,
#                  MAME flop1), ~800K -> 3.5" (slot 5, MAME flop3).  No hard disk
#                  is attached; mutually exclusive with hard-disk args.
#   -no-net        omit the Uthernet II card (present by default)
#   -netslot N     put the Uthernet II in slot N (1-7; default 1)
#   -no-phasor     omit the Applied Engineering Phasor (present by default)
#   -phasorslot N  put the Phasor in slot N (1-7; default 4).  Two things the
#                  card being on the bus does NOT settle: the launcher runs MAME
#                  at -volume 0, so nothing is audible without editing that line;
#                  and the IIgs decides per slot whether $Cn00 belongs to a card
#                  or to the internal device, so slot 4 has to be "Your Card"
#                  rather than "Mouse" in the Control Panel before firmware can
#                  see it.  That setting lives in the shared Ample BRAM
#                  (-nvram_directory) and this script does not set it.
#   -secondsight   EXPERIMENTAL (needs an unpublished MAME device; see above).
#                  Add a Second Sight card (default slot 3) and a MAME window
#                  for its screen.  The sscon module asks the slot that
#                  cfg/system.cfg's sscon.slot names (3), so keep the two the
#                  same.  The card shows the fourth virtual console, ttyv3,
#                  with its own getty; Option-4 gives it the keyboard while
#                  the IIgs screen keeps whichever console it shows, and
#                  Option-1..3 bring the keys back.  The card's window shows
#                  the mode's raster, 720x400 for 80x25 text; a Second Sight
#                  device older than the 2026-09-18 overlay (its visible area
#                  fixed at 1056x768) parks the text in the window's top-left.
#   -ssslot N      put the Second Sight in slot N (1-7; implies -secondsight)
#
#   Storage device (pick one; default -retronet):
#   -retronet      A2retroNET SmartPort card in slot 7 (plain SmartPort), boot
#                  disk on -hard1 and extras on -hard2..-hard8.
#   -microdrive    EXPERIMENTAL (needs an unpublished MAME device and mdttool;
#                  see above).  ReActiveMicro MicroDrive/Turbo in slot 7
#                  (extended SmartPort; fastest multi-block reads).  It takes
#                  a CF-card image, so the .po disks are wrapped with mdttool
#                  into one <first-disk>.mdt, rebuilt when a .po's checksum
#                  changes; mdttool is found on $PATH or named by $MDTTOOL.
#   -cffa          CFFA 2.0 Compact Flash card in slot 7; up to 2 disks.
#   -scsi          Apple II SCSI Card in slot 5, single boot disk.
#                  -cffa and -scsi REPRODUCE the SmartPort-only boot crash: the
#                  stage-1/stage-2 loaders speak only SmartPort ($Cn00+[$CnFF]+3,
#                  inline call), and a plain ProDOS-block card has no SmartPort
#                  dispatcher there, so the inline call runs wild -> BRK at
#                  $00/0000 (IIgs monitor).
#   -keep-config   do NOT wipe /tmp/fgx_debug_config.json (for instrumented
#                  -debug sessions where you set the fgxdebug config up first)
#   -showconfig    print MAME's resolved config and exit
#   -h, -help      this help
#
# Examples:
#   ./mame-hd.sh                          # boot disk/fgxufs.po on the A2retroNET
#   ./mame-hd.sh disk/ntp.2mg             # boot ntp.2mg instead
#   ./mame-hd.sh disk/fgxufs.po disk/ntp.2mg # boot fgxufs.po, ntp.2mg on -hard2
#   ./mame-hd.sh -debug                   # boot fgxufs.po under the debugger
#   ./mame-hd.sh -serial disk/fgxufs.po      # boot with a serial terminal
#   ./mame-hd.sh -fl disk/fgx-floppy.po   # boot the 800K 3.5" FGX floppy (auto)
#   ./mame-hd.sh -fl disk/fgx140.po       # boot a 140K 5.25" floppy (auto)
#
# Emulator location: defaults to a macOS Ample install; override with $MAME /
# $FGX_MAME_SUPPORT (see lib/mame_env.sh).
#
# A STALE TREE IS REFUSED.  Every image under disk/ is a build output, so this
# runs `ninja -n' first and stops if the tree is unbuilt or half-built -- the
# same check tools/mame_test/run.py makes, for the same reason.  Set
# FGX_ALLOW_STALE=1 to boot the old image on purpose.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() { sed -n '2,/^set /p' "$0" | sed '/^set /d; s/^# \{0,1\}//'; }

# --- parse flags + positional disk images ---
DEBUG=0; SERIAL=0; SOCAT=0; NET=1; NETSLOT=1; KEEP_CONFIG=0; SHOWCONFIG=0
PHASOR=1; PHASORSLOT=4
SECONDSIGHT=0; SSSLOT=3
STORAGE=retronet
FLOP=""
DISKS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -debug)       DEBUG=1 ;;
    -serial)      SERIAL=1 ;;
    -socat)       SOCAT=1 ;;
    -fl)          shift; FLOP="${1:-}"; [ -n "$FLOP" ] || { echo "error: -fl requires a floppy image path (140K 5.25\" or 800K 3.5\")" >&2; exit 1; } ;;
    -no-net)      NET=0 ;;
    -no-phasor)   PHASOR=0 ;;
    -microdrive)  STORAGE=microdrive ;;
    -retronet)    STORAGE=retronet ;;
    -cffa)        STORAGE=cffa ;;
    -scsi)        STORAGE=scsi ;;
    -netslot)     shift; NETSLOT="${1:-}"; case "$NETSLOT" in [1-7]) ;; *) echo "error: -netslot requires a slot number 1-7" >&2; exit 1 ;; esac ;;
    -phasorslot)  shift; PHASORSLOT="${1:-}"; case "$PHASORSLOT" in [1-7]) ;; *) echo "error: -phasorslot requires a slot number 1-7" >&2; exit 1 ;; esac ;;
    -secondsight) SECONDSIGHT=1 ;;
    -ssslot)      shift; SSSLOT="${1:-}"; SECONDSIGHT=1; case "$SSSLOT" in [1-7]) ;; *) echo "error: -ssslot requires a slot number 1-7" >&2; exit 1 ;; esac ;;
    -keep-config) KEEP_CONFIG=1 ;;
    -showconfig)  SHOWCONFIG=1 ;;
    -h|-help|--help) usage; exit 0 ;;
    -*) echo "error: unknown option: $1" >&2; echo "try '$0 -h'" >&2; exit 1 ;;
    *)  DISKS+=("$1") ;;
  esac
  shift
done

# Resolve the MAME binary + Ample support dir; override via $MAME / $FGX_MAME_SUPPORT.
. "$SCRIPT_DIR/lib/mame_env.sh"

if [ "$SHOWCONFIG" -eq 1 ]; then exec "$MAME" -showconfig; fi

# The experimental devices: refuse up front, by name, on a MAME without them,
# rather than let MAME fail on an unknown slot option.
EXPERIMENTAL=()
if [ "$STORAGE" = microdrive ] && [ -z "$FLOP" ]; then EXPERIMENTAL+=(microdrive); fi
if [ "$SECONDSIGHT" -eq 1 ]; then EXPERIMENTAL+=(secondsight); fi
if [ "${#EXPERIMENTAL[@]}" -gt 0 ]; then
  SLOTS="$("$MAME" -listslots apple2gs 2>/dev/null || true)"
  for dev in "${EXPERIMENTAL[@]}"; do
    echo "warning: -$dev is EXPERIMENTAL: it needs a MAME device that no published MAME or Ample has yet." >&2
    if ! printf '%s\n' "$SLOTS" | grep -qw "$dev"; then
      echo "error: $MAME has no '$dev' slot device; drop -$dev (the default -retronet works on stock MAME)." >&2
      exit 1
    fi
  done
fi

if [ "$SERIAL" -eq 1 ] && [ "$SOCAT" -eq 1 ]; then
  echo "error: -serial and -socat are mutually exclusive (both configure the serial port)" >&2
  exit 1
fi

# Floppy boot is its own mode: a single built-in floppy drive is the boot
# device, with NO slot-7 hard disk (so the IIgs startup scan reaches it).
# -fl auto-selects the drive by image SIZE; it's mutually exclusive with
# hard-disk args.
FLOPPY=""; FLOPDRV=""; FLOPKIND=""
if [ -n "$FLOP" ]; then
  [ -f "$FLOP" ] || { echo "error: floppy image not found: $FLOP" >&2; exit 1; }
  FLOPPY="$FLOP"
  # Pick the drive by image size: 5.25" Disk II ~140K (143360 B), 3.5" ~800K
  # (819200 B); allow slack for .2mg/.hdv headers.  470K is the split point.
  FLOPSZ=$(wc -c < "$FLOPPY" | tr -d '[:space:]')
  if [ "$FLOPSZ" -lt 51200 ] || [ "$FLOPSZ" -gt 1572864 ]; then
    echo "error: $FLOPPY is ${FLOPSZ} bytes — not a 140K 5.25\" (~143360 B) or" >&2
    echo "       800K 3.5\" (~819200 B) floppy; larger images are hard disks (pass" >&2
    echo "       them as positional args, not -fl)." >&2
    exit 1
  elif [ "$FLOPSZ" -lt 481280 ]; then
    FLOPDRV="-flop1"; FLOPKIND="140K 5.25\" (slot 6, ${FLOPSZ} B)"
  else
    FLOPDRV="-flop3"; FLOPKIND="800K 3.5\" (slot 5, ${FLOPSZ} B)"
  fi
  if [ "${#DISKS[@]}" -gt 0 ]; then
    echo "error: cannot combine a boot floppy (-fl) with hard-disk args;" >&2
    echo "       the floppy is the sole boot device (no slot-7 retronet)." >&2
    exit 1
  fi
fi

# Default boot disk (hard-disk mode only).
if [ -z "$FLOPPY" ] && [ "${#DISKS[@]}" -eq 0 ]; then DISKS=("disk/fgxufs.po"); fi

# Storage card: which slot it occupies and how many disks it can take.
# (SCSI is single-disk here: multi-target SCSI-ID wiring is out of scope.)
case "$STORAGE" in
  microdrive) STORSLOT=7; MAXDISKS=8 ;;
  retronet)   STORSLOT=7; MAXDISKS=8 ;;
  cffa)       STORSLOT=7; MAXDISKS=2 ;;
  scsi)       STORSLOT=5; MAXDISKS=1 ;;
esac

if [ -z "$FLOPPY" ]; then
  if [ "$NET" -eq 1 ] && [ "$NETSLOT" -eq "$STORSLOT" ]; then
    echo "error: -$STORAGE puts the storage card in slot $STORSLOT; move the net card (-netslot N, N!=$STORSLOT) or use -no-net." >&2
    exit 1
  fi
  if [ "$PHASOR" -eq 1 ] && [ "$PHASORSLOT" -eq "$STORSLOT" ]; then
    echo "error: -$STORAGE puts the storage card in slot $STORSLOT; move the Phasor (-phasorslot N, N!=$STORSLOT) or use -no-phasor." >&2
    exit 1
  fi
  if [ "$SECONDSIGHT" -eq 1 ] && [ "$SSSLOT" -eq "$STORSLOT" ]; then
    echo "error: -$STORAGE puts the storage card in slot $STORSLOT; move the Second Sight (-ssslot N, N!=$STORSLOT)." >&2
    exit 1
  fi
  if [ "${#DISKS[@]}" -gt "$MAXDISKS" ]; then
    echo "error: -$STORAGE takes at most $MAXDISKS disk image(s)." >&2
    exit 1
  fi
fi

if [ "$PHASOR" -eq 1 ] && [ "$NET" -eq 1 ] && [ "$PHASORSLOT" -eq "$NETSLOT" ]; then
  echo "error: the Phasor and the Uthernet II are both in slot $PHASORSLOT; move one (-phasorslot N / -netslot N)." >&2
  exit 1
fi
if [ "$SECONDSIGHT" -eq 1 ] && [ "$NET" -eq 1 ] && [ "$SSSLOT" -eq "$NETSLOT" ]; then
  echo "error: the Second Sight and the Uthernet II are both in slot $SSSLOT; move one (-ssslot N / -netslot N)." >&2
  exit 1
fi
if [ "$SECONDSIGHT" -eq 1 ] && [ "$PHASOR" -eq 1 ] && [ "$SSSLOT" -eq "$PHASORSLOT" ]; then
  echo "error: the Second Sight and the Phasor are both in slot $SSSLOT; move one (-ssslot N / -phasorslot N)." >&2
  exit 1
fi

# Wipe any stale fgxdebug plugin config left by tools/mame_test/run.py — without
# this an interactive launch picks up a test_mode config and exits at ~16 s
# (memory/feedback_fgxdebug_config_hijack.md). -keep-config skips it.
if [ "$KEEP_CONFIG" -eq 0 ]; then rm -f /tmp/fgx_debug_config.json; fi

ROMPATH="${ROMPATH:-$SUPPORT_DIR/roms}"
BGFXPATH="${BGFXPATH:-$SUPPORT_DIR/bgfx}"
ARTPATH="${ARTPATH:-$SUPPORT_DIR/artwork}"
NVRAMPATH="${NVRAMPATH:-$SUPPORT_DIR/nvram}"
PLUGINPATH="${PLUGINPATH:-$SUPPORT_DIR/plugins}"

# Validate inputs.
i=0
while [ "$i" -lt "${#DISKS[@]}" ]; do
  d="${DISKS[$i]}"
  [ -f "$d" ] || { echo "error: disk image not found: $d" >&2; exit 1; }
  i=$((i + 1))
done
for d in "$ROMPATH" "$BGFXPATH" "$ARTPATH" "$NVRAMPATH"; do
  [ -d "$d" ] || { echo "error: required directory missing: $d" >&2; exit 1; }
done

# --- Is the tree built?  Refuse to boot an image that is not this tree. ---
#
# Every image under disk/ is a build output, so an unbuilt or half-built tree
# means the thing booting is not the thing checked out.  The worst shape is a
# PARTIAL one: a kernel newer than the staged /sbin/init, or a libc pile whose
# class name changed under the binaries that name it, boots as far as
# `spawning init...' and stops -- which reads as a kernel bug and is not one.
# That is not hypothetical; it cost an afternoon's bisecting on 2026-09-16.
#
# tools/mame_test/run.py has always refused this and says so in the same words.
# This script did not, and it is the one that boots the image IN PLACE and
# re-wraps it for the MicroDrive, so it could wrap a .po that ninja was still
# writing -- the mtime the wrap compares says nothing about whether the file is
# finished.  The check goes BEFORE the wrap for that reason.
#
# FGX_ALLOW_STALE=1 to boot the old image on purpose, which is a real thing to
# want -- bisecting by hand, or comparing against an image you kept.
if [ "${FGX_ALLOW_STALE:-0}" != "1" ] && [ -f "$SCRIPT_DIR/build.ninja" ] \
   && command -v ninja >/dev/null 2>&1; then
  if ! PENDING="$(cd "$SCRIPT_DIR" && ninja -n 2>&1)"; then
    echo "error: the build graph is BROKEN (\`ninja -n' failed), so ${DISKS[0]:-the image} cannot be the tree you are booting:" >&2
    printf '%s\n' "$PENDING" | tail -5 | sed 's/^/  /' >&2
    echo "Fix the build, or set FGX_ALLOW_STALE=1 to boot the old image on purpose." >&2
    exit 1
  fi
  if [ "$PENDING" != "ninja: no work to do." ]; then
    echo "error: ${DISKS[0]:-the image} is STALE -- \`ninja -n' still has work to do, so this would boot an image that is not your tree:" >&2
    printf '%s\n' "$PENDING" | sed -n '1,5s/^/  /p' >&2
    echo "Run \`ninja' first, or set FGX_ALLOW_STALE=1 to boot the old image on purpose." >&2
    exit 1
  fi
fi

# The MicroDrive reads a CF-card image, so wrap the .po disk(s) into one .mdt
# (partition order = argument order, so partition 1 is the boot disk).  Rebuilt
# when an input's checksum differs from the one recorded at the last wrap.
sumfile() {
  if command -v md5sum >/dev/null 2>&1; then md5sum "$1" | cut -d' ' -f1
  else md5 -q "$1"; fi
}
MDT=""
if [ -z "$FLOPPY" ] && [ "$STORAGE" = microdrive ]; then
  if [ "${DISKS[0]}" = "${DISKS[0]%.mdt}" ]; then
    MDTTOOL="${MDTTOOL:-$(command -v mdttool || true)}"
    [ -n "$MDTTOOL" ] && [ -x "$MDTTOOL" ] || { echo "error: mdttool not found: set \$MDTTOOL, put mdttool on \$PATH, or use -retronet" >&2; exit 1; }
    MDT="${DISKS[0]%.*}.mdt"
    # REWRAP ON CONTENT, NOT ON MTIME.  A tree synced to another machine with
    # its mtimes preserved can carry a .po OLDER than a .mdt wrapped there
    # from a previous copy; an mtime test then boots the previous copy for as
    # long as the .mdt lives, while the .po's checksum says the tree is
    # current.  The inputs' checksums are kept beside the wrap and compared.
    SUM=""
    for d in "${DISKS[@]}"; do SUM="$SUM $(sumfile "$d")"; done
    if [ ! -f "$MDT" ] || [ "$(cat "${MDT%.mdt}.mdtsum" 2>/dev/null)" != "$SUM" ]; then
      echo "Wrapping ${DISKS[*]} -> $MDT (mdttool)"
      "$MDTTOOL" -a -o "$MDT" "${DISKS[@]}" || { echo "error: mdttool failed; $MDT is not usable" >&2; rm -f "$MDT" "${MDT%.mdt}.mdtsum"; exit 1; }
      printf '%s' "$SUM" > "${MDT%.mdt}.mdtsum"
    fi
  else
    MDT="${DISKS[0]}"   # already a CF-card image
  fi
fi

# --- build the MAME command ---
ARGS=(
  apple2gs            # ROM 03
  -window
  -skip_gameinfo
  -ramsize 8M
  -sound coreaudio -volume 0
  -video bgfx
  -bgfx_screen_chains Fighters
  -homepath "$SUPPORT_DIR"
  -rompath "$ROMPATH"
  -artpath "$ARTPATH"
  -bgfx_path "$BGFXPATH"
  -nvram_directory "$NVRAMPATH"
)
if [ -d "$PLUGINPATH" ] || [ "$DEBUG" -eq 1 ]; then ARGS+=( -pluginspath "$PLUGINPATH" ); fi

# Uthernet II, on by default in NETSLOT (default 1; -netslot N to move it; Phase B
# binds net to whatever slot it's in).
if [ "$NET" -eq 1 ]; then ARGS+=( -sl${NETSLOT} uthernet2 ); fi

# Applied Engineering Phasor, on by default in PHASORSLOT (default 4).
if [ "$PHASOR" -eq 1 ]; then ARGS+=( -sl${PHASORSLOT} phasor ); fi

# Second Sight, off by default, in SSSLOT (default 3, the slot the kernel's
# sscon.slot names).  Its screen is a MAME screen of its own, below.
if [ "$SECONDSIGHT" -eq 1 ]; then ARGS+=( -sl${SSSLOT} secondsight ); fi

# Screen layout: one window per screen -- the IIgs, then the -serial terminal
# and the Second Sight, in MAME's own order -- single otherwise.
NSCREENS=$((1 + SERIAL + SECONDSIGHT))
if [ "$NSCREENS" -gt 1 ]; then
  ARGS+=( -unevenstretch -numscreens "$NSCREENS"
          -resolution0 1408x924 -view0 "screen 0"
          -resolution1 1056x768 -view1 "screen 1" )
  if [ "$NSCREENS" -ge 3 ]; then ARGS+=( -resolution2 1056x768 -view2 "screen 2" ); fi
else
  ARGS+=( -nounevenstretch -resolution 1408x924 )
fi

# Boot media: a built-in floppy (no slot-7 card), an Apple II SCSI Card in
# slot 5, or slot-7 retronet hard disks (default).
if [ -n "$FLOPPY" ]; then
  # Floppy boot: attach to the built-in drive only.  With no slot-7 card the
  # IIgs startup scan falls through to the floppy (assumes CP startup = Scan).
  ARGS+=( "$FLOPDRV" "$FLOPPY" )
elif [ "$STORAGE" = microdrive ]; then
  # MicroDrive/Turbo takes a CF-card image: wrap the .po list into one .mdt
  # (partition 1 = boot disk), rebuilt when an input's checksum changes.
  ARGS+=( -sl7 microdrive,bios=iigs -hard1 "$MDT" )
elif [ "$STORAGE" = cffa ]; then
  ARGS+=( -sl7 cffa2 -hard1 "${DISKS[0]}" )
  if [ "${#DISKS[@]}" -gt 1 ]; then ARGS+=( -hard2 "${DISKS[1]}" ); fi
elif [ "$STORAGE" = scsi ]; then
  # Apple II SCSI Card in slot 5; boot disk on the SCSI bus (-hard1).  This is
  # the SmartPort-only-loader repro: a plain ProDOS-block card, no SmartPort.
  ARGS+=( -sl5 scsi -hard1 "${DISKS[0]}" )
else
  # Disks on slot-7 retronet: boot on hard1, extras on hard2+.
  ARGS+=( -sl7 retronet -hard1 "${DISKS[0]}" )
  slot=2; i=1
  while [ "$i" -lt "${#DISKS[@]}" ]; do
    ARGS+=( "-hard${slot}" "${DISKS[$i]}" )
    slot=$((slot + 1)); i=$((i + 1))
  done
fi

# Serial port.
if [ "$SERIAL" -eq 1 ]; then ARGS+=( -modem terminal ); fi
if [ "$SOCAT" -eq 1 ];  then ARGS+=( -modem null_modem -bitb socket.localhost:25232 ); fi

# Debugger, and the fgxdebug plugin with it.  MAME's -pluginspath is one
# directory, not a search list, so the repo's copy is synced into the support
# dir's plugins/ beside MAME's own (json, console) rather than pointed at.
if [ "$DEBUG" -eq 1 ]; then
  PLUGSRC="$SCRIPT_DIR/tools/mame_test/plugins/fgxdebug"
  mkdir -p "$PLUGINPATH/fgxdebug" || { echo "error: cannot create $PLUGINPATH/fgxdebug (set \$FGX_MAME_SUPPORT or \$PLUGINPATH)" >&2; exit 1; }
  for f in init.lua plugin.json; do
    cmp -s "$PLUGSRC/$f" "$PLUGINPATH/fgxdebug/$f" || cp "$PLUGSRC/$f" "$PLUGINPATH/fgxdebug/$f" \
      || { echo "error: cannot copy $f into $PLUGINPATH/fgxdebug" >&2; exit 1; }
  done
  ARGS+=( -debug -plugin fgxdebug )
fi

# --- summary + launch ---
if [ -n "$FLOPPY" ]; then
  echo "Booting under MAME (built-in floppy):"
  echo "  ${FLOPDRV#-} (boot): $FLOPPY  [$FLOPKIND]"
elif [ "$STORAGE" = microdrive ]; then
  echo "Booting under MAME (slot-7 MicroDrive/Turbo, extended SmartPort):"
  echo "  hard1 (boot): $MDT"
  i=1
  while [ "$i" -lt "${#DISKS[@]}" ]; do
    echo "  partition $((i + 1)): ${DISKS[$i]}"
    i=$((i + 1))
  done
elif [ "$STORAGE" = cffa ]; then
  echo "Booting under MAME (slot-7 CFFA 2.0):"
  echo "  hard1 (boot): ${DISKS[0]}  [SmartPort-only-loader repro]"
  if [ "${#DISKS[@]}" -gt 1 ]; then echo "  hard2: ${DISKS[1]}"; fi
elif [ "$STORAGE" = scsi ]; then
  echo "Booting under MAME (slot-5 Apple II SCSI Card):"
  echo "  hard1 (boot): ${DISKS[0]}  [SmartPort-only-loader repro]"
else
  echo "Booting under MAME (slot-7 retronet):"
  echo "  hard1 (boot): ${DISKS[0]}"
  slot=2; i=1
  while [ "$i" -lt "${#DISKS[@]}" ]; do
    echo "  hard${slot}: ${DISKS[$i]}"
    slot=$((slot + 1)); i=$((i + 1))
  done
fi
if [ "$NET" -eq 1 ]; then echo "  net:    Uthernet II (slot ${NETSLOT})"; else echo "  net:    off"; fi
if [ "$PHASOR" -eq 1 ]; then echo "  sound:  Phasor (slot ${PHASORSLOT})"; else echo "  sound:  no Phasor"; fi
if [ "$SECONDSIGHT" -eq 1 ]; then echo "  video:  Second Sight (slot ${SSSLOT}) showing ttyv3; Option-4 for its keyboard"; fi
if [ "$SERIAL" -eq 1 ]; then echo "  serial: terminal window"; fi
if [ "$SOCAT" -eq 1 ];  then echo "  serial: null_modem -> socket :25232 (socat)"; fi
if [ "$DEBUG" -eq 1 ];  then echo "  debug:  MAME debugger, fgxdebug plugin"; fi
exec "$MAME" "${ARGS[@]}"
