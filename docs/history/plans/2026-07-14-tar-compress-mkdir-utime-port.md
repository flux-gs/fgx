# Port 2.11BSD tar + compress, with ProDOS mkdir/utime kernel support

**Date:** 2026-07-14
**Status:** Design — approved shape, pending spec review
**Source policy:** userland ports take their source from the vendored
`examples/2.11BSD/` tree (standing rule). netbsd-0-9 advisory-only.

## Goal

Port three 2.11BSD userland tools to FGX (C/fcc, no new hand-asm):
`tar`, `compress`, and `zcat`. `zcat`/`uncompress` are the same binary as
`compress` (it branches on `argv[0]`), so this is **two C ports**. `tar`
additionally needs two FS primitives FGX lacks today — directory creation and
mtime setting — which we build in the kernel/ProDOS module per the
toolchain-first rule (no per-tool asm stubs, no reimplementation).

## Scope decisions (settled in brainstorming)

- **tar: file-only, graceful-degrade.** No tape/`rmt`; archive to/from a file or
  stdin/stdout. Regular files + directories fully supported. Unix entry types
  FGX can't represent (symlink, hardlink, device, fifo) → **warn + skip** on
  extract; tar never *emits* them (FGX has none to archive). `chown` → no-op
  (single-user). `chmod` → best-effort ProDOS access. mtime → restored via the
  new `SYS_UTIME`.
- **compress: write BITS=12, decode up to 16.** Compression produces conservative
  12-bit `.Z` files (~30 KB tables, universally readable). Decode handles any
  `maxbits ≤ 16`, allocating the larger decode tables (~192 KB) via `malloc`
  **only** when a high-bits file demands it.
- **Man pages** for `tar` and `compress` (+ `zcat`/`uncompress` aliases), per the
  port policy. Vendored sources exist (`usr/man/man1/{tar,compress}.1`).

## Phasing & sequencing

**1 → 2 → 3.** Phase 1 ships independently and delivers value while the kernel
work for tar proceeds. tar lands last, on top of the new primitives.

---

## Phase 1 — `compress` / `uncompress` / `zcat`

**Source:** `examples/2.11BSD/usr/ucb/compress/compress.c` (1507 lines).

**Shape.** One FGX2 C binary, staged under three names (`compress`, `uncompress`,
`zcat`) exactly like the `tip`/`cu` port. Dispatch on `argv[0]`:
`compress` → compress; `uncompress` → decompress in place; `zcat` → decompress
to stdout.

**Memory model.**
- Compress path: `BITS = 12` → hash table `htab[HSIZE]` (longs) + `codetab[HSIZE]`
  (shorts), ~30 KB, `malloc`'d.
- Decompress path: must honor the input file's stored `maxbits` (byte 2 of the
  `.Z` magic header, `\037\235`). Allocate `tab_prefix[1<<maxbits]` (shorts) +
  `tab_suffix[1<<maxbits]` + the de-stack sized to `maxbits` — up to ~192 KB at
  16 bits — via `malloc`, sized to the *actual* file, not always max.

**libc / syscall surface (all present today):** `open`/`read`/`write`/`close`/
`unlink`/`malloc`/`free`/`stat` (for `-f` force + mtime-preserve on the output).
LZW codes are 32-bit `long` (fcc has long support).

**fcc gaps to watch (fix in fcc if hit, per toolchain-first):** the `getcode`/
`putcode` bit-packing does 32-bit `long` shifts/masks in a hot loop — verify
fcc's long shift/AND codegen; the LZW inner loop stresses `long` array indexing.

**Man:** `compress.1` → catman; note the `zcat`/`uncompress` invocation aliases.

**Tests (headless MAME, closed-loop):**
- Round-trip: `compress` a fixture → `zcat`/`uncompress` back → `cmp` identical.
- Cross-validate (validate-against-reference policy): a host-`compress`'d `.Z`
  (12- and 16-bit) decodes correctly on FGX; an FGX-`compress`'d `.Z` decodes on
  the host.

---

## Phase 2 — `SYS_MKDIR` + `SYS_UTIME` (kernel / ProDOS)

The heavy, ProDOS-specific work concentrates in `prodos.mod`; the FST-agnostic
kernel layers and libc are thin. `_fop_create` is the working template — it
already allocs blocks (`SYS_BMALLOC`/`Bm_Alloc`), builds+persists a dir entry,
knows the dir storage nibbles (`PRO_DIR_NIBBLE $D0`, validation at prodos.s:2813),
and date-stamps new entries (prodos.s:3061, `ReadTimeHex`).

### `SYS_MKDIR` (syscall slot 92)

- **prodos.mod:** new `_fop_mkdir` + a `FOP_MkDir` slot in `prodos_fop_table`.
  Allocate a key block, format it as a ProDOS **subdir header** (storage type
  `$E`; prev/next dir-block links = 0; the `..` backpointer to the parent's key
  block + the parent entry's position; `entry_length=$27`, `entries_per_block=$0D`,
  `file_count=0`, `access=$C3`), then insert a `$D` **subdir entry** into the
  parent (reusing `_fop_create`'s entry-insert path) and bump the parent's
  `file_count`. Date-stamp create+mod = now.
- **fs.s:** `_Fs_Mkdir` wrapper — split path into parent-dir / leaf, then
  `_Fst_Dispatch(FOP_MkDir)`, mirroring `_Fs_Create`/`_Fs_Unlink`.
- **syscall.s + loader.s:** `SYS_MKDIR EQU 92` → `_Fs_Mkdir`.
- **libc:** `mkdir(path, mode)` shim (`mode` accepted, ProDOS has no mode bits so
  it's advisory).
- **`mkdir(1)` tool** (C; `examples/2.11BSD/.../mkdir.c`) + man — gives a direct
  test vector and is generally useful (`-p` optional).

### `SYS_UTIME` (syscall slot 93)

- **prodos.mod:** new `_fop_utime` + `FOP_Utime` slot. Resolve the dir entry,
  write `DE_ModDate`/`DE_ModTime` ($21) from a caller-supplied ProDOS date/time.
  ProDOS has **no atime** — the atime argument is ignored. Reuses `_fop_create`'s
  dir-entry-update + flush path.
- **fs.s:** `_Fs_Utime` wrapper.
- **syscall.s + loader.s:** `SYS_UTIME EQU 93` → `_Fs_Utime`.
- **libc:** `utime(path, struct utimbuf*)` shim. **Conversion risk:** tar stores
  mtime as a Unix `time_t`; the shim must convert `time_t` → broken-down time →
  ProDOS packed date/time words. If FGX libc lacks a `gmtime`/`time_t`-decompose
  helper, that conversion is a small libc addition (do it in libc, not tar). The
  reverse (ProDOS→display) already exists in `date(1)`/RTC code to crib from.

**Tests:** `mkdir /x` then `SYS_OPEN(O_CREAT)` a file inside `/x` + `ls` sees it;
nested `mkdir /a/b`; `utime` a file to a known date → `stat` reads that mtime
back; `mkdir` an existing name → `EEXIST`.

---

## Phase 3 — `tar`

**Source:** `examples/2.11BSD/usr/bin/tar.c` (1424 lines).

**Strip:** all tape/`rmt` handling (`/dev/rmt*`, the tape `ioctl`s, rewind,
multi-volume/EOT prompting, the remote-tape `rmt` protocol). Archive is a file
(`f` + path) or stdin/stdout (`-`).

**Options (safe subset):** `c` create, `x` extract, `t` list, `v` verbose,
`f` file, `w` confirm, `m` don't-restore-mtime, `o` suppress-ownership (already
the FGX default). **Omit** the tape/append flags (`r`/`u` append, blocking-factor)
— out of scope for v1 (see below).

**Extract entry-type handling (graceful-degrade):**
| Entry | Action |
|-------|--------|
| regular file (`\0`/`0`) | `creat`+`write` (existing) |
| directory (`5`, or trailing `/`) | `SYS_MKDIR` (Phase 2) |
| hardlink (`1`) | warn + skip (ProDOS: no hardlinks) |
| symlink (`2`) | warn + skip (FGX: no symlinks) |
| char/block/fifo (`3`/`4`/`6`) | warn + skip |
| — mtime | `utime()` (Phase 2) unless `m` given |
| — ownership | no-op (single-user) |
| — mode | best-effort → ProDOS access (locked/unlocked), else no-op |

**Create side:** archive regular files, recurse directories. Emit `uid=gid=0`,
mode from stat. Never emits symlink/device entries (FGX has none).

**Archive format:** 2.11BSD tar is the old (pre-POSIX/V7-style) 512-byte-header
format — octal fields, header checksum. FGX↔FGX round-trips cleanly; reading a
modern `ustar` archive works for the regular-file + directory subset (the fields
we consume overlap). Not targeting PAX/GNU extensions.

**Man:** `tar.1` → catman.

**Tests:** `tar cf t.tar dir/` → `tar tf` lists → `tar xf` into a fresh tree →
`cmp -r` round-trip (needs Phase 2 mkdir for the dir entries). Cross-validate: a
host-made old-format tar of regular files + dirs extracts on FGX; an FGX-made tar
extracts on the host. A tar containing a symlink extracts the regular members and
warns+skips the symlink (no crash).

---

## Toolchain-first commitments

- Any fcc/libc gap hit during the ports (long shifts/masks in compress, a K&R or
  codegen construct in tar, the `time_t`→ProDOS conversion helper) is fixed in
  **fcc/libc** with a regression fixture — never a per-tool asm stub, local
  reimplementation, or generated-code rewrite.
- `mkdir`/`utime` are **real syscalls** in the kernel + a real ProDOS FOP, not
  worked around in tar.

## Out of scope (v1)

- Symlinks / hardlinks in tar (FGX has neither; the roadmap symlink FS feature is
  a separate initiative).
- Tape / `rmt` / multi-volume / append (`r`/`u`) tar.
- atime (ProDOS has no access-time field).
- compress writing >12 bits; gzip/`.gz` (this is LZW `.Z` only).

## Testing strategy (summary)

All closed-loop, headless MAME, per-test JSON in `tools/mame_test/tests/`.
Round-trip `cmp` for each tool, plus host cross-validation per the
validate-against-a-C-reference policy. Phase 2 gets kernel-primitive probes
(mkdir-then-create, utime-then-stat). No new hand-run steps.
