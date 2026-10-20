# FGX userland roadmap — od/hd → grep → man → vi (and the fcc/libc work they require)

Date: 2026-06-19. Author: session with the maintainer. Status: plan (not yet executed beyond od).

This plan sequences four faithful 2.11BSD userland ports — **od/hd, grep, man, vi** —
and the **fcc compiler + libc** work each requires. It folds in a standing directive:
**implement primitives properly; do not shim or work around a weakness when we can fix
it correctly.** Two consequences baked in below: `getchar`/`freopen` are *implemented*
(not avoided), and any fcc codegen weakness a port exposes (e.g. the char-class bitmap)
is *fixed in fcc*, not dodged by choosing a different algorithm.

---

## Guiding principles

1. **Implement properly, never shim.** If a tool needs `getchar`/`freopen`/an environ/
   a working `bits[c>>3] |= mask` codegen, we build the real thing. Replacing a missing
   primitive with a per-tool workaround (the `head.c` open/read idiom in place of
   `freopen`, etc.) is banned when the proper implementation is feasible. See
   `feedback_implement_syscalls_not_workarounds`, `feedback_port_missing_framework_stop_and_ask`.

2. **Validate against a C reference — three oracles.**
   - **gcc/clang (behavior):** build the *real* BSD source on the host; diff output + exit
     code against the FGX run on a real battery. This is the acceptance gate, NOT
     hand-written synthetic probes (a probe that passes proves nothing if unfaithful —
     this exact mistake cost most of the od session; see `feedback_validate_against_c_reference`).
   - **llvm-65816-mos (65816 codegen):** `examples/65816-llvm-mos/` is a mature 65816
     LLVM backend. Use it as a codegen oracle for the fcc-stressing constructs (recursive
     matcher, char-class bitmap, deep pointer arithmetic): compile the same C, compare
     behavior and the shape of the generated 65816.
   - **MAME (actual hardware):** every fcc fixture's `tests/oracle.json` exit code is the
     host-reference value; the suite is the final gate.
   - When a fix "should" work but the real program still fails: **instrument the real
     program on FGX** and read ground truth — do not keep building probes.

3. **Faithful 2.11BSD ports.** SPDX + `FGX-Provenance` header + `docs/PROVENANCE.md` row
   (gated by `tools/check_provenance.py`). Don't silently drop features; scope-and-ask.

4. **All new userland tools in C/fcc** (no hand-asm). New kernel syscalls → `include/loader.s`
   jump table (auto-table-gen is `--check`-gated).

---

## Phase 0 — fcc / libc foundation (prerequisite for everything below)

### 0.0 Land this session's three fcc fixes → fcc v0.7.2  *(gated on the running full sweep)*
Already fixed + reference-validated this session:
- **Negative int→long global store** sign-extended (was zero-extend). `emit.c emit_store_global_int`.
  Fixture `long_global_inc=42`.
- **Fn-ptr indirect call pointer-arg width** — unprototyped `T (*)()` pushed pointer args as
  2 bytes; now pushes by the argument's own type (4-byte far ptr). 4 indirect-call sites in
  `parse_expr.c`/`parse_stmt.c`. Fixtures `od_probe`(expr), `od_probe2`(stmt).
- **Fn-ptr-table index corruption (THE od blocker)** — `funcs_declare` promoting a prototype
  to a definition shifted `g_funcs`, invalidating fn-ptr global-initializer indices stored at
  parse time → `put_table[]` named the wrong functions. Fixed by remapping stored indices on
  promotion (`symtab.c`). Fixture `od_probe5` (multi-element table defined before its targets;
  clang ref = 42). Probes `od_probe3/4` are extra coverage.
- Action: commit as separate logical commits, regen goldens, run full sweep (in progress),
  release fcc v0.7.2, bump FGX toolchain pin.

### 0.1 `getchar` — implement properly
`int getchar(void) { return fgetc(stdin); }`. A real libc entry (C or a tiny asm thunk that
loads `stdin` and tail-calls `c_fgetc`). The fcc libc already has `stdin` (FILE*) and `c_fgetc`
(`FILE*`→fd via `_libc_FILE_to_fd`). Trivial. Add `getchar`/`getc` to `toolchain/include/stdio.h`.

### 0.2 `freopen` — implement properly
`FILE *freopen(const char *path, const char *mode, FILE *stream)`: open `path`, **rebind the
`__sFILE` entry** that `stream` points at to the new fd, close the old fd (unless a std stream),
return `stream` (or NULL). This makes `freopen(file,"r",stdin)` — the classic grep/od stdin
redirect — work correctly instead of being avoided. Scope: read the `__sFILE` table layout +
`_libc_FILE_to_fd` in `toolchain/lib/fcc_libc_shims.s`; add `c_freopen` + binding + `stdio.h`
proto. Dual-copy libc note: shims live only in `toolchain/lib` (not `src/userland/lib`), so a
shim is single-copy; a libc *static* would be dual-copy.

### 0.3 Char-class bitmap codegen — evaluate, then fix if needed (do NOT dodge it)
grep's set-membership idiom: `bits[c>>3] |= bittab[c&07]` (byte-array element compound-OR with a
shift/mask-computed index) + byte read-back `bits[c>>3] & bittab[c&07]`.
- **Current finding:** fcc *compiles* it and the generated 65816 is logically correct (computes
  `&bits[c>>3]`, loads the byte, ORs `bittab[c&7]`, stores back via `STA:$0000,X` under SEP #$20);
  clang reference = 42. The 4-byte compound-assign-on-array-elem variant was fixed earlier
  (`ecb8ec4`); this is the **byte** variant.
- **Action:** add fixture `ccbits` (the probe in `/tmp/ccbits.c`, → 42), validate on MAME against
  the clang reference, and cross-check codegen vs llvm-65816. If MAME confirms 42, document it as
  supported and grep keeps the bitmap. If it's wrong, **fix `emit.c`** (byte compound-assign with
  computed index) — we make fcc handle the construct, we do not switch algorithms to avoid it.
- Note: this de-risks both regexp engines (grep.c's bitmap and any future code that bit-packs).

### 0.4 (stretch) `getenv` real environ — flagged, not yet scheduled
`getenv` returns NULL today ("no environment on FGX"), which blocks `$MANPATH`/`$PAGER`/`EXINIT`.
A proper environ (spawn passes env block; libc `getenv` reads it) is the "implement properly"
answer when man/vi want env. Scope separately; until then use compiled-in defaults and say so.

**Phase 0 effort:** ~1–2 days (getchar trivial; freopen ~0.5d; bitmap eval/MAME/fix 0.5–1d; commit/release 0.5d). environ is a separate larger item.

---

## Phase 1 — finish od/hd  *(od done; hd + release remain)*

- **od:** DONE and reference-validated (default + `-h` token-exact vs host od; `od_fmt` MAME test
  green; `-c` no longer floods). Commit `src/userland/od/od.c`, `od.link.s`, `build.sh`
  (`build_userbin_c od`), `docs/PROVENANCE.md` row, `tools/mame_test/tests/od_fmt.json`. Remove the
  stale `od.s`/`od_main.s` hand-asm once hd no longer PUTs them.
- **hd:** a shell wrapper around od (the maintainer's call), ≈ `od -h -c` / hexdump-style. Decide the jsh
  script-exec mechanism (how jsh runs a `/bin` script); make `hd` that script. Faithful behavior;
  update any scripts/tests to BSD options.
- **Release:** bump FGX toolchain pin to fcc v0.7.2; FGX release per the usual gate (build.sh disk
  + MAME headless), push.

**Phase 1 effort:** ~0.5–1 day.

---

## Phase 2 — `grep` + a reusable regexp engine  *(the regexp foundation vi reuses)*

**Why grep first:** its BRE matcher is the *same Thompson/`ed` bytecode engine* 2.11BSD vi/ex use
(`ex_re.c`) — same opcodes, same recursive `advance()`. ~70–80% of the matcher is directly reusable
by a later vi. grep builds the regexp foundation vi needs, and (unlike od) it has **no fn-ptr
dispatch tables** and **no yacc** — a favorable fcc profile.

- **Source:** port `examples/2.11BSD/usr/lib/libc/gen/regex.c` (`re_comp`/`re_exec`, ~400 lines, a
  real reusable API, and — importantly — a `cclass()` linear scan rather than grep.c's static
  bitmap; but since Phase 0.3 makes the bitmap correct, either engine is fine — pick regex.c for
  the clean API) under a thin `grep` front-end derived from `examples/2.11BSD/usr/bin/grep.c`. Both
  are authentic 2.11BSD → provenance rows.
- **Proper I/O:** uses Phase 0's `getchar`/`freopen` for the file/stdin loop — **no `head.c`
  workaround**. Line loop keys on FGX CR (`$0D`) like the other ported tools.
- **2a — engine + minimal grep**, gated on a **clang-built real-grep oracle**: a battery of
  (pattern,input) covering `^ $ . *`, `[abc] [^abc] [a-z]`, `\(\) \1`, `\< \>`, anchors,
  empty-match, pathological `a*a*a*` backtracking. Diff stdout+exit vs the oracle on the *actual
  ported source*. Cross-check the recursive matcher's codegen vs llvm-65816.
- **2b — flags:** `-i -v -n -c -l -w -x -s -h` (note `-i` via pattern-rewrite into `[Xx]` classes,
  per grep.c; `-n` uses `long`+`%ld`; `-l` is an early return, not the upstream `fseek`-to-EOF).
- **2c — factor the engine into a shared lib** (mirror the `src/userland/lib` ↔ `toolchain/lib`
  dual-copy discipline) with the **vi seams pre-installed**: a `same(a,b)` compare hook (for vi
  IGNORECASE), caller-owned `struct regexp { char Expbuf[ESIZE+2]; char Circfl; short Nbra; }`
  (ex_re.h's shape, for vi's three REs), and a separable compile front-end (so vi's MAGIC/QUOTE
  layer drops in). Re-validate grep vs the oracle after the refactor.
- **fcc risks:** recursive `advance()` stack correctness; negative pointer indexing (`ep[-1]`);
  char-class build (covered by 0.3). All host- and MAME-validated.

**Phase 2 effort:** ~1–2 weeks (2a engine+grep is the bulk; 2b/2c smaller).

---

## Phase 3 — `man` (catman/preformatted, bold+underline preserved)

**Key fact:** 2.11BSD's own `man.c` (`examples/2.11BSD/usr/ucb/man/man.c`) **does not run nroff** —
it's a cat-page locator that pages preformatted `.0` files through `more`. So the faithful port is
the catman model, not an nroff port.

- **Console already renders SGR** bold (real bold font `font_bold.s`), underline (drawn pixel row,
  scanline 7), reverse (fg/bg swap) — confirmed in `console_render.s`/`console_init.s`; the
  "stored only" comment in `console_vtcolor.s` is stale. Nothing in the console needs changing.
- **Bridge man's overstrike → SGR (preserve bold/underline, don't strip):** cat pages use
  teletype backspace-overstrike (`_\bX` underline, `X\bX` bold), no ANSI. Convert with **`ul`**
  (`examples/2.11BSD/usr/ucb/ul.c`), which maps overstrike → termcap `us/ue` (underline), `md/me`
  (bold), `so/se` (standout). Our baked "fgx" termcap has `so/se` but is **missing `us/ue/md/me`**
  → add the four caps (`us=ESC[4m`, `ue=ESC[24m`, `md=ESC[1m`, `me=ESC[0m`) to the termcap table —
  in **both** `src/userland/lib/libc_data.s` and `toolchain/lib/libc_data.s` (dual-copy footgun).
  Then `ul`→SGR→console renders true, distinct bold and underline.
- **v1 (host preformat):** host pipeline runs `ul -t fgx` over the curated cat pages → ship the
  SGR-encoded `.man` files; `man name` resolves the path and spawns `more` (which passes SGR bytes
  through untouched). No console change, no on-device C filter. CR/LF: translate cat pages' LF to
  FGX CR in the pipeline.
- **`man` C tool:** stripped-down `man.c` (hand-rolled arg scan, parallel-array section tables,
  fixed path buffers — keep it fcc-friendly): `man [section] name` → `/man/cat<N>/<NAME>` → `more`.
  `man -k`/`-f` (apropos/whatis) scan `/man/whatis`. Compiled-in `/man` default until Phase 0.4
  gives a real `$MANPATH`.
- **Curated initial set:** the already-ported tools (od, cat, more, cmp, head, rm, cp, df, wc,
  fold, ls, date, …) so docs match shipped behavior (~33 KB).
- **v2 (optional):** port `ul.c` to fcc and run `man` as `ul <page>.0 | more` live (needs the pipe
  path; `ul`'s single fn-ptr arg `tputs(s,1,outchar)` is fine post-today's-fix).

**Phase 3 effort:** ~2–3 days (mostly host pipeline + small `man` tool + 4 termcap caps).

---

## Phase 4 — `vi` (the payoff; reuses Phase 2's regexp)

**Groundwork already exists** ("vi-port slices" built earlier): VT100/102 console (`cm cl ce cd up
nd so se`, alt-screen `?1049`, scroll-region `cs`, autowrap), raw/no-echo mode (`tcsetattr` →
`_libc_rawMode` reroutes reads to `SYS_GETKEY`), baked termcap shim (`tgetent/str/num/flag` + "fgx"
entry), `setjmp`/`longjmp`, synchronous `SIGINT` incl. keyboard `^C`, `SYS_GETKEY` raw keys, and the
temp-file syscalls (`lseek`/`O_RDWR`/`unlink`/`getpid`).

- **4.0 — fcc-validate vi's hard constructs FIRST.** 19.5k lines of K&R; the `ex_tty.c`
  `sstrs[]`/`sflags[]`/`fkeys[]` **multi-element pointer tables** are the exact class fixed today —
  re-validate against clang + MAME before committing to the full port. Also `lseek` long math and
  deep `setjmp`/`longjmp`. This gate decides full-port vs hand-written editor.
- **4.1 — small vi-like in C/fcc** (~1–2 wks): modal editor, `hjkl`/arrows, `i a o x dd G :w :q`,
  redraw via native `\x1b[…H`/EL/SGR, alt-screen, raw `SYS_GETKEY`, SIGINT abort, temp-file buffer.
  Proves the whole console+keyboard+raw+signal+temp-file stack end-to-end.
- **4.2 — termlib completion:** land `tgoto`/`tputs` (port `examples/2.11BSD/usr/usr.lib/libtermlib/`
  — `tgoto.c`, `tputs.c` — or replace call sites with native CUP `printf`; `tputs` padding is moot
  on a memory-mapped console). Implement **properly** (per the standing rule), not stubbed.
- **4.3 — full 2.11BSD ex/vi port:** reuse Phase 2's regexp engine (`ex_re.c` = same engine; add
  the MAGIC + IGNORECASE seams left in Phase 2c). Add sgtty `gtty/stty/ioctl` libc shims that
  translate `RAW|~ECHO` → `_libc_rawMode` and make `ioctl(TIOCGWINSZ)` fail → termcap `li#/co#`.
  Provide a writable `/tmp`; add `SIGHUP` delivery (small kernel change) for crash-preserve.
- **Risk** is dominated by fcc maturity on K&R at scale; 4.0 de-risks, 4.1 is the fallback deliverable.

**Phase 4 effort:** small vi-like ~1–2 wks; full ex/vi ~3–6 wks (fcc-dependent).

---

## Sequencing / dependencies

```
Phase 0 (getchar, freopen, bitmap, fcc v0.7.2)
   │
   ├─► Phase 1 (od/hd finish, pin bump)
   │
   ├─► Phase 2 (grep + regexp) ──────────────► Phase 4.3 (vi reuses regexp)
   │                                              ▲
   ├─► Phase 3 (man) ── parallel after 0/1        │
   │                                              │
   └─► Phase 4.0/4.1 (fcc-validate + small vi) ───┘  (can start after Phase 0,
                                                       independent of grep)
```

Critical path to vi: **0 → 2 → 4.3.** man (3) and the small vi-like (4.1) are parallelizable.

## Validation strategy (cross-cutting, applies to every phase)

| Oracle | Role | Used for |
|---|---|---|
| gcc/clang | behavior reference | build the real BSD source, diff output/exit on a battery |
| llvm-65816-mos | 65816 codegen reference | fcc-stressing constructs (recursive matcher, bitmap, ptr arith) |
| MAME + oracle.json | actual-hardware gate | every fcc fixture; final acceptance |
| instrument-the-real-program | ground truth | when a fix "should" work but the real tool still fails |

Acceptance for a ported tool = **output-equivalence vs the clang-built original** on a real input
battery — never a passing synthetic probe alone.

## Effort summary (rough)

- Phase 0: 1–2 days (+ separate environ item if scheduled)
- Phase 1: 0.5–1 day
- Phase 2: 1–2 weeks
- Phase 3: 2–3 days
- Phase 4: small vi-like 1–2 weeks; full ex/vi 3–6 weeks (fcc-dependent)
