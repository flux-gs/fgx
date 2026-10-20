# Design: port `tr` then `sed` from 2.11BSD (pre-vi tool tier)

**Date:** 2026-06-22
**Status:** approved design; `tr` is the immediate work, `sed` follows behind a decision gate.
**Branch:** `feat/tr-sed-port`

## Goal & context

Exercise FGX + fcc/fas with BSD tool ports in the `ed` complexity range, as
de-risking steps before `vi`. This follows the multi-day `ed` port (a regex /
multi-block-buffer / heap-pointer fight that surfaced two real fcc bugs and two
kernel-FS bugs). We deliberately picked tools on **Path A — no catchable
signals required**, because FGX has only *default-action* signal delivery
(terminate at syscall-exit), not catchable userland handlers (the deferred
"vi-port signal slice").

Candidates considered and set aside:
- **Screen/cursor games** (worms/rain/snake) — all call `signal()` for ^C
  terminal cleanup; blocked on the catchable-signal slice. Deferred.
- **`sort`** — shelved. A faithful port is impossible without rewrites: it grabs
  a 256 KB arena via `end`/`sbrk`/`brk` (FGX has none), and `copyproto()` copies
  a struct word-by-word as `int*` assuming 2-byte pointers (fcc pointers are 4
  bytes). Bigger lift than needed right now.

Chosen: **`tr`** (small, clean win) then **`sed`** (the regex / line-editor
capstone, `ed`'s sibling).

## Tool 1 — `tr` (immediate work)

- **Source:** `examples/2.11BSD/usr/usr.bin/tr.c` (137 lines), single TU,
  near-verbatim port.
- **Build:** **FGX2** — FGX2 is the default for new C userland (FGX1 is legacy),
  and it keeps `tr` consistent with `sed`. Static data is `code[256] +
  squeez[256] + vect[256]` = 768 B (FGX2 is more headroom than `tr` needs, but
  consistency + policy win). New `src/userland/tr/` (`tr.c` + `link.s` +
  `tr.json`) built through the FGX2 pipeline. **Build mechanism is a plan-level
  decision:** either generalize `build_userbin_fgx2_c` so a `src/userland/` tool
  can emit FGX2 (currently called 0× — doing this also unblocks the wider
  FGX1→FGX2 userland migration), or a bespoke `tools/tr-fgx2/` pipeline mirroring
  `tools/ed-fgx2/` / `tools/fas/` (`fcc --data-segment` → merlin32 seg1 →
  `gen_seg1_layout.py` → merlin32 seg0 → `fgx_ld.py`). Prefer generalizing
  `build_userbin_fgx2_c` if it's low-friction — `tr` is a small, safe first
  customer.
- **Scope:** full `tr` — `-c` complement, `-d` delete, `-s` squeeze, `a-z`
  ranges, `\nnn` octal escapes. No subsetting (it all lives in the 137 lines).
- **fcc / libc touchpoints to verify:**
  - `register` keyword — must be accepted/ignored.
  - libc surface: `getc(stdin)`, `clearerr`, `ferror`, `EOF`, `putchar`. Confirm
    each exists; **anything missing is added as a reusable libc shim, never a
    tr-local hack** (implement-don't-stub policy).
  - `*argv[0]` / `argv[0][1]` — argv double-indexing (4-byte `char**`, landed).
  - `if (c = code[c&0377] & 0377)` — assignment-in-condition idiom.
  - `struct string { int last, max; char *p; }` — no `char` members, so B-8
    (2-byte char-slot) does not bite.
- **Tests (closed-loop, headless MAME, validated vs host clang `tr`):**
  1. `tr a-z A-Z` (basic transliterate)
  2. `-d` delete a set
  3. `-s` squeeze repeats
  4. `-c` complement
  5. `\nnn` octal escape
  6. range boundary (`a-z`, single char, reversed/edge)
  Per-test progress with `#/total`.

## Tool 2 — `sed` (behind a decision gate)

- **Source:** `examples/2.11BSD/usr/bin/sed/` — `sed0.c` (compiler, 976 L) +
  `sed1.c` (executor, 720 L) + `sed.h` (163 L). Concatenated into **one TU**
  (fcc is single-TU, gap F-1). Dedup the duplicate globals `reend`, `lbend`,
  `depth` (declared twice in `sed.h`). `bittab[]` is defined in `sed0.c` —
  self-contained, no external table needed.
- **Build:** **FGX2.** Static footprint ≈ 30 KB (`respace[10000]` +
  `linebuf`/`holdsp`/`genbuf` ~4 KB each + `ptrspace[200]` × ~30 B). FGX1's
  single bank is too cramped — the `ed` precedent (ed went FGX2 to escape the
  cramped-bank heisenbug). Mirror the `tools/ed-fgx2/` / `tools/fas/` FGX2
  pipeline (`fcc --data-segment` → merlin32 seg1 → `gen_seg1_layout.py` →
  merlin32 seg0 → `fgx_ld.py`).
- **Architecture (unchanged from BSD):**
  - *Compile phase* (`compile`/`address`/`compsub`/`ycomp`): parses the script
    into `ptrspace[]` (the command program, array of `union reptr`), compiles
    regexes into `respace[]`, and resolves labels in `ltab[]`.
  - *Execute phase* (`execute`/`match`/`advance`/`step`/`substitute`/`dosub`):
    streams input through the pattern space (`linebuf`) and hold space
    (`holdsp`), dispatching each compiled command.
  - **No `brk`/`sbrk`/`signal`/`fork` anywhere** — all buffers are static
    arrays, so there is NO memory-model rewrite (the key contrast with `sort`).
- **Memory note:** B-8 (char struct members get a 2-byte slot) doubles
  `union reptr` (15 B on PDP-11 → ~30 B on fcc). Invisible (the union is
  self-consistent, never crosses a byte-exact ABI boundary), but budget for it
  in the FGX2 data segment.
- **Scope:** full command set — `s y p P d D a i c r w n N g G h H x b t : {} = l
  q`, line/regex/`$` addresses, ranges, and `-n` / `-e` / `-f`. The single-pass
  compiler makes subsetting unnatural; port the whole program and test
  incrementally.
- **Risks (honest):**
  1. **Regex-engine codegen.** `compile`/`advance`/`step` are the same
     pointer-arithmetic-heavy family that cost `ed` multiple days. The two fcc
     bugs behind that fight are now FIXED (signed-pointer-compare;
     ptr-compound-assign bank-zeroing) and FGX2 eliminates the cramped-bank
     heisenbug, so sed *should* benefit — but a fresh codegen edge here could be
     another long debug. This is the gamble, and the exercise value.
  2. **Globals near the cap.** ~55 distinct globals vs fcc's 64-global limit;
     dedup helps, but watch it.
  3. **F-1 concatenation** + duplicate-decl removal.
  4. **`long` line numbers** (`lnum`, `tlno[256]`) exercise long-array and long
     compare paths.
- **Decision gate (chosen 2026-06-22):** the sed **regex-risk strategy** —
  *spike the engine first* (a tiny FGX2 harness around `compile`/`advance`/
  `step` over canned patterns, mirroring `tools/fgx2heap/`) vs *full port, test
  incrementally* — is **decided after `tr` lands**, using how cleanly `tr` flows
  through the pipeline as the signal. Until then, sed is design-only.
- **Tests (ladder, simplest→hardest, validated vs host clang `sed`):**
  `s/a/b/` → `s/a/b/g` → `2d` → `2,4d` → `/re/p` with `-n` → `&`/`\1` backrefs in
  RHS → `y///` → hold space `h`/`g`/`x` → `a`/`i` → multi-file `w`/`r` (the FS
  touch — opens up to 12 files) → `b`/`t`/`:` branch/label.

## Cross-cutting

- Feature branch `feat/tr-sed-port`; never commit to `main`. Land via
  merge→main + `release.sh` per versioning discipline (re-pin toolchain first if
  toolchain changes are needed).
- All-new tools in C/fcc (policy); missing primitives become reusable libc
  shims, never per-tool asm.
- Closed-loop testing is silent/headless MAME with per-test `#/total` progress;
  each tool validated against its host clang reference (validate-against-C).
- Never silently drop a feature for a missing primitive — if one surfaces mid
  port, STOP, scope it, and ask.

## Sequence

1. `tr` — full port + 6-test closed-loop suite, green on MAME.
2. **Gate:** assess `tr`'s pipeline experience; choose the sed regex strategy.
3. `sed` — FGX2 port per the chosen strategy + the test ladder.
