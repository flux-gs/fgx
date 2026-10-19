# Phase-2 audit: fcc multipass front-end — seam map, validation net, increments

*2026-07-06. Two exhaustive sweeps (emit/IR seam; corpus + validation net)
on top of the 2026-07-05 architecture audit (§I.4, T2). This is the
implementation-grade plan for the redesign's Phase 2.*

## Decisive findings

1. **The reusable asset is the `emit_*` helper layer, not a structured IR.**
   1,595 raw `ir_emitf` sites live in the parse files (parse_expr 290,
   parse_stmt 419, emit.c 879) vs only 43 structured `ir_record_op*` sites.
   Of 139 emit.c helpers (96 exported), the label/branch/literal/stack/
   prologue/compare cluster is PURE (explicit args, no parse state) and
   survives the rewrite unchanged.
2. **The parse-coupled state is one small cluster**: `g_expr_type` (162
   emit.c reads — the deepest coupling), `g_expr_unsigned/struct_id/fn_sig`,
   `g_binop_unsigned`, `g_s_delta` (co-owned: emit helpers do the mechanical
   ±, the parser adds call-site deltas), `g_loop_ctx`/`g_sw_stack` stacks,
   and `g_cur` for die() positions. These become AST-node fields/args in the
   AST step — and CANNOT be half-migrated (emit reads them positionally).
3. **ir.c is already the per-function seam.** `ir_begin_func`/`ir_end_func`
   bracket a record/replay buffer; promotion/regalloc/isel hang off it.
   Invariants a new front-end must preserve: structured ops interleaved at
   the exact emit points (promotion matches positionally; IR_TEXT is a
   barrier), `g_s_delta` snapshots recorded at emit time,
   `ir_local_mutated_since`/`ir_cur_n` bracketing around index
   sub-expressions, and the addr_taken/raw_accessed escape flags.
4. **Rewind sites: 17 confirmed.** Ten raw `g_pos` saves die with a token
   vector alone; the six `lex_peek_save/restore` sites exist precisely
   because a peek can cross a pp frame boundary — they only die if the
   preprocessor becomes a token pass FIRST or concurrently; the
   char-scan disambiguator (parse_stmt.c:3538-3690) becomes a bounded
   token-index walk.
5. **The 8 call emitters** (6 parse_expr, 2 parse_stmt): the named-call
   expr/stmt pair is near-byte-identical; `emit_struct_byval_arg` and
   `stash_fnptr_callee`/`call_stashed_fnptr` are the existing extraction
   precedents. One `emit_call_marshal(...)` needs: argc + per-arg byte
   weights, RtlArgs reversal state (already shared), far/near, callee kind
   (named/libc/indirect/stashed), return handling (preserve vs discard).
6. **The textual golden net is useless mid-rewrite.** run.sh diffs .s text
   + cmp's binaries — ALL 364 churn on day one of any emission-order
   change. What survives: **oracle.json (344 MAME exit codes) + the
   multibank sweep (34) — the only mid-rewrite correctness nets.** The
   redesign's "goldens + oracle green throughout" is unachievable as
   written; the realistic invariant is *oracle + multibank green
   throughout; goldens regenerated per milestone*. (Also reconcile the
   count drift: redesign says 347; actual = 364 textual / 344 oracle.)
7. **Differential precedent exists**: `run_runtime.py --use-fas-bin` swaps
   the assembler stage and re-validates exit codes against the same
   oracle. Clone the pattern for old-fcc-vs-candidate-fcc.
8. **Corpus** ≈ 420 compilable TUs (364 fixtures + preproc/multitu/lex/
   farcalls + 43 multibank + ~71 built userland + 29 elvis TUs).
9. **Memory budget**: largest TU (jsh.c) ≈ 12.8k tokens whole-TU; largest
   elvis TU (cmd1.c) ≈ 7.5k. Per-function windowing (ir.c's buffer is the
   proof) makes the governing peak the largest FUNCTION, far smaller.
   Fine for self-host; the ~1MB static tables must shrink regardless.
10. **Language surface**: the M0-M34 checklist is the acceptance contract
    (agent report in the session record); stringize/token-paste have NO
    fixture and are presumed absent — verify, then keep rejecting.
    The fail-closed deferral list (B-3/B-5/B-7/C-3/D-1/D-3/E-2/F-1,
    capacity ceilings) may keep dying — but elvis/jsh/sed likely exceed
    some ceilings; confirm headroom per-TU during the AST step.

## Increment plan (each gate-green, merged under the hold)

- **Increment 0 — differential harness** (prerequisite for everything):
  `run_runtime.py --use-fcc <path>`: rebuild each fixture's `fcc_output.s`
  with a candidate fcc binary, reassemble, boot, compare exit codes to
  oracle.json. Also wire the multibank sweep to accept a candidate fcc.
  This is the net that replaces the textual goldens mid-rewrite.
- **Increment 1 — pp → token pass + token vector** ✅ DONE 2026-07-06
  (kills the bug class): `lex_tokenize_all()` drives the unchanged
  `scan_tok()` to EOF once — all #include/#define/#if resolution and macro
  expansion happen there, in source order — recording every token in
  `g_toks[]` with IDENT/STR text interned into a block-chained arena.
  `next_tok`/`peek_tok` are cursor ops; all 17 rewind sites became
  `LexPeek {idx, cur}` save/restores; the retire ring, the pushback, the
  G39/G39b for-step frame-capture + macro-buffer-ownership detach, and
  `pp_push_synthetic` are DELETED (`pp_pop` frees eagerly).  The G20/G21/
  G41 `(`-statement disambiguator is a token walk; the re-dispatch splices
  the wrapper `)` out with a transparent `TOK_SKIP` kind.  Deviations from
  the sketch: the pp frame stack SURVIVES as pre-pass-internal state
  (includes still nest — it is simply no longer parser-visible), and the
  string-based #if evaluator stays (it is the pp's constant evaluator,
  orthogonal to source replay).  Validation: goldens 364/364 BYTE-IDENTICAL
  with no regen; elvis differential (all 28 TUs old-fcc vs new-fcc,
  code+data segments) byte-identical; farcalls 3/3; multibank sweep 34/34;
  runtime oracle green; the stale pre-soft-stack `.expected.s` relics in
  tests/preproc + tests/multitu fail identically under BOTH compilers
  (new == old byte-for-byte there too).
- **Increment 2 — one call emitter** ✅ DONE 2026-07-06:
  `emit_call_marshal_args(ptypes, pstruct_ids, n_declared, &rtl, &argc)`
  replaced the eight near-identical arg loops; param types come from Func
  or FnSig (same LocalType element), the by-value-struct branch gates on
  the struct-id table (NULL for fn-ptr sigs).  Callee acquisition, argc
  checks, the three cleanup shapes, and return bookkeeping stay per-arm.
  Behavioral delta confined to fixture-free latent paths (the declared-
  LT_FLOAT coercion existed in only 2 of 8 arms; now uniform).  Net −239
  lines.  Validation: goldens 364/364 byte-identical; elvis 28-TU +
  userland 83-TU differentials byte-identical vs the Increment-1 fcc;
  FCC_OVERRIDE sweep 34/34; full `--use-fcc` differential oracle 344/344
  (the Increment-0 harness validating a candidate exactly as designed).
- **Increment 3a — expression AST** ✅ DONE 2026-07-06 (toolchain main
  07f615b, branch feat/fcc-ast-expr, tag pre-ast-expr; UNRELEASED per
  hold): the whole expression grammar builds a per-expression AST
  (g_ast[] node pool + kid/field-hop pools, resolved-symbol payloads,
  bottom-up result typing) and walks it through the EXISTING emit
  helpers — parse_expr/parse_comma/parse_assign/parse_unary flip;
  FCC_OLD_EXPR=1 retains the historical grammar (A/B differential in one
  binary).  As designed, g_expr_* survives unchanged (helpers keep
  maintaining it at walk time).  Hybrid emit helpers were split into
  walk-callable glue (ipv, cio, air head/tail).  One flip bug
  (nested-call kid-span capture) — everything else was transcription-
  faithful on the first run.  Gates: goldens 364/364 byte-identical
  through the AST path; FCC_AST_CHECK corpus sweep zero real type
  divergences (N_ELEM_ADDR glue class exempted); elvis 28-TU + userland
  83-TU old-vs-new differentials byte-identical; multibank 34/34;
  runtime oracle 344/344, 0 regressions.
- **Increment 3b — statement trees** ✅ DONE 2026-07-06 (toolchain main
  8017c5e, branch feat/fcc-ast-stmt, 9 commits, tag pre-ast-stmt;
  UNRELEASED per hold): parse_stmt = { ast_reset();
  walk_stmt(build_stmt()); } — one statement, one tree.  Phase 1 flipped
  every non-control-flow dispatcher arm to build+walk-immediately
  (sequential emission ⇒ per-arm landings, goldens green each commit; no
  mode flag needed); phase 2 made if/while/do/for/switch/block/decls
  trees with child subtrees.  DEAD: the for-step cursor replay (step
  subtrees walk after the body — pure traversal) and the
  collect_switch_cases pre-scan (build-time case collection; walk-time
  label allocation in encounter order = identical numbering; function
  deleted).  Declarations register symbols at build; initializers are
  nodes (scalar stores reuse N_STORE_VAR; S_DECL_ARRINIT/_STRUCTINIT
  zero-fill at walk).  Statement calls reuse the expression call nodes
  with AF_STMT_DISCARD cleanup variants; loop-hot marks, loop-ctx,
  labels, and IR_LOOP markers all moved to walk time in parse order.
  Gates: goldens 364/364 byte-identical; elvis 28-TU + userland 83-TU
  differentials vs the 3a baseline byte-identical; multibank 34/34;
  FCC_AST_CHECK corpus sweep 0 failures (statement store nodes carry the
  RHS descriptor with emit_store_local's float itof conversion
  mirrored); runtime oracle 344/344, 0 regressions.
- **Walker purity** ✅ DONE 2026-07-06 (main fb3a196, tag
  pre-walker-purity): every walker-side DECISION read of runtime
  g_expr_* replaced with the child node's descriptor (corpus-proven
  equal by FCC_AST_CHECK) — walkers are pure functions of the tree, so
  Phase-3 re-lowering can swap walkers without touching parse state.
  Builders verified g_s_delta-clean.  The g_expr_* globals survive only
  as the emit helpers' internal value bookkeeping.
- **Increment 4 — stable Func identity** ✅ DONE 2026-07-06 (main
  1c6b88a, tag pre-stable-handles): g_cur_fn_idx names the function
  being compiled; prototype promotion is IN PLACE (the remove-and-
  reappend renumbering, funcs_remap_promote, and the Global.init_*
  index-patch loops are deleted); build_decl's G42 slot swap retired.
  Function indices are valid forever.  FIXED A LIVE LATENT MISCOMPILE
  found by the increment's differential: ed(1) address()'s `return 0`
  NULL-bank normalization gate read the LAST slot's return type — after
  a mid-body K&R implicit declaration that was the callee's int, so the
  guard silently skipped and NULL leaked a stale bank into 4-byte
  pointer compares.  Red-first regression: multibank construct 35
  (c35_ret0bank) — 35:F old, 35/35 fixed.
- **Increment 3c — per-function trees** ✅ DONE 2026-07-06 (main
  0aa1ad3, tag pre-perfn-tree): a function body builds as ONE tree
  (leading decls + all statements) and a single walk emits it — the
  per-function AST window; pools 64K nodes / 32K kids per window;
  per-statement parse_stmt/parse_decl retired.  Oracle 344/344.

## PHASE 2 COMPLETE (2026-07-06)

Every increment of this plan is landed on toolchain main (all
UNRELEASED under the hold): differential harness → token vector → one
call emitter → expression AST → statement trees → walker purity →
stable symbol handles → per-function trees.  fcc's executable grammar
is typed per-function trees walked through the emit layer by pure
walkers over permanent symbol identity — byte-identical to the
historical single-pass emission across goldens (364), differentials
(elvis 28 TU + userland 83 TU), the FCC_AST_CHECK descriptor net, the
multibank sweep (35 constructs incl. the new c35), and the runtime
oracle (344), re-proven at every landing.

**Phase 3 (32-bit pointer value flip) now has its full substrate.**
Remaining niceties, non-blocking: migrating g_expr_* out of the emit
helpers themselves (signature churn, payoff mostly realized), unsigned
literals (deferred here from A-1), and retiring the FCC_OLD_EXPR
fallback grammar once Phase 3 stabilizes.

  **Design (settled 2026-07-06, from the Increment-2-era code reads):**
  1. **The audit's "atomic g_expr_* migration" decomposes.**  `g_expr_type`
     (and unsigned/struct_id/fn_sig) is the compiler's value descriptor for
     "what's in A": emit helpers WRITE it as their result tag (e.g.
     emit_load_lit → LT_INT) and both layers read it.  A walker that
     replays the same helpers in parse order therefore maintains the whole
     cluster FOR FREE — the globals survive the first AST landing
     unchanged (3a), and killing them (moving to node fields/walker state)
     becomes a separate later step, safe because 3a already proves walk
     order == parse order.
  2. **Build-time typing is narrower than it looks.**  The builder needs
     node RESULT types only for the decisions the parser currently makes
     BETWEEN sub-emissions — binop variant selection (ptr stride /
     bank-stash in parse_add_expr, signed-vs-unsigned helper choice), call
     arg weights, deref classification.  These become bottom-up
     `node->type` annotations computed by the same rules the helpers
     apply; emission itself stays in the helpers.
  3. **Self-check net:** an `FCC_AST_CHECK=1` walker mode asserts
     `g_expr_type == node->type` after every expression node across the
     420-TU corpus — every divergence between build-time typing and
     helper-maintained typing fails loud.
  4. **Node inventory mirrors the existing dispatch arms**, not abstract C
     semantics: each syntactic fast path (`*p++ = rhs`, member RMW,
     paren-lvalue, postfix chains) keeps its own node kind so the walker
     reproduces the arm's exact codegen.  parse_primary (~1400 lines) and
     parse_unary (~630) are the bulk; the binop ladder (mul/add/shift/
     relat/eq/bit/logic — uniform ~40-line functions) and ternary/assign/
     comma are mechanical.  parse_const_* (no emission) stays as-is.
  5. **Sub-increment ladder:** 3a expressions (build+walk, globals kept,
     byte-identical goldens target) → 3b statements (if/while/for/switch
     as trees; for-step ordering becomes a tree walk, cursor jumps die;
     parser-side `g_s_delta` call-site deltas move to the walker) → 3c
     declarations/prologue.  Each lands gate-green under the hold with
     the differential harness as the primary net.
  6. **Scale:** 3a alone touches most of parse_expr.c's 3,400 lines —
     plan a fresh session per sub-increment, executing from this doc.
  7. **Development strategy (3a kickoff, branch `feat/fcc-ast-expr`
     created off toolchain main d840d35):** ADDITIVE ONLY — write
     `build_*` (tokens → nodes, no emission) and `walk_*` (nodes → the
     existing emit helpers, byte-exact glue transcription) alongside the
     untouched parse_* functions; nothing calls them until the single
     flip commit turns `parse_expr()` into build+walk.  The tree compiles
     green at every commit; goldens only gate the flip.  Within
     expressions the flip is all-or-nothing (a converted parent cannot
     hold an unconverted emitting child — emission order would invert),
     so primary/unary/assign must all build before the flip.
  8. **Helper predicate/emit splits:** some emit helpers make the
     VARIANT decision internally and report it by return value —
     e.g. `emit_inline_mul_const(k)` / `emit_inline_divmod_pow2(op,k)`
     return whether they inlined, and parse_mul_expr emits the libcall
     fallback only if not.  The builder needs the decision WITHOUT the
     emission: split such helpers into a pure predicate (used at build
     time to annotate the node variant) + the emitter (used by the
     walker), keeping the emitted bytes identical.  Audit for the full
     list while converting; known so far: inline mul/divmod.
- **Increment 4 — stable symbol handles**: retire index-based Func/Local
  identity + the promotion renumbering remap (`funcs_remap_promote`).

Sequencing note: 0 → 1 → (2 anywhere) → 3 → 4. T1 (pointer-model flip,
Phase 3) waits for 3, per the redesign's rationale.

## Risks carried forward

- Emission-order churn makes bisection hard mid-increment: keep the
  FCC_NO_REGALLOC/FCC_TAC_LOWER-style env-gates pattern for each new pass
  (e.g. FCC_OLD_LEX=1 fallback during Increment 1 bring-up).
- The g_s_delta model is the silent-killer state: any missed delta
  miscompiles every later `n,S`. The differential corpus (420 TUs, exit
  codes) is the net for exactly this.
- elvis TUs are compile-targets for the differential corpus even though
  elvis is off the table as a workload (build-only, no boot).
