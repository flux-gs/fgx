#!/bin/bash
#==============================================================================
# FGX Build - Common Functions
#==============================================================================

# Project root (works regardless of cwd)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_step()  { echo -e "${GREEN}==>${NC} $1"; }
echo_warn()  { echo -e "${YELLOW}Warning:${NC} $1"; }
echo_error() { echo -e "${RED}Error:${NC} $1" >&2; }

fail() {
    echo_error "$1"
    exit "${2:-1}"
}

require_tool() {
    command -v "$1" >/dev/null 2>&1 || fail "Required tool not found: $1${2:+ ($2)}" 1
}

# Ensure the fcc/fas toolchain is built AND up to date.  `make` rebuilds a
# binary whenever a toolchain source is newer than it, so this catches a STALE
# fcc as well as a missing one -- the old `[ ! -x toolchain/fcc ]` guard caught
# only *missing*, so a toolchain source change silently kept compiling with the
# previously-built fcc.  Memoized so the near-instant "up to date" make runs
# once per build, not once per tool.
#
# toolchain/ is a PLAIN DIRECTORY since the monorepo merge.  The old
# `git submodule update --init` fetch is gone: the sources are simply present in
# the checkout, so there is nothing to fetch and no network dependency in the
# build path.  (That fetch also needed -c protocol.file.allow=always to work at
# all, since git >= 2.38 blocks file:// submodule clones -- CVE-2022-39253.)
_TOOLCHAIN_ENSURED=""
ensure_toolchain() {
    [ -n "$_TOOLCHAIN_ENSURED" ] && return 0
    [ -f "${PROJECT_ROOT}/toolchain/Makefile" ] \
        || fail "ensure_toolchain: toolchain/ is missing or empty -- expected an in-tree directory since the monorepo merge, not a submodule" 2
    make -C "${PROJECT_ROOT}/toolchain" fcc fas \
        || fail "ensure_toolchain: 'make fcc fas' failed" 2
    _TOOLCHAIN_ENSURED=1
}

# Machine-readable output for Claude Code automation
fgx_result() {
    echo "##FGX## $1"
}

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------

# Parse cfg/system.cfg and generate include/config.s
generate_config() {
    local cfg="$PROJECT_ROOT/cfg/system.cfg"
    local out="$PROJECT_ROOT/include/config.s"

    [ -f "$cfg" ] || fail "Config file not found: $cfg" 1

    cat > "$out" << 'HEADER'
;==============================================================================
; FGX Configuration (AUTO-GENERATED from cfg/system.cfg)
; DO NOT EDIT - modify cfg/system.cfg and rebuild
;==============================================================================

HEADER

    # Parse key = value lines, skip comments and blanks
    while IFS= read -r line; do
        # Strip leading/trailing whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        # Skip comments and blank lines
        [[ -z "$line" || "$line" == \#* ]] && continue

        # Split on '='
        local key="${line%%=*}"
        local val="${line#*=}"

        # Trim whitespace
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"
        val="${val#"${val%%[![:space:]]*}"}"
        val="${val%"${val##*[![:space:]]}"}"

        # Convert key: video.bg_color -> CFG_VIDEO_BG_COLOR
        local asm_name
        asm_name=$(echo "CFG_${key}" | tr '[:lower:].' '[:upper:]_')

        printf "%-20s EQU     %s\n" "$asm_name" "$val" >> "$out"

        # For $0RGB color values, also emit _LO (GB byte) and _HI (0R byte)
        if [[ "$val" =~ ^\$0[0-9A-Fa-f]{3}$ ]]; then
            local r g b
            r="${val:2:1}"
            g="${val:3:1}"
            b="${val:4:1}"
            printf "%-20s EQU     \$%s%s\n" "${asm_name}_LO" "$g" "$b" >> "$out"
            printf "%-20s EQU     \$%s%s\n" "${asm_name}_HI" "0$r" >> "$out"
        fi
    done < "$cfg"

    echo "" >> "$out"
    echo ";==============================================================================" >> "$out"
    echo "; END OF AUTO-GENERATED CONFIG" >> "$out"
    echo ";==============================================================================" >> "$out"
}

#------------------------------------------------------------------------------
# generate_etc_version
# Write disk_src/etc/version (plain text + newline) with the git-describe
# version (suffixed with '+' if the working tree is dirty).  Read by
# 'uname -r' via src/userland/uname/uname.c emitfile("/etc/version").
#
# This used to write build/version.s (a Merlin include defining _BS_Banner
# embedded in the kernel banner).  That was removed: a build-variable string
# in the kernel binary perturbs the layout that the listing-scraped W5100
# offset tables (w5100_patchsites.s) depend on — the dirty '+' adds one byte
# and shifts every later U2_* site by 1, so clean vs dirty builds disagreed.
# The version now lives ONLY on disk in /etc/version, keeping the kernel
# byte-stable regardless of git state.
#
# Gitignored (mirrors disk_src/etc/build) so the per-build SHA never churns
# the tree.
#------------------------------------------------------------------------------
generate_etc_version() {
    local out="$PROJECT_ROOT/disk_src/etc/version"
    local ver dirty

    mkdir -p "$PROJECT_ROOT/disk_src/etc"

    # Release-tag provenance (see docs/VERSIONING.md): describe relative to the
    # semver release tags (v*) ONLY, so the local checkpoint tags
    # (pre-*/post-*/ckpt/*) never leak into the version.  Yields "v0.1.0" on a
    # release tag, "v0.1.0-N-gSHA" after it, and a bare short SHA before the
    # first v* tag is reachable.
    ver=$(git -C "$PROJECT_ROOT" describe --tags --match 'v*' --always 2>/dev/null || echo "0000000")

    # Simple working-tree dirty check: tracked changes (unstaged or staged) or
    # any untracked file marks the build dirty with a trailing '+'.  (The prior
    # w5100_patchsites.s pathspec-exclusion hack that lived here is GONE — the
    # root cause it worked around, version-in-kernel, has been removed.)
    if git -C "$PROJECT_ROOT" diff --quiet HEAD -- 2>/dev/null \
       && git -C "$PROJECT_ROOT" diff --quiet --cached HEAD -- 2>/dev/null \
       && [ -z "$(git -C "$PROJECT_ROOT" ls-files --others --exclude-standard 2>/dev/null)" ]; then
        dirty=""
    else
        dirty="+"
    fi

    # Sanitize defensively (describe output is alnum/./-) and clamp length.
    ver=$(printf '%s' "$ver" | LC_ALL=C tr -c 'A-Za-z0-9._/-' '_')
    if [ "${#ver}" -gt 28 ]; then
        ver="${ver:0:28}"
    fi

    printf '%s%s\n' "$ver" "$dirty" > "$out"
}

#------------------------------------------------------------------------------
# Verification functions
#------------------------------------------------------------------------------

verify_kernel() {
    local bin="$PROJECT_ROOT/bin/fgx.bin"

    [ -f "$bin" ] || { echo_error "Kernel binary not found: $bin"; return 1; }

    local size
    size=$(stat -f%z "$bin" 2>/dev/null || stat -c%s "$bin")

    [ "$size" -gt 256 ] || { echo_error "Kernel too small: $size bytes"; return 1; }
    # Ceiling = FGX_CODE..FGX_DATA boundary = $02EC40 - $020B00 = $E140 = 57664 B.
    # FGX_CODE lowered $022000 → $021000 (2026-06-09 reclaim), then $021000 → $020B00
    # (2026-07-22 pty+fork: reclaim task-table padding below code).  FGX_DATA bumped
    # $02E700 → $02EC40 in the same change (see include/kernel.s for the geometry).
    # Raise this in lockstep with FGX_CODE/FGX_DATA in include/kernel.s + the
    # fgx.link.s ORG + stage2 KERNEL_DEST/_LO (the ERR guards in memmap.s enforce that
    # FGX_DATA's content still fits below $02FE00).
    [ "$size" -le 57968 ] || { echo_error "Kernel too large: $size bytes (exceeds FGX_DATA boundary $02ED70, max 57968)"; return 1; }

    local sig
    sig=$(xxd -l 2 -p "$bin")
    [ "$sig" = "18fb" ] || echo_warn "Unexpected first bytes: $sig (expected 18fb = CLC; XCE)"

    echo "    Kernel OK: $size bytes, signature $sig"
    return 0
}

verify_disk() {
    # Verify the image the caller actually BUILT, not a hardcoded path.  This
    # was pinned to disk/fgx.po, so a release/alternate build (mkimage.sh sets
    # DISK_IMAGE_OVERRIDE -> make_disk.sh's DISK_IMAGE) verified the *test*
    # image instead of its own output: vacuous on a warm tree, and a hard
    # failure in a clean one where disk/fgx.po was never built (CI job 479,
    # `ninja release` -- which never builds the test image).
    local img="${DISK_IMAGE:-disk/fgx.po}"
    case "$img" in /*) ;; *) img="$PROJECT_ROOT/$img" ;; esac

    [ -f "$img" ] || { echo_error "Disk image not found: $img"; return 1; }

    local size expected
    # cadius "32767KB" -> 33553408 bytes = 65534 blocks.  Overridable so an
    # alternate-size build can still verify; keep in sync with make_disk.sh
    # DISK_SIZE.  It is NOT 33554432 (65536 blocks): the ProDOS/SmartPort block
    # count is 16-bit, so 65536 wraps to zero and the volume reports itself as
    # an empty drive.  apple/fgx#80.
    expected="${EXPECTED_DISK_SIZE:-33553408}"
    size=$(stat -f%z "$img" 2>/dev/null || stat -c%s "$img")
    [ "$size" -eq "$expected" ] || { echo_error "Disk image wrong size: $size (expected $expected)"; return 1; }

    local boot_sig
    boot_sig=$(xxd -s 0 -l 2 -p "$img")
    [ "$boot_sig" = "0180" ] || { echo_error "Boot block signature wrong: $boot_sig (expected 0180)"; return 1; }

    # Verify KERNEL is in the ProDOS catalog as a regular file
    if ! cadius CATALOG "$img" 2>/dev/null | grep -q 'KERNEL'; then
        echo_error "KERNEL not found in ProDOS catalog"
        return 1
    fi

    # Phase 6: verify disk_src was populated
    if [ -d "$PROJECT_ROOT/disk_src" ]; then
        if ! cadius CATALOG "$img" 2>/dev/null | grep -qi 'bin'; then
            echo_warn "bin directory not found in ProDOS catalog"
            return 3
        fi
    fi

    echo "    Disk OK: $size bytes, boot=$boot_sig, KERNEL in ProDOS catalog"
    return 0
}

#------------------------------------------------------------------------------
# build_userbin <name>
# Build a userland binary from src/userland/<name>/<name>.link.s.
# Output: bin/<name>.bin (placed at PROJECT_ROOT/bin/).
# Cleans up Merlin32's _Output.txt artifact.
#------------------------------------------------------------------------------
build_userbin() {
    local name="$1"
    local src_dir="src/userland/${name}"
    local out_name="${name}"
    local link_file="${name}.link.s"

    [[ -d "${src_dir}" ]] || fail "build_userbin: ${src_dir} does not exist" 2

    echo_step "Building user binary '${name}'..."
    (
        cd "${src_dir}"
        merlin32 -V "${link_file}" >/dev/null 2>&1 \
            || { echo_error "build_userbin: merlin32 failed on ${link_file}"; exit 2; }
        [[ -f "${out_name}" ]] || { echo_error "build_userbin: expected output '${out_name}' missing"; exit 2; }
    ) || exit $?

    mv "${src_dir}/${out_name}" "bin/${name}.bin" \
        || fail "build_userbin: cannot move output to bin/" 2
    # Move the Merlin -V listing into build/ so check_mx can audit it, and
    # record it in the MX-audit manifest — build.sh audits EXACTLY the
    # hand-asm listings this run produced.  (The old hardcoded list in
    # build.sh went stale as tools flipped to C: fresh CI trees missed
    # never-produced FGX1 listings — FileNotFoundError on CI — while
    # local trees silently audited multi-day-old leftovers.)
    mkdir -p build
    if [[ -f "${src_dir}/_Output.txt" ]]; then
        mv "${src_dir}/_Output.txt" "build/userbin_${name}_Output.txt"
        echo "build/userbin_${name}_Output.txt" >> build/mx_audit.list
    fi
    rm -f "${src_dir}/"*_Output.txt 2>/dev/null
    echo "    Built bin/${name}.bin"
}

#------------------------------------------------------------------------------
# build_host_yacc
# Build the 2.11BSD yacc as a HOST tool (tools/yacc/yacc).  Sources are the
# VENDORED, committed copies under tools/yacc/src (y{1..4}.c + dextern, verbatim
# 2.11BSD; the examples/ reference tree is local-only and absent in CI) compiled
# in a build/ scratch dir alongside a generated `files` whose PARSER define
# points at our committed skeleton tools/yacc/yaccpar.  clang + K&R downgrade
# flags.  See tools/yacc/ and docs/PROVENANCE.md.
#------------------------------------------------------------------------------
build_host_yacc() {
    local hostdir="${PROJECT_ROOT}/build/yacc_host"
    local srcdir="${PROJECT_ROOT}/tools/yacc/src"
    local skel="${PROJECT_ROOT}/tools/yacc/yaccpar"
    [[ -f "${skel}" ]] || fail "build_host_yacc: skeleton ${skel} missing" 2
    [[ -f "${srcdir}/y1.c" ]] || fail "build_host_yacc: 2.11BSD yacc sources missing at ${srcdir}" 2
    echo_step "Building host yacc (2.11BSD) -> tools/yacc/yacc..."
    mkdir -p "${hostdir}"
    cp "${srcdir}/y1.c" "${srcdir}/y2.c" "${srcdir}/y3.c" "${srcdir}/y4.c" \
       "${srcdir}/dextern" "${hostdir}/" \
        || fail "build_host_yacc: cannot copy 2.11BSD yacc sources" 2
    # PARSER -> our skeleton (absolute path, baked per-checkout; binary gitignored).
    printf '#define PARSER "%s"\n#define MEDIUM\n' "${skel}" > "${hostdir}/files"
    # The 2.11BSD yacc is K&R C.  Recent CLANG promotes several K&R patterns to
    # hard errors (return-mismatch, int-conversion, implicit-int/-func-decl) that
    # -w does NOT suppress, so we must downgrade them with -Wno-error=<name>.  But
    # those -W names don't exist on GCC, which rejects the flag outright (the CI image).
    # Probe each so the build is compiler-portable: keep only flags `cc` accepts
    # (clang -> all; gcc -> none, and -std=gnu89 -w already keeps K&R as warnings).
    local krflags=""
    local f
    for f in -Wno-error=return-mismatch -Wno-error=int-conversion \
             -Wno-error=implicit-function-declaration -Wno-error=implicit-int; do
        if printf 'int main(void){return 0;}\n' | cc "${f}" -std=gnu89 -fsyntax-only -x c - 2>/dev/null; then
            krflags="${krflags} ${f}"
        fi
    done
    # shellcheck disable=SC2086
    cc -std=gnu89 -w ${krflags} \
       -o "${PROJECT_ROOT}/tools/yacc/yacc" \
       "${hostdir}/y1.c" "${hostdir}/y2.c" "${hostdir}/y3.c" "${hostdir}/y4.c" \
        || fail "build_host_yacc: cc failed building host yacc" 2
    echo "    Built tools/yacc/yacc (host)"
}

#------------------------------------------------------------------------------
# build_userbin_fgx2 <name>
# Build a multi-segment FGX2 userland binary via toolchain/src/ld/fgx_ld.py.
# Source layout in src/userland/<name>/:
#   - seg0.s + seg0.link.s, seg1.s + seg1.link.s, ...   (per-segment Merlin)
#   - <name>.json                                       (linker manifest)
# Output: bin/<name>.bin.  Per-segment listings land in
# build/userbin_<name>_seg<N>_Output.txt for the MX-leak audit.
#------------------------------------------------------------------------------
build_userbin_fgx2() {
    local name="$1"
    local src_dir="src/userland/${name}"
    local manifest="${name}.json"

    [[ -d "${src_dir}" ]] || fail "build_userbin_fgx2: ${src_dir} does not exist" 2
    [[ -f "${src_dir}/${manifest}" ]] || fail "build_userbin_fgx2: ${src_dir}/${manifest} missing" 2

    echo_step "Building FGX2 user binary '${name}'..."
    mkdir -p build
    (
        cd "${src_dir}"
        local link
        local found=0
        for link in seg*.link.s; do
            [[ -f "${link}" ]] || continue
            found=1
            local segname="${link%.link.s}"
            merlin32 -V "${link}" >/dev/null 2>&1 \
                || { echo_error "build_userbin_fgx2: merlin32 failed on ${link}"; exit 2; }
            [[ -f "${segname}" ]] || { echo_error "build_userbin_fgx2: expected '${segname}' missing"; exit 2; }
            # Merlin overwrites _Output.txt per invocation; rename to
            # <seg>.lst so the linker can read each segment's listing for
            # xref auto-derivation.
            [[ -f _Output.txt ]] && mv _Output.txt "${segname}.lst"
        done
        [[ "${found}" -eq 1 ]] || { echo_error "build_userbin_fgx2: no seg*.link.s files in ${src_dir}"; exit 2; }

        python3 "${PROJECT_ROOT}/toolchain/src/ld/fgx_ld.py" "${manifest}" \
            || { echo_error "build_userbin_fgx2: fgx_ld.py failed on ${manifest}"; exit 2; }

        # After linking, move each segment's listing to build/ for the
        # MX-leak audit and clean up header-less segment intermediates.
        local seg
        for seg in seg[0-9]; do
            [[ -e "${seg}" ]] && rm -f "${seg}"
        done
        local lst
        for lst in seg*.lst; do
            [[ -f "${lst}" ]] || continue
            local segname="${lst%.lst}"
            mv "${lst}" "${PROJECT_ROOT}/build/userbin_${name}_${segname}_Output.txt"
        done
    ) || exit $?

    [[ -f "${src_dir}/${name}" ]] || fail "build_userbin_fgx2: ${src_dir}/${name} missing after link" 2
    mv "${src_dir}/${name}" "bin/${name}.bin" \
        || fail "build_userbin_fgx2: cannot move output to bin/" 2

    echo "    Built bin/${name}.bin"
}

#------------------------------------------------------------------------------
# build_module <name>
# Build an FGXM module from src/modules/<name>/<name>.link.s.
# Output: disk_src/lib/modules/<NAME> (uppercase, for ProDOS).
# Cleans up Merlin32's _Output.txt artifact.
#------------------------------------------------------------------------------
build_module() {
    local name="$1"
    local src_dir="src/modules/${name}"
    local out_name="${name}"
    local link_file="${name}.link.s"
    local upper_name
    upper_name=$(echo "${name}" | tr '[:lower:]' '[:upper:]')

    [[ -d "${src_dir}" ]] || fail "build_module: ${src_dir} does not exist" 2

    echo_step "Building module '${name}'..."
    (
        cd "${src_dir}"
        merlin32 -V "${link_file}" >/dev/null 2>&1 \
            || { echo_error "build_module: merlin32 failed on ${link_file}"; exit 2; }
        [[ -f "${out_name}" ]] || { echo_error "build_module: expected output '${out_name}' missing"; exit 2; }
    ) || exit $?

    mkdir -p disk_src/lib/modules
    mv "${src_dir}/${out_name}" "disk_src/lib/modules/${upper_name}" \
        || fail "build_module: cannot move output to disk_src/lib/modules/" 2

    mkdir -p build
    if [[ -f "${src_dir}/_Output.txt" ]]; then
        mv "${src_dir}/_Output.txt" "build/module_${name}_Output.txt"
    fi
    rm -f "${src_dir}/"*_Output.txt 2>/dev/null
    echo "    Built disk_src/lib/modules/${upper_name}"
}

#------------------------------------------------------------------------------
# build_standalone <name>
# Build a standalone bootable binary from src/standalone/<name>/<name>.link.s.
# Output: build/<name>.bin (placed at PROJECT_ROOT/build/).
# Cleans up Merlin32's _Output.txt artifact.
#
# Standalones are NOT modules and NOT user binaries — they replace the
# kernel on a dedicated test disk image.  See cmd_sim_test().
#------------------------------------------------------------------------------
build_standalone() {
    local name="$1"
    local src_dir="src/standalone/${name}"
    local out_name="${name}"
    local link_file="${name}.link.s"

    [[ -d "${src_dir}" ]] || fail "build_standalone: ${src_dir} does not exist" 2

    echo_step "Building standalone '${name}'..."
    (
        cd "${src_dir}"
        merlin32 -V "${link_file}" >/dev/null 2>&1 \
            || { echo_error "build_standalone: merlin32 failed on ${link_file}"; exit 2; }
        [[ -f "${out_name}" ]] || { echo_error "build_standalone: expected output '${out_name}' missing"; exit 2; }
    ) || exit $?

    mkdir -p build
    mv "${src_dir}/${out_name}" "build/${name}.bin" \
        || fail "build_standalone: cannot move output to build/" 2
    if [[ -f "${src_dir}/_Output.txt" ]]; then
        mv "${src_dir}/_Output.txt" "build/${name}_Output.txt"
    fi
    rm -f "${src_dir}/"*_Output.txt 2>/dev/null
    echo "    Built build/${name}.bin"
}
