# T2 completion — pp as a token pass, symbol handles, and the IR_TEXT lift

**Branches:** `feat/t2-frontend-completion` (both repos) off the released
v1.0.0 mains (tc `81c8604c` / FGX `79a9666d`).  Post-release: normal land
discipline applies (merge→main + release.sh when done).
**Status:** kickoff → Fable design review → execute.

## Why (redesign §T2 + the Track-2 phase-2 payoff)

Phase-2 already delivered: whole-TU token vector (source-replay class
retired), one call-marshalling emitter, the expression/statement AST flip
(3a/3b), per-function trees (3c), stable Func identity (increment 4),
walker purity.  §T2's remaining bullets — and the reason they matter — are:

1. **pp as a token pass.**  `lex_pp.c` (~65KB) still runs the preprocessor
   over the char stream via the `g_pp_stack` frame machinery DURING
   tokenization.  Macro expansion, `#include` frames, and conditionals are
   char-level; the token vector is built THROUGH them.  Residual risk class:
   frame-lifetime/position bugs inside tokenize-time expansion (the
   `#include`-frame for-step variant bit during the elvis port).  Target:
   pp operates token→token (expand into the vector), the lexer touches
   source exactly once, frames die entirely.
2. **Stable symbol handles.**  Increment 4 stabilized `Func` identity;
   locals/globals/fields still pass (name_ptr, name_len) pairs and
   re-lookup.  Target: parse resolves each identifier ONCE to a handle
   (index/pointer with interned text), AST nodes carry handles.  Kills the
   lookup-drift class and is the substrate self-host needs (symbol tables
   must shrink).
3. **The IR_TEXT lift.**  ~1,400 `ir_emitf` raw-text sites (emit.c 1008,
   parse_stmt 258, parse_expr 122) emit machine text the IR cannot see
   through — every one is opaque to the future whole-function allocator
   (Track-2 phase 2: the only remaining fcc size lever; within-BB ceiling
   measured ~2%).  Target: structured IR ops for the recurring shapes
   (loads/stores/moves/branches are the bulk); `IR_TEXT` remains only for
   genuinely irregular sequences.

## Fable design review (2026-07-09) — verdict: proceed-with-changes

Corrections adopted (file:line evidence in the review):
- **REORDER: T2-0 → T2-3 (lift) → T2-1 (handles) → T2-2 (pp).**  The lift
  is independent (IrNode already carries Local*/Global*; peephole runs
  once over the final text buffer, so byte-identical lowering ⇒ identical
  peephole input) and is the campaign's payoff — bank it first.  pp is the
  highest-risk/zero-backend-payoff item — last, with maximum harness
  maturity.
- **Lift unit = emission idiom/helper, NOT string family** (each op needs
  the semantic payload: ptr, g_s_delta snapshot, stack-delta/xclean/
  barrier class).  Measured: 221 distinct format strings, 56 families =
  80% of 1008 sites, dominated by single-instruction lines.  **The true
  prize is control flow** (branches/labels): lifting it turns the
  "run-between-IR_TEXT-barriers" BB partition into a real CFG for the
  whole-function allocator.  Stop rule: "remaining tail has no allocator
  value", not a % of sites.
- **pp staging corrected**: (a) object-macro bodies → token slices + the
  token-level #if evaluator IN THE SAME increment (the char evaluator
  consumes macro bodies as strings — flipping bodies first starves it);
  (b) funclike → token bodies; (c) #include → recursive tokenize, delete
  g_pp_stack.  **Inactive-branch skipping stays CHAR-LEVEL permanently**
  (tokenize-then-filter would die on un-lexable #if-0 prose that compiles
  today).  The headline frame-lifetime risk is already mostly retired
  (Increment 1); the live class is textual substitution itself.
- **Delete-forward, no toggle** (the differential harness compares old
  BINARY vs new; an in-binary twin forces dual macro-body storage).
- **T2-2 gate**: byte-identity across the FULL corpus (goldens + elvis
  28-TU + userland differentials + sweep) + adversarial PP fixtures
  written BEFORE the flip pinning today's exact behavior (accidental-
  paste, rescan guards, #if div-by-zero→0, funclike-in-#if, #if-0 prose).
  stderr error POSITIONS inside expansions: declared OUT-OF-GATE.
- **T2-1 is smaller than drafted**: AST nodes already carry sym_lc/gv/f;
  the work = ~73 locals_lookup/globals_lookup parse sites + fields, with
  the die-loud no-re-lookup tripwire.  Cheap rider: intern the fixed
  char name[MAX_IDENT] copies.
- **T2-0 gains the Part-V memory instrumentation**: peak g_toks bytes,
  intern arena, g_ast peak (MAX_AST_NODES 65536 × ~120B ≈ 7.5MB static),
  reported on the largest elvis TU at T2-4.

**Flagged to the maintainer (non-blocking, defaults adopted):** (1) self-host
memory BUDGET number — none exists; T2 measures + reports, the budget is
set at T2-4; (2) `#`/`##` token-paste operators were NEVER supported —
NOT silently added; explicitly deferred until self-host/a port demands
them (the port rule's stop-and-ask, recorded here).

## Increment ladder (final)

- **T2-0 — measurement + tripwires:** ir_emitf shape classifier (the
  221-string census, ordered by allocator value with control flow first);
  Part-V memory stats print; differential harness wired as the standing
  per-commit gate.
- **T2-3 — IR_TEXT lift by emission idiom:** control flow (branches/
  labels → CFG) first, then the top single-instruction families through
  existing-op patterns.  Byte-identity per commit.
- **T2-1 — symbol handles:** locals → globals → fields; die-loud
  tripwire; interning rider.
- **T2-2 — pp as a token pass:** adversarial PP fixtures FIRST, then
  (a) object-macros + #if evaluator, (b) funclike, (c) #include +
  g_pp_stack deletion.  Inactive-branch skip stays char-level.
- **T2-4 — close-out:** memory report (budget decision to the maintainer),
  allocator-visibility measurement, redesign-doc update, land via the
  normal release train.

## Execution status

- **[x] T2-0** (tc `3f789161`): census — 1,383 sites / 206 shapes; MEM
  48.2%, MISC 20.3%, MODE 14.2%, **CTRL 8.7% = 120 sites (the CFG lift is
  bounded)**, STACK 8.5%.  `FCC_MEM_STATS=1` instrumentation (toks bytes,
  intern total, AST peak) — env-on/off byte-identical, goldens 382/382
  WITHOUT REGEN.  Differential harness identified:
  `tests/run_runtime.py --use-fcc <candidate>` (behavior vs the calibrated
  oracle) — the standing per-increment gate.
- **[~] T2-3** in progress — two family lifts BANKED:
  - **Control flow** (tc `78e46a82`): IR_LABEL / IR_BR / IR_BCOND (far
    *+5/BRL idiom folded into ONE op) / IR_JSR_RT — 70 of 120 CTRL sites;
    the ops carry successor/callee metadata (label number, cond, helper
    name).  emit_label/beq/bne/bra/brl funnels lifted.  Remaining CTRL
    tail (50) = compound/variable-target/epilogue shapes.
  - **Width mode** (tc `246d4fb3`): IR_M8 / IR_M16 — all 100 SEP/REP+MX
    pairs; accumulator width is now an explicit per-point fact.
  - Both barrier-classed (partition PRESERVED); every batch gated by
    goldens-without-REGEN + the differential harness (382/382 both).
  - **LESSON (memory: feedback_fcc_lift_converter_eats_lowering)**: a
    batch converter matches the op's own lowering body → the op records
    itself → infinite recursion/SIGSEGV.  Lowerings are now regex-proofed;
    per-batch crash repro (sum_loop) added to the drill.
  - **MEM tier batch 1** (tc `2700ec0c`): the IRF_RAW mechanism (node
    flags; ir_record_raw; node-aware barrier check) — lifted nodes carry
    semantics but keep barrier-hood BY CONSTRUCTION; per-family relax is
    a later one-line change.  IR_LDA_CELL/IR_STA_CELL (cell identity as
    metadata); 280 sites (transfers raw-routed through existing ops +
    constant-name _fcc_* cells).  **lift_purity.py wired into
    tests/run.sh** (fail-closed; comment-aware) after the
    eats-its-own-lowering class fired at scale (case IR_TAX recording
    IR_TAX; 15 contaminated *_lower helpers; 8 latent double-dispatch
    sites the gate found beyond the crashes).
  - **STACK batch** (tc `158caae5`): 84 raw PHA/PLA sites → raw-flagged
    IR_PUSH_A/IR_POP_A; the purity gate caught its 12 contaminations
    PRE-CRASH.
  - **Census: 1,383 → 817 raw sites (−41%)**, output provably unchanged
    at every step (goldens-without-REGEN ×4, differential harness ×4).
  - **NEXT (T2-3 continuation)**: variable-name (%s) MEM sites wait on
    T2-1's interning (a static-buffer ptr would alias); MISC ALU
    one-liners (CLC/SEC/ADC #%) lift as IDIOMS (add/sub/compare), not
    atomized strings (the review's unit-of-work rule); [_fcc_ptr]
    deref cluster (19) as a deref-idiom family; the remaining CTRL tail
    (51: compound/variable-target/epilogue).
- **[~] T2-1** — foundation + core tables banked:
  - tc `eff70cae`: dedup-interned identifiers (FNV-1a open-addressing;
    same spelling = same canonical pointer TU-wide; g_ident_unique in
    the Part-V stats).
  - tc `f72504d3`: **Local/Global/Func names = interned pointers;
    lookups = pointer scans** (each lookup canonicalizes its query with
    one O(1) probe, replacing strlen+memcmp per entry).
  - tc `76940884`: **ALL NINE tables converted** (Field/Struct/Typedef/
    EnumConst/StaticAlias/UserLabel joined) — every name lookup in the
    compiler is a pointer scan; struct_field_lookup's union-arm
    recursion included.  Truncation behavior kept bit-identical (each
    writer's own clamped length).  Last remaining name array = the pp
    macro table (T2-2's domain).
  - tc `d5fb7b78`: **%s-operand cell lift** (94 sites: 66 fpr_name +
    28 gname operands via interned cellp()/cellp2() — the T2-1 payoff
    consumed).  Census 734 raw sites (T2-0: 1,383; **−47%**).
  - **Re-lookup threading: YAGNI-CLOSED (2026-07-10, the maintainer may veto).**
    §T2's "stable symbol handles" goal is DELIVERED by the interning
    (symbols compare by identity; AST nodes carry sym_lc/gv/f).  The
    ~73 parse-path re-lookups are now O(1)-probe pointer scans, and the
    lookup-DRIFT class they theoretically risk is dead: fcc permits no
    declaration between a statement-head lookup and its builder's
    re-lookup (decls are statements; no compound literals / inline
    sizeof-decls), so both lookups always resolve identically.
    Threading handles through the dispatcher signatures would touch the
    most load-bearing parse code for zero behavioral delta — the risk/
    value inverted.  Revisit only if a scope-model change (e.g. C99
    mixed decls) lands.
  - tc `b7e47423`: **ALU idiom lift** — IR_ADD_CONST/IR_SUB_CONST (58
    CLC+ADC/SEC+SBC pairs; the constant machine-readable).  Census 642
    (T2-0: 1,383; **−54%**).
  - tc `8f80b1e4`: deref family (54 sites; carrier cell + indexed flag
    as metadata) + the 167-site cell-ptr canonicalization retrofit.
  - tc `ab8e6c22`: parameterized cells (60 sites via cellpf-composed
    interned names).
  - **T2-3 CLOSED at −61% (1,383 → 544) — the stop rule binds.**  The
    remainder = cold format-variants of lifted families (~90),
    cold-path immediates (~83; IR_LOAD_LIT owns the hot path),
    un-idiomed ALU inside heterogeneous hand sequences (~95 — the
    anti-pattern to atomize), SP/frame idioms coupled to the Track-2
    pass's own SP model (~50), and jump-table data rows (16).  The
    allocator-relevant surface (CFG, widths, cells, derefs, stack
    deltas, const arith) IS lifted; the residual's idiom boundaries are
    dictated by the CONSUMER — structure them during Track-2 phase 2.
  - THEN: T2-2 (pp) with adversarial fixtures first; T2-4 close-out
    (memory budget to the maintainer).

## RELEASED (2026-07-10): toolchain v1.1.0 (b554fe88) + FGX v1.0.1
(599cf1c5, pinned v1.1.0) — the whole T2-0/1/3 campaign shipped with all
gates (goldens 382/0, farcalls, multibank sweep MULTIBANK_VERIFIED, FGX
build + MAME fast 21/21).  T2-2 proceeds on feat/t22-pp-token-pass (both
repos) with the released tags as fallback.

## T2-2 execution status

- **[~] Stage 0 — adversarial fixtures** (tests/M36/pp_adv{1,2,3}.c;
  385/385 goldens with them REGEN'd; runtime CALIBRATION in flight at
  the compaction boundary — VERIFY oracle.json records 42 for all three
  before committing, floatfield-style assert):
  - adv1: #if-0 un-lexable prose (line-skip never lexes); #if 5/0 -> 0;
    bare funclike name in #if -> 0.
  - adv2: no accidental paste (`1 - 1` from macro juxtaposition);
    object-macro chains; self-reference guard (`#define x x_ + 1`).
  - adv3: comma-in-parens = one arg; body-chain rescan (H->G->body);
    multi-token args.  **DISCOVERY (now in fcc-known-issues): funclike
    CALL in ARGUMENT position does not expand — G(G(1)) dies
    'undeclared' fail-loud.  Body rescan works; arg-position doesn't.
    The flip must preserve or consciously fix + re-pin.**
- **[x] Stages a+b MERGED** (tc `0c352777`, 2026-07-10) — one token-level
  expansion engine for object AND funclike macros + the token #if
  evaluator.  **Deviation from the reviewed ladder, evidence-driven**:
  an object body's token slice can contain a funclike CALL (fcc's own
  tword.h INCREF pattern — the self-host target), and a stage-a-only cut
  would need a token->text re-render bridge (string re-escaping) that
  stage b immediately deletes.  Preceded by **pp_adv4** (tc `0f9a67eb`):
  pins funclike-in-object-body, keyword/long-literal bodies, string-
  escape args, multiline args, __VA_ARGS__ join, #if implicit-parens,
  empty-body->0, defined()-via-body — CALIBRATED 42 on real FGX.
  Faithfulness mechanics preserved by construction: lazy frame pop
  (guard covers a body's own last token), same-source-only '(' lookahead,
  guard-blocked calls consume+drop args (the pinned G(G(1)) line),
  arg-count dies before the guard, #if bodies evaluate as complete
  expressions (implicit parens), inactive-arm exprs never tokenized.
  Declared divergences (corpus-verified absent): #if-line comments no
  longer corrupt the expression (bugfix; authoring pp_adv4 hit it — the
  oracle read 40 not 42 until the comment moved off the #if line);
  macro depth no longer shares the include-depth budget.
- **[x] Stage c** (tc `bbf5ab45`) — #include = recursive
  tokenize-into-vector at the directive point; PpFrame/g_pp_stack/
  pp_push_file/pp_pop DELETED; relative includes resolve via a
  saved/restored current-path; cond stack stays global (unbalanced-#if
  leak semantics unchanged).
- **[x] T2-1 rider** (tc `85e1cd0d`) — pp macro table (the LAST name
  array) on interned names; param/__VA_ARGS__ matches = pointer
  compares.  Every name lookup in the compiler is now a pointer scan.
- **Gate evidence (every increment)**: make clean 0 warnings; sum_loop
  rc=0; test-lex ok; goldens 386/386 WITHOUT REGEN; differential runtime
  harness 386/386; **elvis 29-TU corpus byte-identical vs released
  v1.1.0 fcc output** (incl. -DTMPNAME string-body defines) — old fcc
  built from b554fe88 in a worktree for the comparison.
- Invariants held: inactive-branch skip stays CHAR-LEVEL; delete-forward
  (no toggle); stderr positions OUT-OF-GATE; `#`/`##` unsupported
  (deferred, recorded); arg-position pin (pp_adv3) preserved.
- **[x] T2-2 COMPLETE.**
- **[~] T2-4** — memory report DONE (see below); BUDGET decision =
  THE MAINTAINER; redesign-doc §T2 status block written; release train pending.

## T2-4 memory report (FCC_MEM_STATS, five largest elvis TUs, 2026-07-10)

| TU | toks | tok bytes | intern | idents | mtoks (macro-body toks) | AST peak |
|---|---|---|---|---|---|---|
| cmd1.c   | 8,676 | 486KB | 10.2KB | 990 | 213KB | 283 (36KB) |
| redraw.c | 7,277 | 408KB |  8.0KB | 942 | 261KB | 916 (117KB) |
| curses.c | 5,424 | 304KB |  8.4KB | 960 | 154KB | 445 (57KB) |
| tio.c    | 6,241 | 349KB |  8.1KB | 968 | 237KB | 440 (56KB) |
| vi.c     | 5,942 | 333KB |  7.4KB | 909 | 130KB | 769 (98KB) |

Worst-TU front-end footprint ≈ **0.9MB at host sizeof(Tok)=56B**
(toks 486KB + mtoks 262KB + AST 117KB + intern 10KB — maxima across
TUs).  Scaling notes for the budget decision: (1) a self-host Tok can
pack to ~16B (kind:1, line:2, value:4, ptr:4, len:2 + padding) → toks
~139KB, mtoks ~75KB, ≈ 350KB worst-TU total; (2) macro-body token
vectors are dominated by system headers re-tokenized per TU — sharing
or lazy-freeing dead-macro bodies is available headroom; (3) fcc's own
largest TU (parse_stmt.c, 5,124 lines) is ~2.7× cmd1.c by lines →
naive scale ≈ 0.9-1.3MB packed.  A IIgs self-host needs the multi-bank
malloc arena (T5/T8 world) — per-function AST windowing already caps
the parse side.

**BUDGET DECISION (the maintainer, 2026-07-10): DEFERRED — catalogued, not set.**
Compiler CORRECTNESS comes first; once fcc is fully fleshed out end to
end, true self-host work begins and this report is its input.  Self-
hosting stays the north star; memory-shape items are tagged for that
phase rather than gating current work.

## Gates

Goldens WITHOUT REGEN everywhere (byte-identity is the definition of done
for a front-end-only change); stack_check; run_runtime full oracle at
increment boundaries; differential harness on every commit; MAME fast
group before merge.  FGX-side: nothing changes (no wire, no ABI) — one
`build.sh disk` + battery at the end as insurance.

## Risks (for the review)

- lex_pp rework is the highest-regression-risk file in the toolchain;
  the token corpus must cover pathological macro cases BEFORE the flip
  (fail-closed: keep the char-level path behind an env toggle during
  bring-up? — reviewer to rule; the FCC_OLD_EXPR precedent says delete,
  the differential harness says both can coexist briefly).
- The IR_TEXT lift touches emit.c's 1008 sites — sequencing vs the
  shape-classifier data, not alphabetically.
- Self-host memory budget (Part V): token vector + AST peak on the
  largest elvis TU should be measured during T2-2 (the redesign asks).
