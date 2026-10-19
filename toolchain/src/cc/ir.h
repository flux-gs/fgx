#ifndef FCC_IR_H
#define FCC_IR_H

#include <stdio.h>
#include <stddef.h>

/* fcc 2.0 Track 2 Phase 0 — record-and-replay IR (Path B foundation).
 *
 * The emission boundary in fcc is fprintf(g_out, ...) (the frontend emits asm
 * directly at ~619 raw sites, plus the emit.c helpers) — NOT emit_*.  So every
 * fprintf(g_out, ...) becomes ir_emitf(...): inside a function body
 * (ir_begin_func .. ir_end_func) it renders the text and records an IR_TEXT op;
 * at the function's end ir_end_func replays the op list to g_out, BYTE-IDENTICAL.
 * Outside a function (TU header / globals / string pool) ir_emitf writes straight
 * to g_out.  Validated by golden-diff == 0 + NO MAME.
 *
 * Path B then lifts IR_TEXT ops -> structured pre-isel ops (load-local, push,
 * binop, ...) one cluster at a time (each with a byte-identical lowering, mixed
 * kinds coexisting via the IR_TEXT escape hatch), enabling linear-scan regalloc
 * over {A,X,Y}+DP.  See docs/superpowers/specs/2026-06-26-fcc2-track2-phase0-
 * decouple.md (CORRECTION). */

typedef enum {
    IR_TEXT = 0,        /* opaque rendered asm text (Phase-0 bridge / escape hatch) */
    /* structured pre-isel ops, lifted from IR_TEXT incrementally (Phase 1): */
    IR_PUSH_A,          /* PHA                               (stack += 2) */
    IR_POP_A,           /* PLA                               (stack -= 2) */
    IR_PUSH_LONG,       /* push 4-byte long A:_fcc_long_hi   (stack += 4) */
    IR_POP_LONG,        /* pop  4-byte long -> A:_fcc_long_hi(stack -= 4) */
    IR_LOAD_LIT,        /* LDA #u0   (int literal; u0 = value)        [writes A] */
    IR_STASH_RHS_INT,   /* STA _fcc_tmp_b  (int binop RHS stash)      [X-clean] */
    IR_TAX,             /* TAX  (regalloc: hold a pushed value in X)  [writes X] */
    IR_TXA,             /* TXA  (regalloc: restore the value from X)  [reads  X] */
    IR_TAY,             /* TAY  (regalloc: hold a pushed value in Y)  [writes Y] */
    IR_TYA,             /* TYA  (regalloc: restore the value from Y)  [reads  Y] */
    /* Frame data-flow (int/char scalar path only; long/float/ptr stay IR_TEXT).
     * ptr = Local*.  `n,S`-relative => SP-dependent => op_xclean=0 (blocks the
     * PHA->TAX peephole exactly as IR_TEXT does; the allocator handles SP in P1.3). */
    IR_LOAD_LOCAL,      /* A = local (LDA n,S / far)                  [writes A] */
    IR_STORE_LOCAL,     /* local = A (STA n,S / far)                  [reads  A] */
    /* fcc2 P1.3-inc2 (local promotion): a hot int/char scalar local promoted to
     * a DP-IMG register slot for its whole function.  u0 = slot index k (0..15
     * -> _fcc_img{k} @ DP $C0+2k); ptr = Local* (for the char load mask).  DP-
     * addressed => SP-independent and X-clean (op_xclean=1), so the allocator's
     * n,S `moved` fixup must NOT touch them (different opcode => falls through). */
    IR_LOAD_LOCAL_IMG,  /* A = LDA _fcc_img{u0} [+char mask]          [writes A] */
    IR_STORE_LOCAL_IMG, /* STA _fcc_img{u0} = A                       [reads  A] */
    /* fcc2 P1.4: a value-DISCARDED ++/-- on an int/char scalar local (emitted
     * only at the 3 statement-context sites where the result is unused — for-step,
     * prefix-stmt, postfix-stmt; expression-context ++/-- keep the value-
     * preserving load/stash/add/store).  ptr = Local*; u0 = g_s_delta snapshot
     * (for the n,S fallback offset, fixed up by the allocator's `moved`);
     * u1 bit0 = is_inc (1=++,0=--), u1 bit1 = loop-hot (tally weight).  Folds the
     * old IR_LOAD_LOCAL + IR_TEXT(CLC/ADC) + IR_STORE_LOCAL trio into one
     * structured op (removes the text barrier).  NON-promoted form: lowers
     * byte-identically to `LDA n,S [+mask]; CLC;ADC #1 / SEC;SBC #1; STA n,S`
     * (clobbers A -> op_xclean=0, n,S => gets the `moved` fixup). */
    IR_INCDEC_LOCAL,
    /* fcc2 P1.4: the PROMOTED form of IR_INCDEC_LOCAL — the local lives in a
     * DP-IMG slot, so a discarded ++/-- becomes a single `INC/DEC _fcc_img{u0}`
     * (2 bytes / 2 cyc vs the 7-8 byte load/add/store).  u0 = slot index k;
     * u1 bit0 = is_inc.  DP-addressed RMW: SP-independent, preserves A and X
     * (op_xclean=1, transparent in tac_sim_bb).  char correctness rests on the
     * load-side AND #$00FF mask: INC may leave high bits set in the 16-bit slot,
     * but every reader masks, so the observable value is identical. */
    IR_INCDEC_LOCAL_IMG,
    /* fcc2 P1.4 (B1a): a pointer-local DEREF read `*p` (and the struct/array
     * deref-of-local path), lifted from IR_TEXT so the promotion pass can
     * recognize a pointer local and (B1b) rewrite the deref to `LDA
     * [_fcc_img{k}]`.  ptr = Local*; u0 = g_s_delta snapshot (the n,S offsets of
     * the 4-byte pointer load); u1 = result tword (the pointee type — drives the
     * widen/mask).  It loads the 4-byte pointer to _fcc_ptr then derefs, so it
     * clobbers A (and Y/flags) and is SP-dependent: kept a BB BARRIER (treated
     * like IR_TEXT in ir_build_tac/tac_lower) so the surrounding clean BBs
     * partition byte-identically to the IR_TEXT it replaces. */
    IR_DEREF_LOCAL,
    /* fcc2 P1.4 (B1a): the 4-byte pointer-LOCAL value load/store (the ISPTR path
     * of emit_load_local/emit_store_local), lifted from IR_TEXT so the promotion
     * pass can recognize a pointer local and (B1b) retarget it to a DP-IMG pair.
     * ptr = Local*; u0 = g_s_delta snapshot.  LOAD: A = offset, _fcc_ptr+2 = bank;
     * sets g_expr_type/struct_id/unsigned at record time.  STORE: u1 = bank-is-
     * zero flag (captured at RECORD time from emit_load_value_bank's g_expr_type
     * test, since the RHS context is gone at replay).  Both clobber A/Y, are SP-
     * dependent, and carry the fcc pointer value in A:_fcc_ptr+2 across their
     * edge -> kept BB BARRIERS (ir_is_bb_barrier), byte-identical to the IR_TEXT
     * they replace. */
    IR_LOAD_PTR_LOCAL,
    IR_STORE_PTR_LOCAL,
    /* fcc2 P1.4 (B1a): the OFFSET-word-only store-back of a pointer-local ++/--/
     * +=k (emit_incdec_store_local's ISPTR branch — pointer arithmetic rewrites
     * only the offset word, leaving the bank).  Lifted from raw emit_slot_sta16
     * (which set raw_accessed and excluded walk pointers from promotion) so a
     * `p++` walk pointer becomes fully structured and B1b can promote it.
     * ptr = Local*; u0 = g_s_delta snapshot.  BB barrier (n,S, A-consuming),
     * byte-identical to the raw store it replaces. */
    IR_STORE_PTR_OFFSET,
    /* fcc2 P1.4 (B1b): the PROMOTED forms — a hot single-level int/char/void-
     * pointee pointer local lives in a CONTIGUOUS img PAIR {u0=k (offset),
     * k+1 (bank)} = a valid 24-bit far pointer at $C0+2k.  The deref collapses
     * to one `LDA [_fcc_img{k}]` (the win).  u1 carries the same payload as the
     * un-promoted op (DEREF: pointee tword for the char/void mask; STORE_PTR_LOCAL:
     * bank-zero flag).  All BB barriers (ir_is_bb_barrier). */
    IR_DEREF_LOCAL_IMG,        /* A = [_fcc_img{u0}] (+char/void mask by u1)   */
    IR_LOAD_PTR_LOCAL_IMG,     /* A = img{u0} (offset), _fcc_ptr+2 = img{u0+1} */
    IR_STORE_PTR_LOCAL_IMG,    /* img{u0} = offset(A), img{u0+1} = bank        */
    IR_STORE_PTR_OFFSET_IMG,   /* img{u0} = offset(A)  (p++ store-back)        */
    /* fcc2 P1.4 (B1c): the `*p++` / `*p--` rvalue WALK IDIOM, folded into one op.
     * The old hand-emitted sequence (load p, stash, bump, store-back, rebuild
     * _fcc_ptr from the stashed pre-value, LDA [_fcc_ptr]) left the deref going
     * through _fcc_ptr even after B1b promoted p to an img pair — because the
     * deref operand is the post-increment TEMPORARY (old p), not the local `p`
     * syntactically, so emit_deref_fast never fired.  Folding it into one op lets
     * the promotion pass rewrite the WHOLE idiom to a direct img deref.
     * ptr = Local*; u0 = g_s_delta snapshot (un-promoted n,S offsets);
     * u1 = (stride << 1) | is_inc.  BB barrier (clobbers A/Y, SP-dependent when
     * un-promoted).  UN-PROMOTED lowering is byte-identical to the old dance
     * (same emit_load_ptr_local_lower + text + emit_store_local_lower bytes). */
    IR_DEREF_POSTINC_LOCAL,
    /* fcc2 P1.4 (B1c): the PROMOTED form — p lives in a contiguous img PAIR, so
     * `*p++` collapses to `LDA [_fcc_img{u0}]` (the deref, reading the true bank
     * from img{u0+1}) followed by the pointer bump.  Deref happens BEFORE the
     * bump (the post-inc reads old p = the un-bumped slot), so no _fcc_ptr
     * rebuild and no pre-value stash.  stride 1 (char/void): one A-preserving
     * `INC/DEC _fcc_img{u0}`.  stride>1 (int): PHA / bump slot / PLA so the
     * deref result in A survives the offset add.  u0 = slot k; u1 unchanged. */
    IR_DEREF_POSTINC_LOCAL_IMG,
    /* fcc2 P1.4 (B1c-2b): the rvalue read `p[i]` for a scalar int/char/void pointer
     * LOCAL (emit_array_index_read's scalar-pointer tail), lifted so the promotion
     * pass can retarget it to the img pair.  ptr = Local*; u0 = g_s_delta snapshot
     * (parity, unused by the lowering); u1 bit0 = is_byte (char/void mask), bit1 =
     * base_mutated (the index sub-expr STRUCTURALLY writes the base -> never promote;
     * a RAW mutation is covered separately by lc->raw_accessed).  At op time the
     * scaled index is in A and the 2-byte base offset is @ 1,S (bank in _fcc_ptr+2).
     * BB barrier (clobbers A/Y, SP-dependent), byte-identical to the inline tail. */
    IR_INDEX_DEREF_LOCAL,
    IR_INDEX_DEREF_LOCAL_IMG,   /* promoted: TAY / PLA / LDA [_fcc_img{u0}],Y (+mask u1 bit0) */
    /* fcc2 P1.4 (B1c-2a-step-2): the `*p++ = RHS` / `*p-- = RHS` STATEMENT-context
     * walk-WRITE idiom on an int/char/void-pointee pointer LOCAL, folded into a
     * SETUP + STORE pair that brackets the RHS.  SETUP replaces emit_load_local +
     * stash + bump + offset store-back + emit_push_ptr (records g_s_delta += 4);
     * STORE replaces emit_deref_store_dispatch (records g_s_delta -= 4).  Only the
     * int/char/void pointee set is routed here — those deref-stores
     * (emit_deref_store / emit_deref_store_byte) carry no record-time g_expr_type
     * dependency, so deferring them to replay is byte-exact (a long, float or
     * ptr-to-ptr pointee keeps the inline path).  ptr = Local*; SETUP u0 = g_s_delta snapshot,
     * u1 = (stride << 1) | is_inc; STORE u1 = (stride << 1) | is_inc.  Both BB
     * barriers.  UN-PROMOTED lowering is byte-identical to the old load/dance/push +
     * deref-store. */
    IR_WALK_STORE_SETUP,
    /* PROMOTED, push RETAINED: img load + img offset store-back + push (byte-
     * identical to today's promoted `*p++=` — the IR_LOAD_PTR_LOCAL_IMG /
     * IR_STORE_PTR_OFFSET_IMG rewrite the promotion pass already performed).  u0 =
     * img slot k; u1 unchanged. */
    IR_WALK_STORE_SETUP_IMG,
    /* COLLAPSED: emits NOTHING.  Used when p is promoted AND the RHS span is push-
     * elision-safe (no n,S op, no reference to p) — img{k} already holds old-p, so
     * no setup is needed; the store writes through it directly and bumps after. */
    IR_WALK_STORE_SETUP_NONE,
    /* The store half.  UN-COLLAPSED: emit_deref_store_dispatch (pops the pushed
     * 4-byte dest, byte-identical to today).  ptr = Local*; u1 = (stride<<1)|is_inc. */
    IR_WALK_STORE,
    /* COLLAPSED store: `[SEP/STA/REP] STA [_fcc_img{k}]` at old-p, then bump img{k}
     * by stride (INC for stride 1, LDA/CLC/ADC/STA for stride>1).  u0 = img slot k;
     * u1 = (stride<<1)|is_inc; is_byte derived from the pointer's pointee type (the
     * same stride==1 <=> byte invariant as IR_DEREF_POSTINC_LOCAL_IMG). */
    IR_WALK_STORE_IMG,
    /* fcc2 P1.3-inc2: entry-seed marker, recorded once right after the prologue.
     * At replay it emits `LDA <param>,S / STA _fcc_img{k}` for each PROMOTED
     * param (copying the incoming arg from its stack home into its DP-IMG slot).
     * A no-op when no param was promoted (so it is transparent otherwise). */
    IR_SEED_MARK,
    /* Int ALU tails: A = A <op> _fcc_tmp_b.  u0 = IrBinKind.  (long/float ->
     * runtime JSR, stay IR_TEXT.)  [reads A + _fcc_tmp_b, writes A] */
    IR_BINOP,
    IR_MULCONST,        /* A = A * k (k=0 -> LDA #0; k=1 -> nop; pow2 -> ASL*n). u0=k */
    IR_SHIFT_CONST,     /* A <<= / >>= k.  u0 = is_lsr (0=ASL,1=LSR), u1 = count */
    /* Global data-flow (int/char scalar path only; long/float/ptr stay IR_TEXT).
     * ptr = Global*.  Absolute-addressed (LDA/STA gname), so not SP-dependent. */
    IR_LOAD_GLOBAL,        /* A = global (LDA gname [+char mask])     [writes A] */
    IR_STORE_GLOBAL_INT,   /* global = A (STA gname)                  [reads  A] */
    IR_STORE_GLOBAL_CHAR,  /* char global = A (SEP/STA gname/REP)     [reads  A] */
    /* fcc2 P1.4 (loop-scoped promotion): markers bracketing a loop body in the op
     * stream (recorded by parse_while/for/do).  u0 = loop id (the BEGIN/END pair
     * share it).  When the WHOLE-function promotion gate fails (the function makes
     * a call), ir_promote_locals region-promotes scalars across a CALL-FREE loop:
     * IR_LOOP_BEGIN lowers to the region entry seeds (LDA <local>,S / STA
     * _fcc_img{k}), IR_LOOP_END to the exit write-backs (LDA _fcc_img{k} / STA
     * <local>,S).  No-ops when the region promoted nothing -> transparent, exactly
     * like IR_SEED_MARK (op_stack_delta 0, op_xclean 1, no temp in tac_sim_bb). */
    IR_LOOP_BEGIN,
    IR_LOOP_END,
    /* fcc2 isel Phase 1: load-op fold — `A = A <op> mem` against a leaf operand,
     * folded from the PUSH_A / leaf-load / STASH_RHS_INT / POP_A / BINOP window.
     * A-only ALU (op_stack_delta 0).  Operand order is preserved (LHS stays in A,
     * the leaf is the memory operand) so all five IrBinKinds fold, SUB included. */
    IR_BINOP_MEM_LOCAL,    /* [CLC/SEC] <op> slot,S      ; ptr=Local*, u0=s_delta, u1=kind */
    IR_BINOP_MEM_GLOBAL,   /* [CLC/SEC] <op> gname       ; ptr=Global*, u0=kind */
    IR_BINOP_MEM_IMG,      /* [CLC/SEC] <op> _fcc_img{k} ; u0=slot, u1=kind */
    /* RTL-ABI: a 4-byte LONG/FLOAT local/param VALUE load, lifted from raw
     * IR_TEXT (emit_load_local's long/float branch) so the right-to-left arg
     * reversal can adjust its g_s_delta snapshot for a PARAM operand (elvis
     * passes a MARK=long param as a variadic-call arg: paste(frommark,...)).
     * ptr = Local*; u0 = g_s_delta snapshot.  BB barrier, byte-identical to the
     * emit_slot_lda16(lc,2)/STA _fcc_long_hi/emit_slot_lda16(lc,0) it replaces.
     * g_expr_type is set at RECORD time (parser-visible). */
    IR_LOAD_LONG_LOCAL,
    /* The 4-byte STORE half of the pair above, structured for the same reason
     * IR_STORE_LOCAL is: promotion can only retarget an access it can see as
     * one op.  It was raw IR_TEXT, which is why longs could never promote.
     * ptr = Local*; u0 = g_s_delta snapshot; u1 = how the RHS reaches the high
     * word — 0 a long-typed RHS (already in _fcc_long_hi), 1 an UNSIGNED
     * int/char RHS (zero-extend), 2 a SIGNED one (_fcc_long_from_int).  That
     * choice depends on g_expr_type/g_expr_unsigned, which are gone by replay,
     * so it is captured at record time exactly as IR_STORE_PTR_LOCAL captures
     * its bank_zero. */
    IR_STORE_LONG_LOCAL,
    /* The promoted forms: a long lives in a CONTIGUOUS img PAIR {u0, u0+1} =
     * {low word, high word}, the same pairing pointers already use for
     * {offset, bank}.  A long value travels in A (low) + _fcc_long_hi (high),
     * so these move two words rather than one and the pair is what makes that
     * possible without a stack slot. */
    IR_LOAD_LONG_LOCAL_IMG,
    IR_STORE_LONG_LOCAL_IMG,
    /* long long local/param load and store: four words through A,
     * _fcc_long_hi, _fcc_q2 and _fcc_q3.  ptr = Local*; u0 = g_s_delta
     * snapshot, for the same reason IR_LOAD_LONG_LOCAL carries one.  BB
     * barriers, and never promoted.  The store takes the value already in
     * long long form (emit_to_llong); it widens nothing itself. */
    IR_LOAD_LLONG_LOCAL,
    IR_STORE_LLONG_LOCAL,
    /* RTL-ABI: &param — the SP-relative address of a hardware-stack PARAM
     * (emit_addr_of_local's param branch), lifted from raw IR_TEXT so the arg
     * reversal can adjust its g_s_delta snapshot (elvis regexp gettoken(&text,
     * ...) with text a param).  ptr = Local*; u0 = g_s_delta snapshot.  BB
     * barrier; byte-identical to the raw SEP/LDA#0/STA/REP/TSC/CLC/ADC it
     * replaces.  &LOCAL stays raw (soft-stack, g_s_delta-independent). */
    IR_ADDR_PARAM,
    /* P3-2.5a: FPR-NATIVE pointer-local value load/store — the pointer-model
     * walker's ptr-local funnels (fpr_load_sym, N_STORE_VAR/N_COMPOUND_VAR,
     * the parse_stmt deref-store arms).  Same promotion contract as
     * IR_LOAD_PTR_LOCAL/IR_STORE_PTR_LOCAL (scanned + retargeted to the img
     * forms below), but the value rides FPR u1 directly instead of the
     * A+_fcc_ptr+2 carrier (kills the fpr_in/to_carrier bridge per access).
     * ptr = Local*;
     * u0 = g_s_delta snapshot (IMG forms: img slot); u1 = FPR index.
     * LOAD ends with A = offset word (the fpr_load_sym contract — kd arms
     * consume it).  All BB barriers (clobber A/Y, n,S when un-promoted). */
    IR_FPR_LOAD_PTR_LOCAL,
    IR_FPR_STORE_PTR_LOCAL,
    IR_FPR_LOAD_PTR_LOCAL_IMG,   /* fpr{u1} = {img{u0}, img{u0+1}}; A = offset */
    IR_FPR_STORE_PTR_LOCAL_IMG,  /* {img{u0}, img{u0+1}} = fpr{u1}             */
    /* T2-3 control-flow lift (the CFG substrate).  These replace the raw
     * branch/label/runtime-call IR_TEXT records so a future whole-function
     * pass can SEE successors and per-helper clobbers instead of an opaque
     * text barrier.  All four are BB barriers TODAY (ir_is_bb_barrier) with
     * byte-identical lowerings — the partition and output are unchanged;
     * only the metadata is new.
     *   IR_LABEL   — numbered label DEF `<tu>_L{u0}` at column 0.
     *   IR_BR      — unconditional `BRA/BRL <tu>_L{u0}`; u1 bit0 = is_brl.
     *   IR_BCOND   — conditional `Bcc <tu>_L{u0}`; u1 = cond index into
     *                ir_cond_mnem[] (BEQ BNE BCC BCS BMI BPL BVC BVS),
     *                u1 bit3 = FAR form (`B!cc *+5 / BRL target` — the
     *                inverted-skip idiom, one op so the pair never splits).
     *   IR_JSR_RT  — near `JSR <name>` to a runtime/libc helper; ptr = the
     *                helper name (static string).  Clobber profile stays
     *                "barrier" until per-helper masks exist. */
    IR_LABEL,
    IR_BR,
    IR_BCOND,
    IR_JSR_RT,
    /* T2-3 width-mode lift: the SEP/REP #$20 + MX directive PAIRS (they
     * always travel together at record-time sites).  Makes the accumulator
     * width an explicit per-point fact for the future pass.  Barriers today
     * (partition preserved); relaxable later. */
    IR_M8,              /* SEP #$20 / MX %10 — A to 8-bit  */
    IR_M16,             /* REP #$20 / MX %00 — A to 16-bit */
    /* T2-3 MEM tier: DP-cell traffic with the CELL IDENTITY as metadata
     * (ptr = static cell-name string, e.g. "_fcc_ptr+2", "_fcc_tmp_b").
     * Always recorded RAW (barrier preserved); the future pass relaxes
     * per-cell families with def/use knowledge it never had from text. */
    IR_LDA_CELL,        /* LDA <cell>   [writes A]  */
    IR_STA_CELL,        /* STA <cell>   [reads  A]  */
    /* T2-3 ALU idioms (the review's unit-of-work rule: the IDIOM, not the
     * mnemonic).  A-only const arithmetic; u0 = (unsigned)int constant,
     * lowered back through (int) so %d rendering is bit-identical. */
    IR_ADD_CONST,       /* CLC / ADC #<i>   [A += i]  */
    IR_SUB_CONST,       /* SEC / SBC #<i>   [A -= i]  */
    /* T2-3 far-pointer deref idiom: A traffic through a DP long pointer.
     * ptr = canonical interned cell name (WITHOUT brackets: "_fcc_ptr",
     * "_fcc_ptr2", "_fcc_fp"); u0 bit0 = ,Y indexed.  The future pointer-
     * tracking pass reads deref sites + their carrier cell from here. */
    IR_LDA_DEREF,       /* LDA [<cell>](,Y)   [writes A; reads Y if indexed] */
    IR_STA_DEREF,       /* STA [<cell>](,Y)   [reads  A; reads Y if indexed] */
    IR_OP_COUNT
} IrOp;

/* IR_BINOP kinds (u0). */
typedef enum {
    IRBIN_ADD = 0, IRBIN_SUB, IRBIN_BAND, IRBIN_BOR, IRBIN_BXOR
} IrBinKind;

typedef struct {
    IrOp     op;
    char    *text;      /* IR_TEXT payload: owned heap copy of rendered asm */
    size_t   text_len;
    unsigned u0;        /* structured-op operand 0 (immediate / resolved offset / kind) */
    unsigned u1;        /* structured-op operand 1 (e.g. shift count) */
    unsigned flags;     /* IRF_* below */
    void    *ptr;       /* structured-op frontend handle (Local* / Global*) */
} IrNode;

/* T2-3 MEM tier: a RAW-flagged node was lifted from a free-standing IR_TEXT
 * site.  It carries the op's SEMANTICS (the future pass reads them) but
 * keeps IR_TEXT's BARRIER-hood so today's BB partition — and therefore the
 * allocator's decisions and the output — are preserved BY CONSTRUCTION.
 * Relaxing a family from raw to clean is a later, measured, per-family
 * change in exactly one place (ir_node_is_bb_barrier). */
#define IRF_RAW 1u

/* Master switch: 1 (default) = record/replay active; 0 = ir_emitf is a pure
 * pass-through to g_out (bisection / disable). */
int  ir_enabled(void);
void ir_set_enabled(int on);
int  ir_recording(void);    /* 1 only while recording a function body (not replay) */
void ir_note_indirect_call(void);  /* P1.3-inc2: indirect call -> no promotion */
int  ir_has_indirect_call(void);   /* P3-3 3.2b: read at fn end for the stack guard */
void ir_note_self_recursion(void); /* P3-3 3.2b: direct self-call seen */
int  ir_self_recursive(void);      /* P3-3 3.2b: read at fn end for the stack guard */
void ir_emit_param_seeds(void);    /* P1.3-inc2: emit promoted-param entry seeds */
void ir_emit_loop_seeds(unsigned loop_id);     /* P1.4 loop-scoped: region entry seeds */
void ir_emit_loop_writeback(unsigned loop_id); /* P1.4 loop-scoped: region exit write-backs */

/* Per-function record/replay lifecycle (called by the frontend around a
 * function body). */
void ir_begin_func(void);   /* reset the op list + arm recording */
void ir_end_func(void);     /* disarm + replay the op list to g_out */

/* Drop-in replacement for fprintf(g_out, fmt, ...). */
void ir_emitf(const char *fmt, ...);

/* Record a structured (operand-less) IR op; if not recording, lower it now. */
void ir_record_op(IrOp op);
void ir_record_raw(IrOp op, unsigned u0, unsigned u1, void *ptr);  /* T2-3: IRF_RAW lift */

/* Record a structured op carrying one unsigned operand (u0). */
void ir_record_op1(IrOp op, unsigned u0);

/* Record a structured op carrying two unsigned operands (u0, u1). */
void ir_record_op2(IrOp op, unsigned u0, unsigned u1);

/* Record a structured op carrying a frontend handle (Local* / Global*). */
void ir_record_op_ptr(IrOp op, void *ptr);

/* Record a structured op carrying a frontend handle AND a snapshot operand
 * (e.g. g_s_delta at emit time, since stack-relative offsets are SP-dependent
 * and must be reproduced at replay rather than recomputed from the live SP). */
void ir_record_op_ptr1(IrOp op, void *ptr, unsigned u0);
/* P1.3-inc3: also carry u1 (loop-access flag for IR_LOAD_LOCAL/STORE_LOCAL). */
void ir_record_op_ptr2(IrOp op, void *ptr, unsigned u0, unsigned u1);
/* B1c-2b: current op count (snapshot before an index sub-expression) + a scan for a
 * STRUCTURED mutation of pointer local `lc` in g_ir[snap, now).  g_ir is file-static
 * to ir.c, so emit.c reaches it through these. */
int ir_cur_n(void);
int ir_local_mutated_since(int snap, void *lc);

/* RTL-ABI: reverse a variadic call's N recorded arg op-ranges (right-to-left
 * push) with per-arg g_s_delta compensation.  bounds[0..n], weights[0..n-1]. */

/* Lower one structured op to g_out (replay dispatch; implemented in emit.c). */
void emit_lower_op(const IrNode *n);

/* Phase 1 regalloc: toggle the in-place optimization pass (default on). */
void ir_set_opt(int on);

#endif /* FCC_IR_H */
