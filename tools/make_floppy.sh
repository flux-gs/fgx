#!/bin/bash
#==============================================================================
# make_floppy.sh — the FGX RESCUE floppy (~800K SmartPort 3.5").
#
# PARKED 2026-09-06, AND NOTHING CALLS THIS.  A floppy image, if pursued again,
# will be for a specific purpose.  The ninja edge that built
# disk/fgx-floppy.po is commented out (tools/ninja/gen.py), `ninja release' no
# longer carries it, CI does not publish it,
# tools/cleanroom.sh no longer checks for it, nothing runs this,
# and floppy_boot skips.  The script itself is untouched and still works if you
# run it by hand.
#
# IT DOES NOT FIT TODAY.  apple/fgx#340: over by `rm' + `sync' = 75,261 bytes,
# about 147 ProDOS blocks, measured by dropping binaries until the image built.
# Each FGX2 binary carries its own ~70 KB libc pile, so /bin is what fills it,
# and the three UFS modules a rescue disk needs to read the filesystem it is
# meant to repair are another ~150 KB.  Deciding what the floppy is FOR is what
# decides the payload, which is why this is parked rather than trimmed.
#
# RUNNING IT WITH A REDUCED FLOPPY_BIN LEAVES A TRAP: a valid-LOOKING image
# missing binaries, which floppy_boot would run against and could pass.  The
# checked adds below delete the image on any failure, which is what keeps that
# honest -- do not defeat it.
#
# THIS IS A RESCUE DISK, NOT A SMALL FGX (2026-08-29).  It exists to boot
# a machine whose hard-disk install is broken and give you enough to repair it:
# single user, one console, no network, an editor, and the few tools that make
# /bin/sh usable.  It is deliberately NOT a general-purpose system, and the
# reason is arithmetic rather than taste -- see THE BUDGET below.
#
# Same loader / stage2 / kernel as disk/fgxufs.po.  Every add is checked; a missing
# essential or an overflow DELETES the image and fails loudly.
#
# THE BUDGET, measured 2026-08-29 rather than estimated.  The volume is 1600
# blocks.  The boot chain and the filesystem modules take 975 of them:
#
#     kernel three banks   310 blk      /sbin/init            135 blk
#     VFS + UFS + UFSDIR   253 blk      PRODOS                 16 blk
#     loader + /boot        10 blk      /etc + fonts + SERIAL  27 blk
#
# ...which leaves ~625 for /bin, and EVERY FGX2 BINARY CARRIES THE ~70K LIBC
# PILE, so a tool costs 70-130 blocks whatever it does.  That is why the tool
# list is six items and not sixteen: `cp' alone does not fit beside them.  The
# same arithmetic is why the old "minimal boot + network" floppy stopped
# building at all (apple/fgx#208) as VFS/UFS grew -- it was carrying a network
# stack and a general-purpose /bin on a disk that no longer had room for either.
#
# WHAT IS DELIBERATELY ABSENT, and what to do instead:
#   cp      -- `cat src > dst'.  The Bourne shell has redirection (sh(1)); this
#              is the substitution that buys room for `ed'.
#   mkdir   -- nothing substitutes for it.  Omitted because a config repair
#              rarely needs a new directory and it costs 96 blocks.
#   mount   -- DOES NOT EXIST YET.  mount(2)/umount(2) are syscalls 21/22,
#              RESERVED and unimplemented, "held for the UFS campaign"
#              (include/loader.s:216).  Filesystems are mounted by the kernel at
#              boot.  When mount(1) exists it belongs on this disk.
#   vi      -- 314K, more than twice `ed' and a third of the whole volume.
#   network -- dhclient/inetd/getty/login are all off the disk, so /etc/rc and
#              /etc/ttys are REWRITTEN below rather than copied: the shipped
#              ones spawn binaries this image does not carry.
#
# What lands, and why (the boot chain drives the list):
#   loader (sector 0) + /KERNEL + /KERNELFAR + /KERNELTTY + /boot — stage2 + kernel
#   /etc/*                                          — boot config, minus the
#       network configs and with ttys/rc/motd REWRITTEN for single user
#   /lib/fonts: $FLOPPY_FONTS                       — console font (DEFAULT.FNT)
#   /lib/modules minus $FLOPPY_MOD_EXCLUDE          — PRODOS VFS UFS UFSDIR
#       SERIAL: the filesystem stack, which is what a rescue disk is for
#   /sbin: $FLOPPY_SBIN                             — init only (kernel spawns it)
#   /bin:  $FLOPPY_BIN                              — sh (init spawns it) plus
#       the repair set.  NOTE the shell is bsh, a real Bourne shell: `echo' is
#       NOT a builtin, so /bin/echo is a genuine requirement.
#   /root (empty), /var/{log,tmp}, /tmp             - minus the /root/ntp sample
#       and all test cruft (/testbin /tests /root/ntp)
#
# Reuses build/loader_padded.bin, bin/fgx.bin, disk_src/boot — run after (or as
# part of) ./build.sh disk.  Nothing invokes it while it is parked.
#==============================================================================
set -e
. "$(dirname "$0")/../lib/build_common.sh"
cd "$PROJECT_ROOT"

require_tool cadius "Cadius ProDOS disk utility"

IMG="${FLOPPY_IMAGE_OVERRIDE:-disk/fgx-floppy.po}"
VOL="${VOLUME_NAME_OVERRIDE:-FGX}"

# --- The rescue include set (override via env for a custom floppy). ---------
# /bin: sh is required (init spawns it).  The rest is the smallest set that can
# actually repair an install: read a file, list a directory, edit a file, remove
# a bad one, and commit the result before the disk comes out.
#
#   sh    required        ed    edit the broken config -- the point of the disk
#   ls    see the damage  cat   read a file, and `cat a > b' for copy
#   echo  NOT a Bourne builtin, so a real binary; also `echo x > f' to create
#   rm    delete a corrupt file      sync  commit writes before ejecting
#
# Measured free space with this set: 82 blocks (41 KB).  Each binary grows with
# libc, and there are seven of them, so a 2K libc growth costs ~28 blocks --
# roughly three growth cycles of headroom.  Adding one more tool costs another
# 70-130 and takes that to nearly nothing, which is the whole trade.
FLOPPY_BIN="${FLOPPY_BIN:-sh ed ls cat echo rm sync}"
# /sbin: init only.  dhclient is gone with the network; getty and login are not
# here either, because the console runs the shell directly (see /etc/ttys below).
FLOPPY_SBIN="${FLOPPY_SBIN:-init}"
# /lib/fonts: default.fnt is the console font.  default35.fnt went with the
# 320-pixel mode on 2026-09-01.
FLOPPY_FONTS="${FLOPPY_FONTS:-default.fnt}"
# /lib/modules: what a RESCUE boot needs, which is the FILESYSTEM STACK and
# nothing else.  PRODOS reads today's installs; VFS + UFS + UFSDIR read the ones
# the UFS campaign is moving to, and cost 253 blocks together -- kept anyway,
# because a rescue disk that cannot read the filesystem it is meant to repair is
# a disk you find out about at the worst moment.  SERIAL stays for a console on
# a machine whose video is the problem.
#
# NET and BPF go: there is no dhclient to use them.  PTY goes: one console, no
# ptys.  RAMDISK goes: 4 blocks, but nothing on this disk mounts it.  The test
# modules never shipped anywhere.
#
# THE CONFIG IS FILTERED TO MATCH, below.  Dropping the module without dropping
# its modload.conf line trades a full disk for a boot that logs a load failure
# and paints the border yellow -- quieter than an overflow and just as wrong.
FLOPPY_MOD_EXCLUDE="${FLOPPY_MOD_EXCLUDE:-HELLO HELLOFAIL HELLOKC UFSPROBE NET BPF PTY RAMDISK}"

for f in build/loader_padded.bin bin/fgx.bin bin/fgxfar.bin bin/fgxtty.bin disk_src/boot; do
    [ -f "$f" ] || fail "make_floppy: missing $f — run ./build.sh disk first" 2
done

echo_step "Creating minimal 800K boot floppy -> $IMG"
rm -f "$IMG"
cadius CREATEVOLUME "$IMG" "$VOL" "800KB" >/dev/null
dd if=build/loader_padded.bin of="$IMG" bs=512 seek=0 conv=notrunc 2>/dev/null
cp bin/fgx.bin build/KERNEL
cadius ADDFILE "$IMG" "/$VOL" build/KERNEL >/dev/null
# The far kernel bank is part of the kernel image, not an optional extra: sound
# and the BRAM RTC syscalls live there, and boot JSLs into it before the console
# exists.  A floppy without it does not degrade, it dies.
cp bin/fgxfar.bin build/KERNELFAR
cadius ADDFILE "$IMG" "/$VOL" build/KERNELFAR >/dev/null
# The tty kernel bank rides along for the same reason, one bank further on.  It
# is optional TODAY -- nothing on the boot path calls into it until the line
# discipline moves there -- and it is added unconditionally anyway, because a
# floppy that boots without it would go on booting the day it stops being
# optional and start failing somewhere else entirely.
cp bin/fgxtty.bin build/KERNELTTY
cadius ADDFILE "$IMG" "/$VOL" build/KERNELTTY >/dev/null
cadius ADDFILE "$IMG" "/$VOL" disk_src/boot >/dev/null

# Checked add: any cadius failure (usually "No enough space") kills the build —
# a silently-partial floppy black-screens the boot.
_add() {
    cadius ADDFILE "$IMG" "$1" "$2" >/dev/null 2>&1 \
        || { rm -f "$IMG"; fail "make_floppy: ADDFILE $2 -> $1 failed (image full?) — image deleted" 2; }
}
_mkdir() { cadius CREATEFOLDER "$IMG" "$1" >/dev/null 2>&1 || true; }

# Stage a single named file from a source dir (fails loudly if absent).
_add_named() {
    local src="$1" pro="$2" name="$3"
    [ -f "$src/$name" ] || { rm -f "$IMG"; fail "make_floppy: essential $pro/$name missing from $src" 2; }
    _add "$pro" "$src/$name"
}

# Recursively populate filesystem dir $1 into ProDOS dir $2, skipping dot/underscore
# files and any basename in the (space-separated) exclude list $3.
_pop() {
    local src="$1" pro="$2" excl=" $3 " e b
    _mkdir "$pro"
    for e in "$src"/*; do
        [ -e "$e" ] || continue
        b="$(basename "$e")"
        case "$b" in _*|.*|*.sample) continue ;; esac
        case "$excl" in *" $b "*) continue ;; esac
        if [ -d "$e" ]; then _pop "$e" "$pro/$b" "$3"
        elif [ -f "$e" ]; then _add "$pro" "$e"; fi
    done
}

# --- BOOT-CRITICAL FIRST (config, fonts, modules, init), /bin LAST -----------
echo_step "Staging /etc, /lib (fonts + modules minus $FLOPPY_MOD_EXCLUDE), /sbin, /bin: $FLOPPY_BIN"
# /etc, minus the files this image REPLACES or has no binary for.  A filtered
# modload.conf and rescue ttys/rc are written below; the network configs go
# because dhclient, inetd and the resolver are not on the disk, and a config
# describing absent software is a false trail for whoever is reading it at 2am.
_pop disk_src/etc "/$VOL/etc" "modload.conf ttys rc rc.in motd netstart inetd.conf dhclient.conf dhcp.lease resolv.conf"

# modload.conf, FILTERED TO WHAT SHIPPED.  Every excluded module's line is
# dropped, matched case-insensitively because the config spells them lowercase
# and the staged files are uppercase (ProDOS).  Built here rather than kept as
# a second checked-in file so it cannot drift from FLOPPY_MOD_EXCLUDE.
# A temp DIRECTORY, not a temp file: cadius ADDFILE names the entry from the
# file's own basename, so the filtered copy has to actually be called
# modload.conf on the way in.
_flop_tmp="$(mktemp -d)"
awk -v excl="$FLOPPY_MOD_EXCLUDE" '
    BEGIN { n = split(tolower(excl), x, " "); for (i = 1; i <= n; i++) drop[x[i]] = 1 }
    { line = $0; sub(/^[ \t]+/, "", line); sub(/[ \t\r]+$/, "", line)
      if (tolower(line) in drop) next
      print }
' disk_src/etc/modload.conf > "$_flop_tmp/modload.conf"
_add "/$VOL/etc" "$_flop_tmp/modload.conf"

# /etc/ttys and /etc/rc, REWRITTEN FOR SINGLE USER.  The shipped ttys runs
# /bin/getty on ttyv1 and ttyv2 and the shipped rc sources /etc/netstart and
# backgrounds /sbin/inetd -- and none of getty, dhclient or inetd is on this
# disk.  Copying them verbatim would boot to a console that works, behind a
# scroll of respawn failures for binaries that were never going to be there.
#
# The console line is `/bin/sh' and not `/bin/getty': that is how the shipped
# ttys already spells the console, so this is the same mechanism with the two
# virtual consoles turned off rather than a special rescue path in init.
cat > "$_flop_tmp/ttys" <<'TTYS'
# FGX rescue floppy -- SINGLE USER.  One console, running the shell directly.
#
# The virtual consoles are off because /bin/getty is not on this disk, and
# neither is /bin/login: a rescue disk that asks for a password you may be
# here to reset is a rescue disk that has failed.
#
# name  getty              type    status
console /bin/sh            vt100   on secure
ttyv1   none               vt100   off secure
ttyv2   none               vt100   off secure
ttyv3   none               vt100   off secure
ttyp0   none               fgxpty  off secure
ttyp1   none               fgxpty  off secure
TTYS
_add "/$VOL/etc" "$_flop_tmp/ttys"

cat > "$_flop_tmp/rc" <<'RCF'
# FGX rescue floppy -- rc.  Deliberately almost empty.
#
# No `. /etc/netstart' and no `/sbin/inetd &': there is no network on this
# disk.  Nothing here should be able to fail, because a rescue boot that stops
# in rc has removed the one thing you booted it for.
cat /etc/motd
RCF
_add "/$VOL/etc" "$_flop_tmp/rc"

# A motd that says what this disk is and what it does NOT have, because the
# first thing you do on a rescue disk is find out what you are holding.
cat > "$_flop_tmp/motd" <<'MOTD'
FGX rescue floppy -- single user, no network.

  ed(1)   edit a file          ls, cat  look at one
  rm(1)   delete a file        sync(1)  commit writes BEFORE ejecting

No cp: use `cat src > dst'.  No mkdir, no mount (mount(2) is not
implemented yet).  The hard disk is mounted by the kernel at boot; if
it is not in `ls /', the kernel could not read it.
MOTD
_add "/$VOL/etc" "$_flop_tmp/motd"
rm -rf "$_flop_tmp"

_mkdir "/$VOL/lib"
_mkdir "/$VOL/lib/fonts"
for fnt in $FLOPPY_FONTS; do _add_named disk_src/lib/fonts "/$VOL/lib/fonts" "$fnt"; done
_pop disk_src/lib/modules "/$VOL/lib/modules" "$FLOPPY_MOD_EXCLUDE"

_mkdir "/$VOL/sbin"
for b in $FLOPPY_SBIN; do _add_named disk_src/sbin "/$VOL/sbin" "$b"; done

# Empty runtime dirs the system expects to exist.
_mkdir "/$VOL/var"; _mkdir "/$VOL/var/log"; _mkdir "/$VOL/var/tmp"
_mkdir "/$VOL/tmp"

# /root: created empty (no staged sample); the 1MB /root/ntp sample and
# test cruft stay off the floppy.
_mkdir "/$VOL/root"

_mkdir "/$VOL/bin"
for b in $FLOPPY_BIN; do _add_named disk_src/bin "/$VOL/bin" "$b"; done

# Bake stage 2's block range into the boot sector.  Stage 1 is one sector and
# has no name lookup (UFS 2.2), so it reads stage 2 from a start block and a
# count patched in here -- after the catalog is populated, and fatally if the
# file's blocks are not contiguous.
python3 "$PROJECT_ROOT/tools/bake_stage2.py" --verify disk_src/boot "$IMG" BOOT \
    || { rm -f "$IMG"; fail "make_floppy: bake_stage2 failed -- image deleted" 2; }

# Verify the boot-critical contents actually landed.
CAT=$(cadius CATALOG "$IMG" 2>/dev/null)
for must in INIT DEFAULT.FNT PRODOS sh; do
    printf '%s' "$CAT" | grep -qai "$must" \
        || { rm -f "$IMG"; fail "make_floppy: '$must' missing from the image" 2; }
done

SZ=$(stat -f%z "$IMG" 2>/dev/null || stat -c%s "$IMG")
FREE=$(printf '%s' "$CAT" | grep -aiE 'Free *:' | tail -1)
echo "    $IMG (${SZ} bytes).  $FREE"
