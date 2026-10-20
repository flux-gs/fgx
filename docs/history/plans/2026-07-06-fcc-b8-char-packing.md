# B-8 audit: scalar char struct members 2-byte-slot → 1-byte packing

*2026-07-06. Probe-verified (host fcc) + two exhaustive sweeps (fcc layout
sites; codebase dependency inventory). Precedes the implementation.*

## Target layout (PDP-11 / 2.11BSD convention — BSD-port-shaped)

- scalar `char`/`unsigned char` members: **1 byte, align 1** (today: 2/2)
- `short`/`int`/`long`/`float`/pointers/nested structs: even-aligned (unchanged)
- char arrays: byte-packed (already true)
- struct total size: rounded up to even (already true — **keep**: the
  word-copy loops in `emit_struct_copy`/`emit_struct_byval_arg` require it)
- unions/bitfields: unchanged (union arm at 0 sized by max; bitfields use a
  self-aligning 2-byte int container)

Consequence: **only runs of 2+ adjacent scalar chars change layout.**
`{char;int}` stays 4 (int re-aligns), `{int;int;char}` stays 6 (even round),
`char name[15]` member stays 16. `{char;char}` goes 4→2.

## fcc-side: the whole rule is ONE site

- `parse_stmt.c:169` — `case LT_CHAR: align = 2; size = 2;` → `1; 1`.
  Offsets assigned at `:208-211` (align-round + bump); total at `:220`
  (`(cur+1)&~1` — the even round, keep).
- **Latent gap to fix in the same change:** fn-ptr struct fields
  (`parse_stmt.c:55` and `:79`) append at raw `cur` with NO alignment —
  today masked because chars keep `cur` even; after packing, a char before
  a fn-ptr field would land the 4-byte pointer at an odd offset. Align
  `cur` to even in both paths.
- Everything else is derived and follows automatically (probe- and
  sweep-verified): member access codegen is already byte-correct (8-bit
  SEP stores; 16-bit loads masked `AND #$00FF`); the M22 init-list emitter
  pads by `byte_offset` and already emits chars as 1 byte; array stride =
  `(total_size+1)&~1` via `elem_size_for`; address-of/nested chains sum
  `byte_offset`; no MVN anywhere in struct copies; no `offset>>1` math;
  DP-IMG promotion never touches members; peephole layout-blind.
- `sizeof(char)`==1 and char stride==1 already. (Separate pre-existing
  quirk, NOT touched: `sizeof` of a soft-stack LOCAL char array returns
  `slot_count*2`.)

## Codebase blast radius: **zero wire structs change**

Every ABI/boundary struct was already built to dodge the 2-byte slot:
`stat`/`winsize`/`timeval` (short/long only), `sgttyb`/`tchars`
(deliberately all-`short` to match the kernel's 10/12-byte images),
`statfs`/`procinfo` (char *arrays*), `sockaddr_in`/`ifreq` (raw byte
buffers with macro offsets). None contain a scalar char.

**THE TRAP (for future sessions): do NOT "modernize" the all-short ABI
structs to char after the flip.** The kernel images (`TTY_Sgttyb`,
`TTY_Tchars`) are still shorts; `sgttyb` as 5 chars would be 6 bytes and
silently mismatch. The shorts stay. Likewise `sockaddr_in`/`ifreq` stay
raw buffers (fcc still even-aligns words, so a struct still can't
reproduce fully-packed wire layouts).

Layout actually moves in exactly five places, all benign:
- `sed` `struct reptr1/reptr2` (30→26; the A/B pun has identical field
  sequences — stays consistent) and `ul` `struct CHAR` (4→2): internal,
  recompile-consistent.
- multibank fixtures `c11_structcpy` (12→6), `c04_field` (8→4),
  `c22_chainfield` (8→4): value-asserted, stay green; comments stale.

No golden/runtime test asserts a changing number — `M8/struct_def.c`
returns `sizeof(struct{int;int;char})*7` and 6*7=42 holds either way.

## Implementation plan

1. Red-first fixture `tests/M32/charpack.c` (or next M): asserts the NEW
   layout — `sizeof(struct{char;char;})==2`, `{char;char;char}`==4,
   `{char;int}`==4, adjacency write/read (poison-checked), brace-init by
   field, array-of-struct stride, by-value arg, char-before-fn-ptr-field
   alignment. RED today.
2. Flip `parse_stmt.c:169` + align fn-ptr field paths (`:55`, `:79`).
3. Gates: fixture green; goldens mass-regen (`tests/regen_goldens.sh`
   AFTER behavior-green); runtime 338; multibank sweep 34/34
   (`parse_stmt.c` is an MB_FILE ⇒ release with `MULTIBANK_VERIFIED=1`).
4. Comment truth-pass (~9 sites, both repos): `sgtty.h` ×2 copies,
   `socket_h.h`, `ifconfig.c`, `route.c`, `dhclient.c`,
   `c11_structcpy.c`, `M22/struct_sinit.c`; add the do-not-modernize
   warning to the sgtty.h comment.
5. `fcc-known-issues.md`: close B-8. Release toolchain, re-pin FGX.

## Why B-8 matters (recorded rationale)

Silent-wrong for every K&R port with packed char structs; T6 prerequisite
(socket argblk widen wants honest struct layouts); removes the "write your
structs as all-short" tribal rule for new code (existing ABI structs keep
it for image-compat reasons, see the trap above).
