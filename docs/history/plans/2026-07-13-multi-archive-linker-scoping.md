# Multi-archive linker — scoping & design (2026-07-13)

**Context.** Direction set by the maintainer (2026-07-13, out of the elvis `getkey`
collision fix): keep **libc BSD-correct** (only ISO C / POSIX / BSD names), move
IIgs/FGX-specific functions to **libfgx**, and — during ports — accrete a
**family** of BSD libraries (`libtermcap`, `libcurses`, `libm`, `libutil`, …).
No more monolithic pile. For that, **fgx_ld must learn to link multiple archive
files**. This doc scopes that work. It is a design, not an implementation.

Related: memory `project_fgx_libc_libfgx_split_multiarchive`; the link-time
recursion-trap guard just landed (toolchain 6518eef4) is the standalone
class-closer, independent of this.

---

## 1. Where we are today (grounded)

- **libc is a single whole-pile blob.** `fcc --pile lib/libc_c/libc_c.c ->
  lib/libc_c.s` compiles the *entire* C library into one assembled segment
  (`toolchain/Makefile` target `libc_c`). There is no per-function object and no
  symbol index.
- **Every tool includes the whole pile.** `build_userbin_fgx2_c`
  (`lib/build_common.sh`) generates a 3-segment manifest from `tools/fgx2/*.in`:
  seg0 = tool code, seg1 = tool data, **seg2 = the libc pile** (assembled from
  `libc_c.s`). A tool that calls only `printf` still links all of `socket`,
  `qsort`, `tgetstr`, …. The multibank case (elvis) is the same pile hoisted by
  `gen_elvis_link.py` into its own **KIND=LIBC** segment, shared emit-once across
  the code banks (T5-A).
- **The linker is manifest-driven, not archive-driven.** `fgx_ld.py` reads a
  JSON manifest that already *names every segment to include*. It scans each
  segment's Merlin `-V` listing for exports/imports/relocs, resolves imports
  (per-segment for `FGX2_IMPORT`, globally via `resolve_precedence` for
  `FGX2_FARCALL`/`FGX2_LONG_PTR`), lays out banks, and emits one FGX2/FGX3
  binary. **The manifest author — not the linker — decides what libc code is
  in.** There is no on-demand extraction and no `-l` concept.
- **Weak/strong (A1) already emulates the one useful archive property:** a
  strong (non-LIBC) definition preempts the weak (KIND=LIBC) pile export
  (`resolve_precedence`, fgx_ld.py:502). That is BSD "user .o beats libc.a" —
  but done over a *whole* pile, not per member.

**Net:** the collision-safety and namespace goals need only *library-level*
separation; true size-reducing dead-strip needs *member-level* extraction. These
are two different amounts of work and worth phasing.

---

## 2. What "link multiple archives" actually requires

Classic Unix `ld` archive linking is:

1. Always include the **root objects** (the tool's own `.o`s).
2. Collect the root's **undefined symbols**.
3. Walk the library list **in order** (`-lc -lfgx -ltermcap …`). For each
   archive: repeatedly scan its members; pull any member that **defines a
   currently-undefined symbol**; a pulled member adds its own undefineds; iterate
   until the archive yields no new pull, then move on.
4. Any symbol still undefined at the end → **link error**.

Two ingredients FGX lacks: **(a) an archive format with a symbol index**
(name → member), and **(b) the on-demand extraction loop**. Everything else
(bank layout, reloc emission, emit-once sharing, the D1/MODE gates) already
exists and is reused unchanged.

---

## 3. Design

### 3.1 Archive format
An archive is a directory (or a single indexed file) of **members**, each member
a compiled unit with a listing + bin (exactly today's per-segment shape), plus a
**symbol index**: `{ exported_symbol -> member_id }` (the `ranlib`/`__.SYMDEF`
analogue). Members carry their imports in their listing (already scanned). Build
it by teaching the libc build to emit per-member objects + an index instead of
one `--pile` blob (see granularity §4).

Concretely for FGX: `libc.fgxa` = `{ index.json, m000.bin/.lst, m001.bin/.lst, … }`.
`index.json` maps each exported name to its member and records the member's
imports (so extraction doesn't have to re-scan every member up front).

### 3.2 Manifest change
The tool manifest stops hand-listing the pile. Instead:
```
{ "output": "...", "segments": [ <root code>, <root data> ],
  "libs": ["libc", "libfgx"],            # search order
  "libpath": ["toolchain/lib"], ... }
```
`fgx_ld` resolves `libs` to `.fgxa` archives on `libpath`.

### 3.3 Extraction loop (the core, in fgx_ld)
- Seed `undef` from the root segments' imports (FGX2_IMPORT / FGX2_FARCALL /
  FGX2_LONG_PTR targets not defined by a root).
- For each archive in order: fixpoint — while some `undef` name is in this
  archive's index, pull that member (append to the segment set), remove the
  names it defines from `undef`, add the names it imports (minus already-defined)
  to `undef`.
- After all archives: `undef` non-empty → error naming each symbol and the tool.

### 3.4 Layout / multibank integration
Pulled members are just more segments — but they must be **packed into banks**
(today's FFD packer in `gen_elvis_link.py` / the `tools/fgx2/*.in` templates) and
the libc members must land in the **KIND=LIBC emit-once segment(s)** so they stay
shared across code banks. So the pipeline becomes: **extract → pack pulled
members into (code/LIBC) segments → link**. The packer moves *after* extraction;
today it runs before (author-fixed). Preserving emit-once is a hard requirement,
not optional.

### 3.5 What it subsumes
Real archive semantics give "strong app def preempts library member" for free
(an already-defined symbol is never in `undef`, so its archive member is never
pulled). So the **A1 weak/strong precedence becomes redundant for the app-vs-lib
case** and can retire once extraction lands — *one* mechanism (archive order)
replaces the special-case precedence. Keep the emit-once/KIND=LIBC machinery;
that is orthogonal.

### 3.6 Error & diagnostic semantics
- Unresolved symbol after all archives → hard error (names symbol + tool +
  searched libs).
- The recursion-trap guard (6518eef4) stays and gets *more* precise: with true
  archives, "shadowed" = "a root defines a name an archive also exports and the
  root's is on a cycle" — same check, cleaner inputs.
- Link order matters: document that `libc` precedes `libfgx` precedes app-libs is
  the convention (or the reverse — decide, then gate).

---

## 4. Granularity — the real fork

**(A) Library-level (whole-pile-per-library).** Split the one pile into several
`--pile` blobs: `libc_c.c` (BSD-correct) + `libfgx.c` (the ~19 FGX functions) +
later `libm.c`, etc. Each is a whole segment. The manifest selects which library
segments to include. **Delivers the collision/namespace goal and the libc/libfgx
split immediately**, with a small linker change (select named library segments;
no per-member index, no extraction loop). Does **not** dead-strip within a
library (a tool using `printf` still pulls all of libc).

**(B) Member-level (true archives).** Per-member objects + symbol index +
extraction loop (§3). **This is "link multiple archive files" in full** — and the
only path that dead-strips (pull only referenced members), which matters on a
64KB-bank machine. Bigger lift: change the libc build to emit per-member objects,
build the index, add the extraction loop, move packing after extraction.

**Recommendation:** phase it. (A) first — it is most of the *architectural* value
(BSD-correct libc, separate libfgx, `<fgx.h>`, no collisions) for a fraction of
the work, and it is a clean intermediate the ports can already build against.
(B) second — the true archive machinery + dead-strip, done once the library
family actually exists and size pressure is real.

---

## 5. Phasing

- **P0 (done):** link-time recursion-trap guard (6518eef4).
- **P1 — libc/libfgx source + header split + library-level selection.**
  Carve `libfgx.c` (waitkey/pollkey/ticks/yield, IIgs video/font,
  dmesg/meminfo/procs/listdir, ifctl, spawn*) out of `libc_c.c`; new `<fgx.h>`;
  repoint FGX-native callers to include it; teach the build to emit two piles and
  the manifest/templates to select `libc` (+`libfgx` for FGX-native tools).
  Verify: the 2.11BSD ports link libc-only; FGX-native tools link both. **This is
  the collision-safety deliverable.**
- **P2 — true multi-archive linking.** Archive format + symbol index + extraction
  loop + packing-after-extraction; retire A1 weak/strong for app-vs-lib; then
  member-level dead-strip. Enables `libm`/`libtermcap`/`libcurses`/… as real
  archives during ports.
- **P3 — retire the monolithic assumptions.** Once P2 is trusted: libc stops
  being "the pile everyone includes"; it is one archive among several.

---

## 6. Risks & open questions (for the maintainer)

1. **Granularity commitment.** Confirm the phasing: P1 library-level now, P2
   member-level later? Or go straight to member-level?
2. **Member granularity in P2:** per-function or per-source-file objects?
   Per-file is simpler and matches C `.o`; per-function dead-strips finer but
   needs fcc to emit one object per function.
3. **Emit-once + extraction interaction.** The KIND=LIBC shared segment is
   load-bearing for multibank; extraction must feed it the pulled libc members
   without breaking sharing. Needs a careful test (elvis is the vehicle).
4. **Link-order convention** and whether to gate it.
5. **The borderline libc residents** (termcap `tget*`, `gtty`/`stty`,
   `getfsstat`): stay in libc, or spin `libtermcap` in P1? (from the audit).
6. **Header story:** one `<fgx.h>` for all libfgx, or split (`<fgx/video.h>`,
   `<fgx/kbd.h>`)? Ports never include any of them — but FGX-native tools do.

---

## 7. Bottom line

The collision-safety architecture (BSD-correct libc + libfgx + `<fgx.h>`) is
achievable at **library-level (P1)** with a modest linker/build change and is the
right next increment. **True multi-archive linking with dead-strip (P2)** is the
larger, genuinely-new linker capability the maintainer named; it subsumes the A1
weak/strong hack and is the foundation for the BSD library family. Recommend P1
next, P2 when the library family and size pressure make dead-strip pay.
