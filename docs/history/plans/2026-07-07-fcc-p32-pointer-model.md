# P3-2 — T1 pointer model: audit, design, increments

*2026-07-07.  Phase-3 train increment P3-2 (the core, Phase-2-sized).
Sources: `docs/history/plans/architecture-redesign.md` §T1, the Phase-3 train plan
(`2026-07-06-fgx-phase3-clean-break.md`), the Phase-2 record
(`2026-07-06-fcc-phase2-frontend.md`), and a fresh audit of the fcc
pointer-lowering surface (this doc's findings).  Every increment lands
gate-green under the release hold.*

## Decisive findings (2026-07-07 code audit)

1. **Pointer STORAGE is already uniform 32-bit.**  `type_size_bytes`:
   `ISPTR(t) → 4` everywhere — locals, globals, struct fields
   (offset@+0..1, bank@+2, pad@+3), initialized globals via
   `FGX2_LONG_PTR` relocs.  T1 is a flip of the **value carrier**, not
   the memory layout: pointer rvalues ride `A` (offset) + the shared DP
   global `_fcc_ptr+2` (bank), and every general deref first *stages*
   the offset into `_fcc_ptr` before `LDA [_fcc_ptr]`.
2. **The carrier surface**: 195 `_fcc_ptr` textual sites in emit.c, 108
   in parse_expr.c (~half in the dead old grammar), 43 in parse_stmt.c;
   ~40 pointer-family emit helpers (deref/addr/load/store/walk/ipv
   families).  The whole multibank whack-a-mole class
   ([[feedback_fcc_multibank_untested_whackamole]], ~68 catalogued
   single-bank-invisible sites) is this carrier going stale.
3. **Bank-source decisions live in 59 mode branches** (`g_data_out`/
   `g_far_calls` conditionals: emit.c 38, parse_expr.c 17,
   parse_stmt.c 4), each choosing per-site among: stored bank byte
   (FGX2), PHB=DBR (FGX2 data addr), PHK (FGX1 convention — bank
   re-derived at use because **FGX1 has no loader bank-byte reloc**),
   `#0` (NULL normalization: `emit_load_value_bank` + the S_RETURN c35
   site), and the hidden `_Fa` FGX2_LONG_PTR for function addresses.
4. **The model to generalize already runs whole functions**: the DP-IMG
   promoted pointer pair (`_fcc_img{k}`/`{k+1}` = offset+bank, deref
   `LDA [_fcc_img{k}],Y`) — ir.c's B1b promotion proves self-contained
   DP pairs are correct and FAST (that's why promotion wins).
5. **DP space is not a constraint**: `$10-$BB` of the task DP page is
   free.  A far-pointer register (FPR) band fits clear of the libc
   scratch bands (`$E4-$EA`, `$F2-$F7` — clobbered by libc/shims, so
   FPRs must not live there if live across calls; they won't be —
   caller-save).  `_fcc_ptr` ($E8) and `_fcc_ptr2` ($FC) retire with
   the flip; `_fcc_fp` ($F8) retires at P3-3.
6. **ABI seams**: args already push 4 bytes (bank+pad word, then
   offset — `emit_push_ptr`, 5 instructions; from an FPR it becomes
   `PEI fpr+2 / PEI fpr`, 2).  Pointer RETURN = `A` + `_fcc_ptr+2`
   (the c35 latent-miscompile site) → becomes a canonical FPR0 return.
   The libc shim contract is the *pushed layout*, which does not change
   — the caller-buffer-bank rule keeps working unmodified.
7. **Backend coupling**: structured IR pointer ops
   (IR_LOAD/STORE_PTR_LOCAL[_IMG], IR_DEREF_*, the walk-store family)
   are positionally matched by the promotion pass (record/replay);
   peephole rules key on `_fcc_ptr` textually (staging elision, bank-
   byte liveness).  Both re-target, neither blocks.
8. **FCC_OLD_EXPR is a casualty, not a tool**: the old grammar
   (~3,000 lines of parse_expr.c) calls the same emit helpers — it
   cannot survive the flip, and the A/B net it provided is superseded
   by the Increment-0 differential harness (old-BINARY vs new-BINARY).
   Delete it FIRST; it also halves parse_expr.c's conversion surface.
9. **The one-mode question has a real constraint**: retiring
   `--far-calls`/`--data-segment` means fcc always emits the
   stored-bank convention — but single-segment output then needs
   load-time bank fixup for *static pointer initializers* (runtime
   stores stamp their own banks), and the FGX1 loader has none.  The
   oracle's 344 fixtures are FGX1 today.  Resolution direction:
   move the harness wrappers to single-bank FGX2 (the loader already
   patches FGX2_LONG_PTR; P3-0 already runs every FGX2 tool, single-
   bank included, on the far pile) — FGX1 *emission* retires from fcc
   ahead of P3-6's format retirement.  Decided at P3-2.6, not before.
10. **Validation reality** (from the train plan): goldens churn 100%
    BY DESIGN at the flip.  The net = runtime oracle (344) + multibank
    sweep (35+, exit 42) + FCC_AST_CHECK + MAME FGX2 battery + the
    old-vs-new behavioral differential (exit codes, full ~420-TU
    corpus compiled by both compilers).  Goldens regenerate per
    milestone and gate only *within* a milestone.

## Design

**Value representation.**  A pointer-typed expression value is a
**far-pointer register**: a 4-byte DP slot (offset@+0..1, bank@+2,
pad@+3) from a small walker-allocated band — FPR0..FPR{N-1} (start
N=4; band placed in free DP `$10-$BB`, exact address chosen at
execution; 8 slots reserved).  Non-pointer values stay in `A` (+
`_fcc_long_hi` for longs) exactly as today.  The walker tracks, per
pointer-valued node, which FPR holds its result — a walk-time stack
discipline (allocate on produce, free on consume), NOT a register
allocator: depth = live pointer temps in one expression (≥2 only for
ptr-vs-ptr binops and nested member chains; spill to the HW stack on
overflow, expected never in real code — log if hit).

**One funnel per operation** (each the ONLY place its decision lives):

- `fpr_load_sym` / `fpr_addr_of` — materialize a pointer from a
  symbol.  The **single bank-source decision point**: stored bank byte
  (pointer-typed home), PHB (address of data-segment symbol), PHK
  (address of code-segment object: function via `_Fa`, string
  literal), `#0` never here (see literals).  Segment kind comes from
  the symbol, not from a mode flag.
- `fpr_lit` — literal in pointer context: offset=k, bank=0.  Kills the
  scattered NULL normalization (emit_load_value_bank, the S_RETURN
  arm) — build-time node property, one emitter.
- `fpr_deref_load` / `fpr_deref_store` — `LDA/STA [fpr]` or `[fpr],Y`
  by width (byte/word/long/float via the existing shapes).  The
  staging copy into `_fcc_ptr` DIES — derefs go direct, like the
  promoted path already does.  Constant-offset-into-Y fold lands here
  (cost lever #1).
- `fpr_add_off` / `fpr_sub_off` — pointer±int arithmetic on the offset
  half; bank untouched (bank-crossing pointers remain out of the
  model, as today).
- `fpr_push` — call-arg push (`PEI/PEI`), routed through `g_s_delta`
  exactly like `emit_push_ptr` (+4).
- `fpr_ret` / call-result — pointer returns in **FPR0** (callee loads
  FPR0 before epilogue; caller treats FPR0 as the result's home).
  Caller-save discipline: any FPR live across a call spills to the HW
  stack (through `g_s_delta`); FPR0..N are call-clobbered.
- `fpr_cmp` — pointer comparison compares offset AND bank (4-byte
  compare shapes exist from the long tier).
- fn-ptr dispatch — the 3-layer call consumes offset+bank from an FPR
  instead of A+`_fcc_ptr+2`; mechanism otherwise unchanged (T3
  replaces it with linker JML trampolines later).

**Control-flow join rule**: `?:` and `&&/||` arms producing a pointer
must deposit into the SAME FPR (the walker pins the target slot before
walking the arms) — the join-point analog of today's "result in A".

**What this kills structurally**: the shared-carrier staleness class
(chained-deref bank drop, tget bank drop, kbuf, arr2d PHK-vs-PHB, the
c35 return-bank leak — every one was `_fcc_ptr+2` or PHK-vs-PHB
scatter); the 59 mode branches; `_fcc_ptr`, `_fcc_ptr2`, and the
deref staging copies; the S_RETURN normalization; ~5-instruction arg
pushes.  **Cost**: pointer loads from memory get the full 4-byte read
even where FGX1 used to skate on PHK (+~6 cycles/load); levers =
Y-fold, FPR reuse across consecutive derefs of the same pointer
(walker-level; promotion already covers the hot-local case), DP-IMG
promotion unchanged.  P3-1(c)'s hard-vs-soft numbers are the size-
measurement precedent; measure the same TUs old-vs-new at P3-2.5.

**Promotion interplay**: the img band ($C0-$DF) and the FPR band are
disjoint; a promoted pointer local's home is an img pair, and
`fpr_load_sym` from a promoted local is `img→fpr` (or, lever #2, the
deref funnels accept "pointer already in a DP pair" and use the img
pair directly — that's today's IR_*_IMG forms, preserved).

## Increment ladder (each gate-green under the hold, fresh session each)

- **P3-2.0 — decks clear.  ★DONE 2026-07-07** (toolchain main 1a78867,
  feat/p32-decks-clear, tag pre-ptr-model; under the hold).  −2,949
  lines; parse_expr.c 6,999→4,088, its `_fcc_ptr` surface 108→35.
  Baseline = rebuild from tag pre-ptr-model (goldens prove the commit
  emission-identical, so the tag IS the pre-flip compiler).  Gates:
  goldens 364/364 byte-identical, sweep all-green, oracle 344/344.
  Original spec: delete the FCC_OLD_EXPR grammar
  (parse_primary/parse_unary_old/parse_expr_old/... ~3,000 lines) +
  the env hook; pin the pre-flip fcc as the differential baseline
  (tag `pre-ptr-model`; build and stash the binary).  Gate: goldens
  364 BYTE-IDENTICAL (dead code only), oracle, sweep — the last
  all-nets-textual checkpoint.
- **P3-2.1 — scaffolding.  ★DONE 2026-07-07** (toolchain main 09a0600,
  feat/p32-scaffold, tag pre-p32-scaffold; under the hold).  Landed:
  the four model-edge constructs — ALL GREEN under today's compiler
  (sweep now 39/39), so they are behavior locks for the flip, not
  red-first bugs; the FPR band `_fcc_fpr0..7` @ `$98-$B7` (inert EQUs)
  + DP-map update; and a live front-end fix c39 flushed out —
  **pointer-returning fn-ptr declarators** (`char *(*fp)()`) were an
  artificial reject in parse_fn_ptr_declarator (return-type stars never
  consumed; FnSig.return_type was always a full tword and every consumer
  reads it generically) — fixed + golden fnptr_ptrret (365th), depth-2/
  struct-ptr/array-of forms accept, struct-by-value return stays
  deferred.  Gates: goldens 365/365 (364 byte-identical), sweep 39/39
  MAME-booted, oracle/battery unchanged by byte-identity.
  **Re-scope:** the walker FPR slot tracker + funnel emitters MOVE INTO
  2.2's bring-up commits — they are inseparable from the arm conversion
  (signatures settle only with the arms in hand); writing them blind
  here invited churn, and the flip branch lands them additively before
  the flip commit exactly as planned.  Original spec: FPR band EQUs in
  fcc_runtime.s + the DP-map comment; walker FPR slot tracker; the
  funnel emitters written alongside the untouched helpers; nothing
  calls them.  RED-FIRST sweep constructs for model edges not yet
  covered (ptr-vs-ptr compare across banks, deep member-chain temps,
  FPR spill depth, ptr return through fn-ptr call).  Gate: goldens
  byte-identical; new constructs red under baseline semantics ONLY
  where they encode today's known-broken shapes, else green.
- **P3-2.2 — the expression flip.  ★DONE 2026-07-07** (toolchain main
  ec72cd5, feat/p32-ptr-flip, tag pre-p32-flip; under the hold).
  Landed: FCC_OLD_PTR dual walker (verbatim pre-FPR fallback,
  byte-identical); the full vocabulary (cmp = offset word + bank BYTE;
  Y-folded deref_field with the multibank set GENERALIZED from the
  LT-name list to ISPTR — char**/float* fields were PHK'd under FGX2;
  4-byte stores; spill/restore); THE FLIP (g_fpr_res result protocol +
  fpr_drop; walk_expr_root statement bridge until 2.3; PEI-pair ptr
  args — NULL args now bank 0; spill-all before call args; ternary
  join via walk-time LIFO slot identity; IR-structured ptr-local paths
  carrier-bridged until 2.5, ptr globals native).  THREE miscompiles
  killed: (a) N_ADD_IPLUSP scaled the POINTER offset, not the int
  (red-first M22/iplusp_scale, oracle-calibrated); (b) peephole
  pat_dead_store deleted a live FPR bank store — reads_loc didn't know
  PEI (jsh boot-dead, 0/344 no-marker; LESSON: new mnemonic ⇒ audit
  the peephole read/write classifiers first); (c) N_DOT_SCALAR
  ptr-field loads PHK'd single-bank but the soft stack is malloc'd
  from a HEAP bank outside PB — old code was stale-carrier luck; now
  emit_fpr_load_field reads the STORED pair in both modes.  Plus
  N_CAST keyed its ptr path on the star-count flag, missing typedef'd
  fn-ptr casts (FCC_AST_CHECK caught it).  FGX2 ptr equality = offset
  word + bank BYTE (the ptr→long reinterpret is dead); FGX1 stays
  offset-only; fn-ptr struct-field runtime stores keep offset+bank.
  Gates: goldens REGENERATED 366/366 (169 churn by design);
  FCC_OLD_PTR byte-identical on the 365 pre-flip fixtures; oracle
  344/344 ×2 (the behavioral differential — oracle.json encodes
  pre-flip-validated exit codes); sweep 39/39 ×2; FCC_AST_CHECK 0/366
  incl. the new FPR contract check (ISPTR(node.type) ⇔ g_fpr_res≥0);
  MAME FGX2 battery 19/19; whole userland disk builds + boots.
  Original spec: all-or-nothing within expressions — a converted
  parent cannot hold an unconverted pointer-valued child; helpers
  untouched (the funnels are new functions).
- **P3-2.3 — statements/decls.  ★DONE 2026-07-07** in three tranches on
  toolchain main: 2.3a `26461c0` (tag `pre-p32-stmts`) — deref-store
  family, S_RETURN on walk_fpr (c35 block dead), struct copy via two
  FPRs (`_fcc_ptr2` byval-arg-only; LESSON: LT_STRUCT values stay
  carrier-carried — walk_fpr bridges them, a sweep-only-visible bank
  class); 2.3b(1) `0202f07` (tag `pre-p32-conds`) — condition/discard
  offset-word collapse; 2.3b(2) `d57cb06` (tag `pre-p32-stmts2`) — 11
  field/array statement store arms (ptr-member ++/op= reads the member's
  OFFSET WORD, never the bank).  S_ARR_STORE / S_SARR_FIELD_IDX /
  S_PREINC_DEREF / decl-init stay self-contained-legacy until 2.5/2.6.
  All gates green at each tranche.
- **P3-2.4 — calls/ABI.  ★DONE 2026-07-07** on toolchain main `167e54a`
  (feat commit `7ce6866`, tag `pre-p32-callabi`).  ATOMIC callee+caller
  flip: S_RETURN ptr → `emit_fpr_ret` (FPR0 home; epilogue never touches
  the FPR band); caller capture via `fpr_capture_ret` — alloc lands
  ABOVE the spill window (spill_live leaves spilled slots allocated),
  `mov k←FPR0` only when something spilled, THEN restore_live.
  N_CALL_NAMED splits by binding: hand-asm libc shims (lb != NULL) keep
  the carrier return until libc.s converts.  By-value struct args on
  `emit_fpr_arg_window` (bank-0 HW-stack window) + `emit_fpr_struct_copy`
  — `_fcc_ptr2` now FCC_OLD_PTR-only.  `emit_call_indirect(int kc)` can
  consume a callee FPR; fn-ptr arms pass −1 (carrier) until the fn-ptr
  LOADS go FPR-native at 2.5 (bridging early = +7 instr/call site).
  FCC_OLD_PTR builds stay ABI-consistent end to end (S_RETURN gated on
  `old_ptr_mode()`).  Net −171/+146 lines; ptr-return goldens SHRANK
  (7-instr bridge deleted per return + per capture).  Gates: goldens
  366/366 (6 regen), AST_CHECK 0/366, oracle 345/345, sweep 39/39
  (c07_ret cross-TU ptr return + c36 capture-above-spill lock the seam),
  battery 19/19, disk builds.
- **P3-2.5 — backend re-target + cost pass.  ★DONE 2026-07-07** in two
  tranches on toolchain main: **2.5a** `c424fec` (tag `pre-p32-fprlocal`)
  — new structured IR ops IR_FPR_LOAD/STORE_PTR_LOCAL (+_IMG) carry the
  FPR index (u1) through the promotion retarget; every ptr-local funnel
  (fpr_load_sym, N_STORE_VAR, N_COMPOUND_VAR, parse_stmt kd arms) moves
  the value slot↔FPR directly — the 7-instr fpr_in/to_carrier bridge per
  access is dead; corpus −2,096 generated lines over 96 regens; load
  ends A = offset word (the kd-arm contract).  **2.5b** `3c14435` (feat
  `68ca7d2`, tag `pre-p32-fnptr`) — fn-ptr dispatch consumes the FPR
  (FPVAR via fpr_load_sym, FPFIELD via emit_fpr_load_field stored pair,
  stashed pull → FPR; FCC_OLD_PTR keeps carrier), and NEW walk_expr_stmt
  drops a discarded statement value instead of carrier-bridging it —
  walk_expr_root had emitted a dead 7-instr fpr_out per discarded
  ptr-valued statement since 2.2, masked only when a following dispatch
  overwrote _fcc_ptr+2 (82 fixtures shrank).  **Peephole re-key = no-op
  by audit**: every rule is a generic DP-loc pattern already firing on
  FPR shapes (zero literal `_fcc_ptr` keys).  **Size measurement** (vs
  `pre-ptr-model` baseline, FGX2 flags, instruction count): ed −6.4%,
  sed −6.0%, jsh −0.6% — the pointer model is a net size WIN; Y-fold/
  FPR-reuse levers NOT needed (deferred indefinitely as pure
  optimization).  **Deferred to 2.6**: S_ARR_STORE, S_SARR_FIELD_IDX,
  S_PREINC_DEREF, decl-init stay self-contained-legacy — their own-bank
  derivations are correct, and the mode collapse rewrites their
  g_data_out branches anyway (converting twice is waste).  Gates green
  at both tranches (goldens 366, AST_CHECK 0, oracle 345, sweep 39,
  battery 19, disk).
- **P3-2.6 — mode collapse.  ★DONE 2026-07-07** (feat branches under
  hold; toolchain feat/p32-modecollapse, FGX feat/p32-modecollapse-fgx).
  Landed in three tranches, each gate-green:
  **2.6a harness rebase** — fixtures build as REAL two-segment FGX2
  binaries (crt0_far + far libc pile, sweep shape; per-M-dir
  _seg0/_seg1/_fgx.json trio replaces 366 .link.s + 32 _wrap.s; run.sh
  REGEN=1 is the regen routine; --use-fas-bin retired;
  gen_seg1_layout.py moved into toolchain/tools + DUM-form for S/X/Y
  label collisions — Merlin substitutes EQU symbols into operands
  BEFORE address-mode decode).  ★ORACLE GREW 345→366: all 21 former
  FGX-INCOMPAT fixtures run under the FGX2 wrappers (20 host-clang-
  verified; union_kr per documented intent); exit codes of the
  pre-existing 345 UNCHANGED.  Three FGX1-masked fcc defects fixed
  live: T*[] static-init artificial reject → FGX2_LONG_PTR _Ga;
  S_ARR_STORE pointer-element BANK-DROP (global + local); LOCAL
  ptr-arrays broken end-to-end (reject / 1-slot alloc / stride 2 /
  scalar reads / builder typing).
  **2.6b fcc collapse** — --far-calls REMOVED; --data-segment now a
  PATH override (data segment always emitted; default <out>.data.s);
  retn=3, RTL-only, stored-bank always, string pool in the data seg,
  fcc_stack_pages gone; all 59 mode branches deleted.  Goldens BYTE-
  IDENTICAL across the collapse (one-mode == old far mode).  Sweep
  ballast → inert DS filler (compiled ballast would clash exports /
  merged-dataseg globals); zero-image tags skipped by anti_coincidence;
  fcc_multi.sh + tests/multitu + tests/farcall2bank retired.
  **2.6c FGX far world** — all 63 remaining build_userbin_c FGX1 C
  tools flipped to the FGX2 template (65 dead link.s deleted; 12 stub
  files renamed to the template's <name>_stubs.s slot; ping's two
  merged); template + fas seg0 crt0_c.s → crt0_far.s; all 24 per-tool
  stub files far-converted (FGX2_EXPORT entries, RTS→RTL, C-arg n,S+1
  — all flat push-free syscall stubs); ticks() promoted into libc with
  a libc_data buffer (the per-tool CODE-seg DS buffer made SYS_TICKS —
  which writes via _Sys_CallerBank = caller DBR — silently clobber the
  data bank while reads aliased the same wrong spot); today_init
  exported; fas MAX_SYMBOLS 600→560 (string pool joined seg1);
  build_userbin_c retired; floppy sheds ul/man/cal.
  **Fallout fixed by the wider net** (103-test extended battery over
  every flipped tool): pointer-returning libc shims must stamp the
  carrier BANK (one-mode eq compares offset+bank; a NULL with stale
  _fcc_ptr+2 read as != NULL — man_noentry) → _libc_ptrret helper +
  dest-arg bank returns for str/mem shims; cp read the pre-task-#53
  NATIVE stat mode byte (POSIX st_mode short @4 now — cp_dot);
  slotscan_disk_safe re-pinned to post-refactor hello.s (no
  corruption).  Extended battery green except the two documented
  df wrap-fragile baseline tests.
  Legacy stmt arms note: S_ARR_STORE converted live (bank-drop fix);
  S_SARR_FIELD_IDX / S_PREINC_DEREF / decl-init keep their (correct,
  now-only) data-mode lowerings on the legacy carrier — they go
  FPR-native with the P3-2.7 carrier retirement.
- **P3-2.7 — cleanup.**  Delete the orphaned old pointer helpers +
  `FCC_OLD_PTR`; retire `emit_load_ptr_value_via_fcc_ptr`/staging;
  update tooling that greps the old shapes (stack_measure.py INDIR_RE,
  fgxdebug notes); final goldens regen; docs (CHANGELOG, this doc's
  completion record, architecture doc tick).
  ★DONE 2026-07-07 in four landings on toolchain feat/p32-cleanup
  (`efa08296` → `3fa5f3a4` + comment tidy) + FGX feat/p32-cleanup-fgx:
  **(a)** FCC_OLD_PTR bisection mode DELETED — walk_expr_old (~1.2k
  lines), g_old_ptr, old_ptr_mode(), every old-mode arm, plus the
  already-dead parse-side emit_call_marshal_args/emit_struct_byval_arg/
  stash_fnptr_callee; emit_call_indirect is FPR-only; −1,440 lines,
  goldens byte-identical.  **(b)** The three remaining legacy stmt arms
  FPR-native: S_PREINC_DEREF (fpr_load_sym + [fpr] RMW),
  S_SARR_FIELD_IDX (S_AV_STORE shape — the _fcc_ssp+2/PHB bank
  re-establish dies), decl-init (S_DECL_ARRINIT/STRUCTINIT ptr+fn-ptr
  members via NEW emit_fpr_store_local_4).  TWO live bugs found+fixed
  (both FGX1-masked, brace-init+ptr-array fixture-free): local
  ptr-ARRAY brace init sized elements 2 bytes/BANK DROPPED vs 4-byte
  reads, and the leading-`*` stmt fast path committed past ANY local
  IDENT ("expected '='" on `*a[i]=`/`*v.p=` — artificial rejects; now
  gated to scalar ptr locals).  New fixture M27/declinit_ptr
  (host-clang 42, red 1 → green 42).  **(c)** Carrier RETIRED as a
  cross-call convention: every pointer-returning libc shim (str/mem
  five, fopen/freopen via _libc_ptrret, popen, malloc, realloc, getenv,
  tgetstr, fgets, strchr, strrchr, getcwd) homes its return in
  **FPR0** (offset+bank; NULL = both words 0) — the P3-2.6 interim
  bank-stamp rule is dead; the caller's binding split collapsed to one
  fpr_capture_ret; air/airg tails RETURN the FPR for ptr results (new
  emit_fpr_load_ptr_at_fcc_ptr; N_ARR_READ's fpr_in bridge gone) which
  also fixed a latent partial-decay hazard (row-ptr bank trusted
  _fcc_ptr+2 across the index walk — a call in the index clobbered it;
  bank now re-staged from _fcc_ssp+2/param-slot/PHB and FPR-homed);
  emit_load_ptr_value_via_fcc_ptr DELETED (last body inlined into the
  deref-postinc ptr arm); the dead pre-AST token-consuming emitter
  layer deleted (~200 lines: emit_index_ptr_value + ipv halves,
  emit_chained_index_offset, emit_array_index_read(_global),
  emit_arrow_chain).  **(d)** stack_measure.py INDIR_RE re-keyed to
  the FPR dispatch shape (`LDA _fcc_fprN / DEC / PHA`); §6A DP-scratch
  wording updated (_fcc_fpr0 = every pointer return's home).
  **Documented survivors** (self-contained, one-statement lifetime,
  bridged by fpr_in at their arm; convert with P3-3's soft-stack
  rewrite which rewrites those lowerings anyway): deref-postinc/
  deref-fast IR family, member incdec, ptr-local preinc, printf arg
  staging; LT_STRUCT values stay carrier-carried by design (2.2).
  Gates: goldens 367/367 (regen where churn was by-design), oracle
  367/367, multibank sweep all green, AST_CHECK 0/367, FGX world
  rebuilt on the FPR0 shims.  Extended battery: **zero 2.7
  regressions** — every failure verified pre-existing/environmental
  (hello-silent reproduces on a pre-2.7 baseline disk rebuilt at the
  2.6 mains → backlog, not a 2.7 defect; heaptest/msgtest/
  kbd_shell_paste/vi_* are hand-staged debug probes whose
  preconditions a fresh `./build.sh disk` doesn't provide — vi is not
  part of the build per the maintainer; df_multi/df_path are the documented
  wrap-fragile pair).
  **P3-2 pointer-model ladder COMPLETE.**

## Risks carried forward

- **g_s_delta remains the silent killer**: FPR spills and `fpr_push`
  change push depths; every miss miscompiles all later `n,S`.  The
  behavioral differential corpus is the net for exactly this.
- **Promotion positional desync**: emission-shape changes around
  structured ops can break record/replay matching — land P3-2.5's IR
  changes with the sweep + oracle after every commit, not per-landing.
- **fas dialect**: the funnels introduce `PEI dp` and more `[dp],Y`
  shapes — verify fas assembles them (fas has a known backlog; if it
  can't, fix fas, don't dodge the emission — toolchain-first rule).
- **Kernel/tooling DP assumptions**: anything reading the task DP map
  (fgxdebug probes, stack_measure) must learn the FPR band; the kernel
  itself never touches task-DP `$10-$BB` (verified free).
- **Size regression on pointer-heavy FGX1-class tools** is accepted
  and measured (P3-2.5); the flag-day world-rebuild (P3-6) absorbs
  the churn.

## Sequencing

2.0 → 2.1 → 2.2 → 2.3 → 2.4 → 2.5 → 2.6 → 2.7, strictly — each gates
the next; 2.2 is the flip and deserves a fresh session with full
context headroom, executing from this doc (the Phase-2 Increment-1
pattern).  P3-3 (soft-stack delete) starts only after 2.7: heap-boxing
wants the FPR deref lowering, and the FPR spill discipline wants the
final stack model — the seam between them is `g_s_delta`, which both
respect.
