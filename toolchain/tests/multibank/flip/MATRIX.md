# Site → construct traceability matrix (MEASURED, task #56 Task 9)

`flip_sweep.py` flips each PHK/PHB bank-emission site (`flip/sites.json`, from
`enumerate_sites.py`) PHK↔PHB, rebuilds fcc, boots the sweep, and records which
constructs went `P → F`.  Green = the sweep stays `=MBEND 042`; a red run prints
`=MBi <id> F` per failing construct.

**Scope:** the 21 clean `ir_emitf("...PHK/PHB\n")` sites in `emit.c` (12),
`parse_expr.c` (3), `parse_stmt.c` (6) — the DBR-vs-PB *decision* points.  fcc has
more bank *sources* (`_fcc_ptr+2`, `#0`, soft-stack, heap, MVN DBR) reached by
non-PHK/PHB forms; those need per-kind mutations (follow-on).

**default and `FCC_NO_REGALLOC=1` produced IDENTICAL results** — bank emission is
optimizer-invariant across these 21 sites (no opt-dependent bank bug).

## Guarded sites (flip reds ≥1 construct → traceability proven)

| site | kind | constructs reddened | what it banks |
|------|------|---------------------|---------------|
| `emit.c:749` | PHB | **1,2,4,5,6,7,11,14,19** | `emit_addr_of_global` — `&global` far-ptr bank (the whole data-deref family). |
| `emit.c:1827` | PHB | **16,17,18,19** | fn-ptr / cross-bank-dispatch family. |
| `emit.c:2579` | PHB | **3** | N-D array partial decay (regression-guards mole #48). |
| `parse_expr.c:386` | PHK | **ALL 1..19** | the central far-call/entry bank — every construct depends on it. |

## Dead single-bank paths (green EXPECTED — the `else`/`!g_data_out` PHK branch, never emitted in multi-bank)

`emit.c` 625, 751, 798, 914, 1422, 2003, 2581, 2623 · `parse_expr.c` 388, 1469 ·
`parse_stmt.c` 2579, 4186.  These are the single-code-bank recovery paths
(`PHK` = own program bank); in the sweep `g_data_out` is always true so they are
inert.  Not coverage gaps.

## ★ Coverage-gap candidates (green on the ACTIVE multi-bank path → no construct detects a flip)

These bank emissions ARE made in the multi-bank sweep, yet flipping them changes
nothing observable — either no fixture triggers the path or no check is sensitive
to it.  Each is a candidate for a NEW construct (or a strengthened existing one):

| site | kind | context | likely missing construct |
|------|------|---------|--------------------------|
| `emit.c:1228` | PHK | G22 "refresh bank so chained struct-ptr" (field_type ptr/fn-ptr/struct-ptr) | chained struct-pointer field deref (`a->b->c` across banks) |
| `parse_stmt.c:2576` | PHB | `else if (g_data_out)` pointer-value store bank (non-local) | assign a far pointer VALUE to a global ptr, then deref |
| `parse_stmt.c:2815` | PHB | `if (!lc && !is_ptr_global)` pointer bank store | (related pointer-store bank path) |
| `parse_stmt.c:3403` | PHK | `MVN $00,$00` block-move DBR setup (`PHK/PLB`) | whole-struct/array copy whose MVN source bank matters (c11 didn't catch it) |
| `parse_stmt.c:4184` | PHB | `if (g_data_out)` pointer bank | (g_data_out pointer-bank path) |

## ★ Gap resolution — constructs c22..c25 (2026-07-05)

Built a construct per gap candidate and re-flipped.  (fcc line numbers shifted after
the 3 fcc fixes; sites.json was regenerated — the sites below are the same emit
points at their new lines.)

| original site | construct added | result | disposition |
|---------------|-----------------|--------|-------------|
| `emit.c:1228` (G22 chained struct-ptr field) | **c22_chainfield** (`o->p->v` across banks) | c22 GREEN; flip of 1228 reds nothing | **NOT a gap** — 1228 is the SINGLE-BANK PHK fallthrough; multi-bank pointer-field loads take the CORRECT path at emit.c:1192/1205 (`LDY #2; LDA [_fcc_ptr],Y` = stored bank).  c22 exercises that correct path (good coverage), and 1228 is a dead single-bank branch. |
| `parse_stmt.c:2576` (`g[i].c[j]=p[k]` LHS-array bank) | **c23_idxstore** | c23 GREEN; **flip reds [23]** | **GUARDED** ✓ moved to the Guarded set. |
| `parse_stmt.c:2815` (`garr[i] op= x` compound-assign) | **c24_gcompound** | c24 GREEN; **flip reds [24]** | **GUARDED** ✓ |
| `parse_stmt.c:3403` (struct-by-value arg MVN `PHK/PLB`) | **c25_structarg** | c25 GREEN; flip reds nothing | **INERT flip** — the `PHK/PLB` is a DBR setup restored immediately around the stack-reservation MVN; the struct's field-copy bank is established elsewhere.  c25 is valid struct-by-value coverage but does not guard this specific PHK. |
| `parse_stmt.c:4184` (main `argv` binding) | — | deferred | **NOT sweep-reachable** — the sweep's driver is `int main(void)`; argv binding is a main-only path. |

Net: 2 gaps closed (c23/c24 now guard 2576/2815), 1 reclassified dead (1228), 1 inert
(3403), 1 deferred (4184).  c22..c25 also add real multi-bank coverage (chained field,
indexed store, compound-assign, struct-by-value).

Also fixed during this pass: `flip_sweep.py` now (a) recreates `disk_src/TESTS/FCC`
each boot (run_runtime rmtree's it — else a silent stale-dump false green) and (b)
scores ALL baseline construct IDs, not a fixed 1..19 (else c22..c25 were invisible to
the flip).

**Remaining follow-on:** ~~extend the sweep to the non-PHK/PHB bank SOURCES~~
→ DONE for `_fcc_ptr+2`/heap, 2026-07-16 (below).  Soft-stack source was
deleted at P3-3; `#0` sources are constant-correct by construction.

---

# ★ 2026-07-16 re-measurement — train-2 phase 0b (`_fcc_ptr+2` + heap sources)

19 sites (12 PHK/PHB re-anchored after post-v1.5.0 line drift + **7 NEW
PTRBANK sites**), 42 constructs (+ **c41** realloc-move heap provenance,
**c42** ptr-local spill pressure).  PTRBANK mutations are per-kind:
`LDA _fcc_ptr+2 → LDA #$00` (bank read dropped), `STA/STX → STZ` (bank
write zeroed); a no-op guard skips stores whose value was just loaded `#0`
(`emit_addr_param_lower` — &param IS bank 0; STZ changes nothing).

## Guarded (2026-07-16 lines)

| site | kind | reds | what it banks |
|------|------|------|---------------|
| `emit.c:525` | PTRBANK_ST | **ALL 42** | the central stored-ptr bank commit — everything transits it. |
| `emit.c:1007` | PHB | 11, 25, 26 | struct-copy/struct-arg family. |
| `emit.c:1681` | PTRBANK_LD | **10, 41** | stored-bank read on the pointer-RETURN path — the HEAP provenance channel (malloc/realloc returns); c41 guards the malloc train directly. |
| `emit.c:2133` | PHB | 16–19, 22–42 | fn-ptr / cross-bank dispatch family. |
| `emit.c:2331` | PTRBANK_ST | 36, 38, 39, 42 | ptr-model bank commit. |
| `emit.c:2757` | PHB | 3 | N-D partial decay (mole #48). |
| `emit.c:4080` | PHK | **ALL 42** | central far-call/entry bank. |
| `parse_stmt.c:1260` | PHB | 24 | global compound-assign bank. |

## Dead / inert on the sweep's config (not gaps)

PHK/PHB: `emit.c` 1439, 2058, 2060, 4090, 4318 · `parse_expr.c` 3819 ·
`parse_stmt.c` 4749 — the same single-bank-recovery/inert population as the
2026-07-05 adjudication, at drifted lines.
PTRBANK: `emit.c:1423` — field-deref bank commit on the `--data-segment`-
WITHOUT-`--far-calls` branch; **sweep-invisible by configuration** (the
sweep binary is the 5-bank far-calls shape).  Standard 2-seg FGX2 tools DO
take it — guarded behaviorally by every such tool.  Structural blind spot
recorded.

## ★ Enumerated OPEN gaps

| site | kind | path | status |
|------|------|------|--------|
| `emit.c:541` | PTRBANK_LD | bank load for a stack-SLOT (unpromoted) ptr-local store | OPEN — c42 (7 live ptr locals across a call) did NOT reach it; the promoter routes around the slot path. |
| `emit.c:571` | PTRBANK_ST | DP-IMG → `_fcc_ptr+2` materialization (`IR_LOAD_PTR_LOCAL_IMG`) | OPEN — direct `[_fcc_img]` deref bypasses it in c42's shapes. |
| `emit.c:652` | PTRBANK_LD | `_fcc_ptr+2` → DP-IMG store (`IR_STORE_PTR_LOCAL_IMG`) | OPEN — ditto. |

Honest-coverage note: enumerated residue, not silent truncation.  These are
optimizer spill/materialize paths — orthogonal to the heap-provenance
channel the malloc train rewrites (that channel IS guarded: 525+1681+2331).
Next attempt should start from what records `IR_LOAD/STORE_PTR_LOCAL_IMG`
rather than guessing source shapes.

_Generated 2026-07-05; raw data in `flip/matrix.json` (keys `<file>:<line>[<mode>]`)._
