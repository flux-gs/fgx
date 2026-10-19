#!/usr/bin/env bash
#==============================================================================
# make_ufsboot.sh -- build a bootable 2.11BSD volume carrying the boot chain.
#
# UFS campaign 2.3.  Stage 2 grows a UFS reader beside its ProDOS one, and a
# reader with nothing to read is not a deliverable: this is the volume it reads.
#
# THE BOOT CHAIN IS THREE FILES NOW -- /boot, /fgxunix and /etc/boot.conf.
# It was eight: stage 2, three kernel banks, three modules and the
# preload.conf that named them.  /fgxunix carries all six segments in one
# image, the way 2.11BSD ships one /unix (see tools/mkfgxunix.py).
#==============================================================================
set -u
cd "$(cd "$(dirname "$0")/.." && pwd)"
. lib/build_common.sh 2>/dev/null || true

IMG="${1:-disk/fgxufs.po}"
BLOCKS="${UFSBOOT_BLOCKS:-32000}"       # 1 KB filesystem blocks -> ~32 MB

FGXFS="python3 tools/fgxfs.py"
BAKE="python3 tools/bake_stage2.py"

for f in build/loader_padded.bin disk_src/boot bin/fgxunix \
         disk_src/etc/boot.conf; do
    [ -f "$f" ] || { echo "make_ufsboot: missing $f -- run ninja first" >&2; exit 2; }
done

_put() {   # _put <src> <path-on-volume>
    $FGXFS put "$IMG" "$1" "$2" >/dev/null \
        || { echo "make_ufsboot: put $1 -> $2 failed" >&2; exit 2; }
}

rm -f "$IMG"
$FGXFS mkfs "$IMG" --size "$BLOCKS" >/dev/null \
    || { echo "make_ufsboot: mkfs failed" >&2; exit 2; }

# STAGE 2 GOES DOWN FIRST, AND THAT IS NOT COSMETIC.  Stage 1 holds at most
# S2MAX device blocks' worth of block numbers, so putting /boot down before
# anything else keeps its extent stable as the rest of the volume changes -- a
# bake failure then points at stage 2's size and not at whatever was added
# last.
_put disk_src/boot /boot

# THE KERNEL, AS ONE FILE.  It is `/fgxunix' in lower case, unlike the
# /KERNEL, /KERNELFAR and /KERNELTTY it replaces: those kept a ProDOS spelling
# because /etc/boot.conf named /KERNEL and the ProDOS image still had to find
# them.  A 2.11BSD name is bytes, this file exists only on this volume, and
# the thing it is named after is `/unix'.
_put bin/fgxunix /fgxunix

# THE REST OF THE TREE, STAGED VERBATIM AND THEREFORE IN ITS REAL CASE.
#
# This is the one place the two filesystems genuinely disagree.  ProDOS stores
# a directory name in UPPERCASE and carries the display case in the version
# bytes, so stage 2's ProDOS walker compares uppercase and the userland's
# lowercase paths match case-INSENSITIVELY underneath.  2.11BSD names are
# bytes, and `etc' is not `ETC'.  Staging disk_src verbatim is what makes
# /bin/sh and /etc/rc work under UFS; it is also why stage 2 carries a second
# set of path strings for its own boot-time files.
if [ -d disk_src ]; then
    _populate() {
        local src="$1" pro="$2" base entry
        for entry in "$src"/*; do
            [ -e "$entry" ] || continue
            base=$(basename "$entry")
            # CASE-INSENSITIVELY, because a stale lowercase
            # `_fileinformation.txt' from an older tool sat untracked in
            # disk_src/root and slipped past the exact-case test -- and
            # `ls -l /root' then reported `_fileinformatio not found',
            # the name being 20 characters where a 2.11BSD directory
            # entry holds 14.
            case "$(printf '%s' "$base" | tr 'A-Z' 'a-z')" in
                _fileinformation.txt) continue ;;
            esac
            case "$base" in .*) continue ;; esac
            # DOT.NAME IS A ProDOS SPELLING, NOT A NAME.  ProDOS cannot store a
            # leading dot, so `.profile' ships in the tree as `DOT.PROFILE' and
            # the FST maps it both ways (prodos.s:847 in readdir, :2290 on the
            # way in).  2.11BSD needs no such trick and does no such mapping, so
            # staging the ProDOS spelling verbatim puts a file on the volume
            # that nothing ever opens: /bin/sh asks for ".profile" byte-exactly
            # (vendor/2.11BSD/usr/bin/sh/msg.c:70), never finds it, and keeps
            # the Bourne built-in "# " prompt instead of this tree's `fgx# '.
            # That is what made the harness unable to see a UFS shell at all.
            # The guard matches the FST's: the exact "DOT." prefix and at least
            # one character after it, so a genuine DOTTY is left alone.
            case "$base" in
                DOT.?*) base=".$(printf '%s' "${base#DOT.}" | tr 'A-Z' 'a-z')" ;;
            esac
            if [ -d "$entry" ]; then
                $FGXFS mkdir "$IMG" "$pro/$base" >/dev/null \
                    || { echo "make_ufsboot: mkdir $pro/$base failed" >&2; exit 2; }
                _populate "$entry" "$pro/$base"
            elif [ -f "$entry" ]; then
                # /boot is already down, first, on purpose.
                [ "$pro/$base" = "/boot" ] && continue
                # ProDOS METADATA IS NOT A FILE ON A UFS VOLUME.  mkimage.sh
                # GENERATES _FileInformation.txt per directory to carry ProDOS
                # type/auxtype and skips it when staging; nothing skipped it
                # here, so every directory on the volume carried one -- and
                # `ls -l /root' reported `_fileinformatio not found', because
                # the name is 20 characters and a 2.11BSD directory entry holds
                # 14.  .gitkeep is excluded for the same reason it is there:
                # it exists to make git keep an empty directory.
                case "$base" in _FileInformation.txt|.gitkeep) continue;; esac
                _put "$entry" "$pro/$base"
            fi
        done
    }
    # /etc/rc IS GENERATED, and this image has to generate it too.  mkimage.sh
    # writes it from rc.in for the ProDOS variants (all three copy it verbatim);
    # nothing wrote it for this one, so the volume shipped whatever the last
    # ProDOS build happened to leave on disk -- or nothing at all in a tree that
    # has only ever built the UFS image.  apple/fgx#315.
    [ -f disk_src/etc/rc.in ] && cp disk_src/etc/rc.in disk_src/etc/rc

    # /etc/version AND /etc/build ARE GENERATED HERE TOO, at image time from git
    # state and the clock -- `uname -r' and `uname -v' read them, and so does
    # the kernel.  They cannot be graph outputs: nothing depends on a file for
    # them.  Nothing else writes them, so without these lines a warm tree ships
    # whatever an earlier build left in disk_src/etc and a clean checkout (CI)
    # ships neither (apple/fgx#455).
    #
    # /etc/version -- release-tag provenance, '+' if the tree is dirty.  Matched
    # against v* tags ONLY so local checkpoint tags never leak into the version.
    _ver=$(git describe --tags --match 'v*' --always 2>/dev/null || echo 0000000)
    if git diff --quiet HEAD -- 2>/dev/null \
       && git diff --quiet --cached HEAD -- 2>/dev/null \
       && [ -z "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
        _dirty=""
    else
        _dirty="+"
    fi
    _ver=$(printf '%s' "$_ver" | LC_ALL=C tr -c 'A-Za-z0-9._/-' '_')
    printf '%s%s\n' "${_ver:0:28}" "$_dirty" > disk_src/etc/version

    # /etc/build -- the uname -v source; the KERN_VERSION / newvers.sh analog.
    _branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')
    [ "$_branch" = HEAD ] && _branch=detached
    printf '%s %s %s\n' "$_ver" "$_branch" "$(date '+%Y-%m-%d')" > disk_src/etc/build

    _populate disk_src ""
fi

# /dev IS PART OF THE ROOT, NOT A VOLUME OF ITS OWN -- UFS campaign 2.5.
#
# The nodes come from build/dev_nodes.list, which tools/ninja/gen.py writes
# from the SAME DEV_NODES list that builds disk/fgxdev.po and the kernel's
# dev_nodes.c.  Retyping them here would be the disagreement dev_nodecheck
# exists to catch, and one nobody could see until a device node opened the
# wrong driver.
#
# THE ProDOS ROOT CANNOT CARRY THESE, which is why the separate /dev volume
# stays for now: a ProDOS volume has no inode to hold a device number.  A
# machine booting that image still mounts /dev; a machine booting this one
# finds it in its own root and the mount has nothing left to do.
DEVLIST=build/dev_nodes.list
[ -r "$DEVLIST" ] || { echo "make_ufsboot: $DEVLIST missing" >&2; exit 2; }
while read -r kind path dev mode; do
    case "$kind" in
        ''|'#'*) continue ;;
        d) $FGXFS mkdir "$IMG" "$path" >/dev/null \
               || { echo "make_ufsboot: mkdir $path failed" >&2; exit 2; } ;;
        c|b) $FGXFS mknod "$IMG" "$path" "$kind" "$dev" "$mode" >/dev/null \
               || { echo "make_ufsboot: mknod $path failed" >&2; exit 2; } ;;
        l) $FGXFS symlink "$IMG" "$dev" "$path" >/dev/null \
               || { echo "make_ufsboot: symlink $path failed" >&2; exit 2; } ;;
        h) $FGXFS link "$IMG" "$dev" "$path" >/dev/null \
               || { echo "make_ufsboot: link $path failed" >&2; exit 2; } ;;
        # `o' IS A chown: the dev column is the uid and the mode column the
        # gid.  Nothing else on this volume needs one -- every other inode
        # belongs to root and should -- but a home directory its user cannot
        # write in is not a home, and there is no chown(8) to call at this
        # point: the machine has never booted.
        o) $FGXFS chown "$IMG" "$path" "$dev" "$mode" >/dev/null \
               || { echo "make_ufsboot: chown $path failed" >&2; exit 2; } ;;
        *) echo "make_ufsboot: $DEVLIST: bad type '$kind'" >&2; exit 2 ;;
    esac
done < "$DEVLIST"

# A DOUBLE-INDIRECT FILE, for the truncate path that has never executed.
# NDADDR is 4 and NINDIR is 256, so the single indirect covers blocks 4..259
# and block 260 is the first the DOUBLE indirect addresses.  At 300 blocks this
# file owns 303: 300 data, one single indirect, one double, and one sub-index
# under the double.  apple/fgx#159 is the truncate half of that and apple/fgx
# #193 is the coverage gap it sits in -- "no UFS probe case reaches
# ufs_indirtrunc at recursion level 1 or 2".
#
# IT IS MADE BY mkfile RATHER THAN WRITTEN ON TARGET, and that is not a
# shortcut: 300 KB of 512-byte writes through the vnode path is minutes of
# guest time (bigread greps 48 KB in 127), and the subject here is the TRUNCATE
# and not the write.  The content is a function of the logical block number, so
# a reader that returns the right bytes from the wrong block is still caught.
$FGXFS mkfile "$IMG" /root/big300 --blocks 300 >/dev/null \
    || { echo "make_ufsboot: mkfile /root/big300 failed" >&2; exit 2; }

# Sector 0 is stage 1; sector 1 is the disklabel's and is left alone.
dd if=build/loader_padded.bin of="$IMG" bs=512 count=1 seek=0 conv=notrunc 2>/dev/null

$BAKE --ufs --verify disk_src/boot "$IMG" /boot || exit 2

# The oracle judges the volume this script wrote, not the script's own account
# of it.  A boot image that does not fsck clean is not one worth booting.
$FGXFS fsck "$IMG" || { echo "make_ufsboot: fsck refused the image" >&2; exit 2; }
echo "    $IMG ($BLOCKS blocks)"
