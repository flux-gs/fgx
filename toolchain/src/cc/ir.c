/* fcc 2.0 Track 2 Phase 0 — record-and-replay IR (Path B foundation).
 * See ir.h and docs/superpowers/specs/2026-06-26-fcc2-track2-phase0-decouple.md. */

#include "fcc.h"
#include "ir.h"
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

/* Per-function op list.  One C function's emitted line count is modest; this cap
 * is a generous backstop (errors out loudly rather than silently truncating). */
#define IR_MAX_NODES 65536
#define IR_LINE_MAX  8192

static IrNode g_ir[IR_MAX_NODES];
static int    g_ir_n     = 0;
static int    g_ir_on    = 1;   /* master switch (1 = record/replay active) */
static int    g_recording = 0;  /* 1 while inside a function body */
/* fcc2 P1.3-inc2: an indirect (function-pointer) call lowers to a tokenless
 * computed trampoline (emit_call_indirect: in-bank PEA/DEC/PHA/RTS, or the
 * --far-calls double-RTL far variant) — it carries no JSR/JSL/FARCALL token, so
 * the IR_TEXT call scan can't see it.  This flag is
 * the direct signal: any indirect call disqualifies the function from promotion
 * (the callee may reuse this task DP page's $C0..$DF). */
static int    g_has_indirect_call = 0;
/* P3-3 3.2b: set when the function makes a direct call to itself.  Together with
 * g_has_indirect_call and a >=128 B frame it decides whether the prologue emits
 * the hardware-stack overflow guard (a small leaf frame can't meaningfully
 * overflow on its own; recursion / indirect calls / big frames can). */
static int    g_self_recursive = 0;

int  ir_enabled(void)       { return g_ir_on; }
void ir_set_enabled(int on) { g_ir_on = on; }
int  ir_recording(void)     { return g_recording; }   /* 1 only during record (not replay) */
void ir_note_indirect_call(void) { g_has_indirect_call = 1; }
int  ir_has_indirect_call(void)  { return g_has_indirect_call; }
void ir_note_self_recursion(void){ g_self_recursive = 1; }
int  ir_self_recursive(void)     { return g_self_recursive; }

static void
ir_reset(void)
{
    int i;
    for (i = 0; i < g_ir_n; i++) {
        free(g_ir[i].text);
        g_ir[i].text = NULL;
    }
    g_ir_n = 0;
}

static void
ir_record_text(const char *s, size_t n)
{
    char *copy;
    if (g_ir_n >= IR_MAX_NODES) {
        fprintf(stderr, "fcc: IR node overflow (>%d in one function)\n", IR_MAX_NODES);
        exit(1);
    }
    copy = malloc(n + 1);
    if (!copy) { fprintf(stderr, "fcc: IR out of memory\n"); exit(1); }
    memcpy(copy, s, n);
    copy[n] = '\0';
    g_ir[g_ir_n].op       = IR_TEXT;
    g_ir[g_ir_n].text     = copy;
    g_ir[g_ir_n].text_len = n;
    g_ir[g_ir_n].u0       = 0;
    g_ir[g_ir_n].u1       = 0;
    g_ir[g_ir_n].flags    = 0;
    g_ir[g_ir_n].ptr      = NULL;
    g_ir_n++;
}

/* Drop-in for fprintf(g_out, fmt, ...).  Recording: render byte-identically and
 * stash an IR_TEXT op.  Otherwise: straight to g_out. */
void
ir_emitf(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    if (g_ir_on && g_recording) {
        char buf[IR_LINE_MAX];
        int  n = vsnprintf(buf, sizeof buf, fmt, ap);
        if (n < 0) { fprintf(stderr, "fcc: ir_emitf vsnprintf error\n"); exit(1); }
        if ((size_t)n >= sizeof buf) {
            fprintf(stderr, "fcc: ir_emitf emission too long (%d bytes)\n", n);
            exit(1);
        }
        ir_record_text(buf, (size_t)n);
    } else {
        vfprintf(g_out, fmt, ap);
    }
    va_end(ap);
}

/* T2-3: flags applied to the NEXT recorded op (one-shot; see IRF_RAW). */
static unsigned g_rec_flags = 0;

void
ir_record_raw(IrOp op, unsigned u0, unsigned u1, void *ptr);   /* fwd (uses ir_emit_op) */

static void
ir_emit_op(IrOp op, unsigned u0, unsigned u1, void *ptr)
{
    if (g_ir_on && g_recording) {
        if (g_ir_n >= IR_MAX_NODES) {
            fprintf(stderr, "fcc: IR node overflow (>%d in one function)\n", IR_MAX_NODES);
            exit(1);
        }
        g_ir[g_ir_n].op       = op;
        g_ir[g_ir_n].text     = NULL;
        g_ir[g_ir_n].text_len = 0;
        g_ir[g_ir_n].u0       = u0;
        g_ir[g_ir_n].u1       = u1;
        g_ir[g_ir_n].flags    = g_rec_flags;   /* T2-3: IRF_RAW etc. */
        g_ir[g_ir_n].ptr      = ptr;
        g_ir_n++;
    } else {
        IrNode t;
        t.op = op; t.text = NULL; t.text_len = 0; t.u0 = u0; t.u1 = u1; t.ptr = ptr;
        t.flags = g_rec_flags;
        emit_lower_op(&t);
    }
}

void ir_record_op(IrOp op)               { ir_emit_op(op, 0u, 0u, NULL); }
void ir_record_raw(IrOp op, unsigned u0, unsigned u1, void *ptr)
{   /* T2-3 MEM tier: record with IRF_RAW (barrier-hood preserved). */
    g_rec_flags = IRF_RAW;
    ir_emit_op(op, u0, u1, ptr);
    g_rec_flags = 0;
}
void ir_record_op1(IrOp op, unsigned u0) { ir_emit_op(op, u0, 0u, NULL); }
void ir_record_op2(IrOp op, unsigned u0, unsigned u1) { ir_emit_op(op, u0, u1, NULL); }
void ir_record_op_ptr(IrOp op, void *ptr){ ir_emit_op(op, 0u, 0u, ptr); }
void ir_record_op_ptr1(IrOp op, void *ptr, unsigned u0){ ir_emit_op(op, u0, 0u, ptr); }
void ir_record_op_ptr2(IrOp op, void *ptr, unsigned u0, unsigned u1){ ir_emit_op(op, u0, u1, ptr); }

/* ---------------------------------------------------------------------------
 * Phase 1 register allocation (incremental).  Rewrites the recorded op list in
 * place before replay.  Correct-by-construction: a transform fires only when the
 * spanned window is ENTIRELY structured ops, so any IR_TEXT (unknown effects /
 * `n,S` stack-relative access / X use) blocks it.  As ops are lifted out of
 * IR_TEXT, more windows qualify.
 * ------------------------------------------------------------------------- */
static int g_ir_opt = 1;     /* 1 = run the regalloc pass (bisect via ir_set_opt) */
void ir_set_opt(int on) { g_ir_opt = on; }

/* Net stack bytes a structured op moves; 0x7fffffff = unknown (IR_TEXT). */
static int
op_stack_delta(IrOp op)
{
    switch (op) {
    case IR_PUSH_A:    return  2;
    case IR_POP_A:     return -2;
    case IR_PUSH_LONG: return  4;
    case IR_POP_LONG:  return -4;
    case IR_LOAD_LIT:  case IR_STASH_RHS_INT:
    case IR_TAX:       case IR_TXA:
    case IR_TAY:       case IR_TYA: return 0;
    case IR_LOAD_LOCAL: case IR_STORE_LOCAL: return 0;  /* stack-neutral (n,S) */
    case IR_LOAD_LOCAL_IMG: case IR_STORE_LOCAL_IMG: return 0;  /* DP, stack-neutral */
    case IR_INCDEC_LOCAL: case IR_INCDEC_LOCAL_IMG: return 0;   /* in-place RMW, stack-neutral */
    case IR_SEED_MARK: return 0;                                /* entry seeds: LDA/STA only */
    case IR_LOOP_BEGIN: case IR_LOOP_END: return 0;            /* region seeds/write-backs: LDA/STA only */
    case IR_BINOP: case IR_MULCONST: case IR_SHIFT_CONST: return 0;  /* A-only ALU */
    case IR_BINOP_MEM_LOCAL: case IR_BINOP_MEM_GLOBAL:
    case IR_BINOP_MEM_IMG: return 0;      /* load-op fold: A = A <op> mem, A-only */
    case IR_LOAD_GLOBAL: case IR_STORE_GLOBAL_INT:
    case IR_STORE_GLOBAL_CHAR: return 0;  /* absolute (gname), stack-neutral */
    default:           return 0x7fffffff;   /* IR_TEXT / unknown */
    }
}

/* 1 iff the op provably neither reads nor writes the X register. */
static int
op_xclean(IrOp op)
{
    switch (op) {
    case IR_PUSH_A: case IR_POP_A:
    case IR_PUSH_LONG: case IR_POP_LONG:
    case IR_LOAD_LIT:  case IR_STASH_RHS_INT: return 1;
    /* DP-addressed (not n,S) and touch only A -> safe inside a PHA..PLA window. */
    case IR_LOAD_LOCAL_IMG: case IR_STORE_LOCAL_IMG: return 1;
    case IR_INCDEC_LOCAL_IMG: return 1;         /* INC/DEC dp: touches the slot + flags, not X/A */
    case IR_BINOP_MEM_GLOBAL: case IR_BINOP_MEM_IMG: return 1;  /* abs/DP operand, A-only */
    /* IR_BINOP_MEM_LOCAL is n,S (SP-dependent) -> default 0, like IR_LOAD_LOCAL. */
    case IR_SEED_MARK: return 1;                /* seeds touch A only, not X */
    case IR_LOOP_BEGIN: case IR_LOOP_END: return 1;   /* region seeds/write-backs touch A only */
    /* IR_INCDEC_LOCAL is n,S RMW (SP-dependent) -> falls to default 0 so the PoC
     * peephole aborts rather than leave its n,S offset stale (cf. IR_LOAD_LOCAL). */
    default:           return 0;   /* IR_TAX/IR_TXA use X; IR_TEXT unknown */
    }
}

/* PHA..PLA save/restore -> TAX..TXA when X is free across a fully-structured,
 * stack-balanced span.  Non-overlapping: each transformed span owns X. */
/* PoC peephole over [lo,hi): PHA..PLA save/restore -> TAX..TXA when X is free
 * across a fully-structured, stack-balanced span.  Used for NOT-clean BBs, where
 * the SP-aware allocator can't safely simulate the stack. */
static void
ir_opt_pha_pla(int lo, int hi)
{
    int i;
    for (i = lo; i < hi; i++) {
        int above, j, hit;
        if (g_ir[i].op != IR_PUSH_A) continue;
        above = 0; hit = -1;
        for (j = i + 1; j < hi; j++) {
            IrOp op = g_ir[j].op;
            if (op == IR_POP_A && above == 0) { hit = j; break; }
            if (!op_xclean(op)) break;          /* unknown / X-clobber -> abort */
            above += op_stack_delta(op);
            if (above < 0) break;               /* popped past our value -> abort */
        }
        if (hit >= 0) {
            g_ir[i].op   = IR_TAX;
            g_ir[hit].op = IR_TXA;
            i = hit;                            /* skip the consumed span */
        }
    }
}


/* ---------------------------------------------------------------------------
 * P1.2 — stack -> TAC (virtual temps + basic blocks).
 *
 * Compile-time simulation of the per-function op list: split into basic blocks
 * (a BB is a maximal run of structured ops between IR_TEXT barriers), and over
 * each BB simulate the abstract operand stack (the PHA'd values) + A/_fcc_tmp_b,
 * assigning a virtual temp id to every value produced/consumed.  This is the
 * representation the linear-scan allocator (P1.3) will operate on.
 *
 * Value/stack model (matches the lifted ops' real behaviour):
 *   LOAD_LOCAL/GLOBAL/LIT        def A-temp
 *   MULCONST/SHIFT_CONST         use A-temp, def A-temp'
 *   STORE_LOCAL/GLOBAL_*         use A-temp
 *   STASH_RHS_INT                use A-temp, def tmp_b-temp
 *   BINOP                        use A-temp + tmp_b-temp, def A-temp'
 *   PUSH_A / PUSH_LONG           use A-temp, spill onto the abstract stack
 *   POP_A  / POP_LONG            reload A-temp from the abstract stack
 * A BB is "clean" (allocatable) iff every use has a prior def and the abstract
 * stack is balanced (empty at the BB's end — no PHA'd value crosses a barrier).
 * Not-clean BBs still lower correctly; the allocator simply skips them.
 *
 * Built only under FCC_TAC_LOWER / FCC_TAC_STATS so the default emission path is
 * completely untouched (zero risk to goldens).  The naive lowerer (tac_lower)
 * re-emits via the BB structure -> byte-identical to the raw (peephole-off)
 * replay, which is the round-trip risk gate (compare vs FCC_NO_REGALLOC).
 * ------------------------------------------------------------------------- */
#define IR_MAX_BB 8192
typedef struct { int lo, hi, clean; } TacBB;   /* g_ir[lo,hi) structured run */
static TacBB g_bb[IR_MAX_BB];
static int   g_bb_n;
static int   g_t_in0[IR_MAX_NODES], g_t_in1[IR_MAX_NODES], g_t_out[IR_MAX_NODES];
static int   g_astk[IR_MAX_NODES], g_astk_n, g_ntemp;

static int   g_tac_lower = -1;   /* getenv-cached: lower via the TAC (round-trip gate) */
static int   g_tac_stats = -1;   /* getenv-cached: log per-function BB/temp coverage */
static int   g_isel      = -1;   /* getenv-cached: FCC_NO_ISEL=1 -> 0 (disable isel pass) */
static int   g_p3_stats  = -1;   /* getenv-cached: FCC_P3_STATS -> emit spill/reload measurement */

static int tac_new_temp(void) { return g_ntemp++; }

/* Simulate one BB's stack/temps; return 1 if clean (allocatable). */
static int
tac_sim_bb(int lo, int hi)
{
    int atemp = -1, btemp = -1, clean = 1, j;
    g_astk_n = 0;
    for (j = lo; j < hi; j++) {
        g_t_in0[j] = g_t_in1[j] = g_t_out[j] = -1;
        switch (g_ir[j].op) {
        case IR_LOAD_LOCAL: case IR_LOAD_LOCAL_IMG:
        case IR_LOAD_GLOBAL: case IR_LOAD_LIT:
            atemp = tac_new_temp(); g_t_out[j] = atemp; break;
        case IR_MULCONST: case IR_SHIFT_CONST:
        case IR_BINOP_MEM_LOCAL: case IR_BINOP_MEM_GLOBAL: case IR_BINOP_MEM_IMG:
            if (atemp < 0) clean = 0;
            g_t_in0[j] = atemp; atemp = tac_new_temp(); g_t_out[j] = atemp; break;
        case IR_STORE_LOCAL: case IR_STORE_LOCAL_IMG:
        case IR_STORE_GLOBAL_INT: case IR_STORE_GLOBAL_CHAR:
            if (atemp < 0) clean = 0;
            g_t_in0[j] = atemp; break;
        case IR_STASH_RHS_INT:
            if (atemp < 0) clean = 0;
            g_t_in0[j] = atemp; btemp = tac_new_temp(); g_t_out[j] = btemp; break;
        case IR_BINOP:
            if (atemp < 0 || btemp < 0) clean = 0;
            g_t_in0[j] = atemp; g_t_in1[j] = btemp;
            atemp = tac_new_temp(); g_t_out[j] = atemp; break;
        case IR_PUSH_A:
            if (atemp < 0) clean = 0;
            g_t_in0[j] = atemp;
            if (g_astk_n < IR_MAX_NODES) g_astk[g_astk_n++] = atemp; else clean = 0;
            break;
        case IR_POP_A:
            if (g_astk_n > 0) { atemp = g_astk[--g_astk_n]; g_t_out[j] = atemp; }
            else { atemp = -1; clean = 0; }
            break;
        case IR_PUSH_LONG: case IR_POP_LONG:
            /* The long push/pop lowerings (emit_push_long_lower / emit_pop_long_lower)
             * clobber Y.  A long can only enter A via an IR_TEXT barrier, so a long
             * push/pop is always the first structured op of its BB and the BB is
             * already non-clean.  Mark it non-clean EXPLICITLY so the allocator's
             * Y-spill can never be colored into a BB containing one — keeping the
             * invariant structural even if a future change makes a long a
             * structured (in-A) value. */
            clean = 0;
            break;
        case IR_SEED_MARK:
            /* Entry-seed marker: emits LDA/STA only at the BB head (before any
             * push), no temp + no stack effect -> transparent to clean-ness. */
            break;
        case IR_LOOP_BEGIN:
        case IR_LOOP_END:
            /* Loop-region seed/write-back markers: emit LDA/STA only (clobbers A;
             * X-clean; no operand-stack/temp effect).  Safe because BEGIN is the
             * last op of its BB (followed by the loop-top IR_TEXT label) and END
             * the first (preceded by the lab_end IR_TEXT barrier), so no live-A
             * temp spans the marker -> transparent to clean-ness, like IR_SEED_MARK. */
            break;
        case IR_INCDEC_LOCAL_IMG:
            /* INC/DEC dp: in-place RMW that preserves A and X -> fully
             * transparent to clean-ness (any value live in A survives it). */
            break;
        case IR_INCDEC_LOCAL:
            /* n,S RMW clobbers A.  Emitted only where the result is discarded so
             * no temp flows through it; kill the in-A temp so an (impossible)
             * later read of the now-clobbered A forces non-clean rather than
             * trusting stale A. */
            atemp = -1; break;
        default:   /* IR_TEXT excluded by the partition; IR_TAX/IR_TXA are post-alloc */
            clean = 0; break;
        }
    }
    if (g_astk_n != 0) clean = 0;       /* a PHA'd value spans a barrier */
    return clean;
}

/* Partition g_ir into basic blocks + simulate each.  TAC lives until ir_reset. */
/* fcc2 P1.4 (B1a): ops that BREAK a basic block exactly like IR_TEXT.  They are
 * not part of any clean BB (the allocator fences around them, preserving the
 * byte-identical partition), but unlike IR_TEXT (which fwrites captured text)
 * they lower via emit_lower_op.  A pointer deref clobbers A/Y and is SP-
 * dependent, so it stays a barrier until B1b promotes it to a DP-IMG deref. */
static int ir_is_bb_barrier_op(IrOp op);

static int
ir_node_is_bb_barrier(const IrNode *n)
{
    /* T2-3 MEM tier: RAW-lifted nodes keep IR_TEXT's barrier-hood. */
    if (n->flags & IRF_RAW) return 1;
    return ir_is_bb_barrier_op(n->op);
}

static int
ir_is_bb_barrier_op(IrOp op)
{
    return op == IR_TEXT || op == IR_DEREF_LOCAL ||
           /* T2-3 control-flow ops: barriers BY DEFINITION (they end a BB);
            * the lift's value is that u0/ptr now carry the successor/callee
            * the future CFG pass reads — IR_TEXT carried nothing. */
           op == IR_LABEL || op == IR_BR || op == IR_BCOND ||
           op == IR_JSR_RT || op == IR_M8 || op == IR_M16 ||
           op == IR_LOAD_PTR_LOCAL || op == IR_STORE_PTR_LOCAL ||
           op == IR_STORE_PTR_OFFSET ||
           /* P3-2.5a FPR-native forms: same clobber/SP profile as their
            * carrier originals -> same barrier treatment. */
           op == IR_FPR_LOAD_PTR_LOCAL || op == IR_FPR_STORE_PTR_LOCAL ||
           op == IR_FPR_LOAD_PTR_LOCAL_IMG ||
           op == IR_FPR_STORE_PTR_LOCAL_IMG ||
           /* RTL-ABI: 4-byte long/float value load — clobbers A, n,S for a
            * param (SP-dependent) -> barrier like the other n,S loads. */
           op == IR_LOAD_LONG_LOCAL ||
           /* Its store twin, and both promoted forms: all clobber A (and Y,
            * across the widen), and the unpromoted pair is n,S. */
           op == IR_STORE_LONG_LOCAL ||
           op == IR_LOAD_LONG_LOCAL_IMG || op == IR_STORE_LONG_LOCAL_IMG ||
           op == IR_LOAD_LLONG_LOCAL || op == IR_STORE_LLONG_LOCAL ||
           /* RTL-ABI: &param — TSC-relative address (SP-dependent), clobbers A
            * -> barrier like the other n,S ops. */
           op == IR_ADDR_PARAM ||
           /* B1b promoted forms: img-deref clobbers A, the load/stores touch
            * A/Y + _fcc_ptr; keep them barriers like their n,S originals. */
           op == IR_DEREF_LOCAL_IMG || op == IR_LOAD_PTR_LOCAL_IMG ||
           op == IR_STORE_PTR_LOCAL_IMG || op == IR_STORE_PTR_OFFSET_IMG ||
           /* B1c `*p++` walk idiom: clobbers A/Y, SP-dependent (un-promoted) /
            * deref+RMW (promoted) -> barrier like the other deref ops. */
           op == IR_DEREF_POSTINC_LOCAL || op == IR_DEREF_POSTINC_LOCAL_IMG ||
           /* B1c-2b p[i] read: clobbers A/Y, SP-dependent -> barrier. */
           op == IR_INDEX_DEREF_LOCAL || op == IR_INDEX_DEREF_LOCAL_IMG ||
           /* B1c-2a-step-2 `*p++ = RHS` walk-WRITE: SETUP loads p + pushes (SP-
            * changing), STORE derefs/pops or img-stores -> all barriers (SETUP_NONE
            * emits nothing but stays a boundary).  Like the other deref/store ops,
            * they fence the surrounding clean BBs, preserving the byte-identical
            * partition (the collapsed RHS for `*d++=*s++` is itself all barriers). */
           op == IR_WALK_STORE_SETUP || op == IR_WALK_STORE_SETUP_IMG ||
           op == IR_WALK_STORE_SETUP_NONE ||
           op == IR_WALK_STORE || op == IR_WALK_STORE_IMG;
}

/* B1c-2b: see ir.h.  ir_local_mutated_since catches a STRUCTURED pointer mutation of
 * `lc` (p++, p--, p+=k, p=q, post-inc deref) inside an index sub-expr; a RAW mutation sets
 * lc->raw_accessed (excluded by the promotion tally), so the two together fully cover
 * index-mutates-base for the promoted [_fcc_img],Y deref. */
int ir_cur_n(void) { return g_ir_n; }

/* (ir_op_carries_s_delta + ir_reverse_call_args retired — T5-C C5: a
 * right-to-left call walks its args in reverse order at record time, so
 * no post-hoc u0 compensation or range reordering exists.) */

int ir_local_mutated_since(int snap, void *lc)
{
    int j;
    for (j = snap; j < g_ir_n; j++) {
        IrOp o = g_ir[j].op;
        if ((o == IR_STORE_PTR_OFFSET || o == IR_STORE_PTR_OFFSET_IMG ||
             o == IR_STORE_PTR_LOCAL  || o == IR_STORE_PTR_LOCAL_IMG ||
             o == IR_FPR_STORE_PTR_LOCAL || o == IR_FPR_STORE_PTR_LOCAL_IMG ||
             o == IR_DEREF_POSTINC_LOCAL || o == IR_DEREF_POSTINC_LOCAL_IMG) &&
            g_ir[j].ptr == lc)
            return 1;
    }
    return 0;
}

static void
ir_build_tac(void)
{
    int j = 0, clean = 0;
    g_bb_n = 0; g_ntemp = 0;
    while (j < g_ir_n) {
        int lo;
        if (ir_node_is_bb_barrier(&g_ir[j])) { j++; continue; }   /* barrier between BBs */
        lo = j;
        while (j < g_ir_n && !ir_node_is_bb_barrier(&g_ir[j])) j++;
        if (g_bb_n >= IR_MAX_BB) {
            fprintf(stderr, "fcc: TAC basic-block overflow (>%d)\n", IR_MAX_BB);
            exit(1);
        }
        g_bb[g_bb_n].lo = lo; g_bb[g_bb_n].hi = j;
        g_bb[g_bb_n].clean = tac_sim_bb(lo, j);
        if (g_bb[g_bb_n].clean) clean++;
        g_bb_n++;
    }
    if (g_tac_stats)
        fprintf(stderr, "fcc-tac: %-20s %3d bb / %3d clean / %4d temps\n",
                g_func_name[0] ? g_func_name : "?", g_bb_n, clean, g_ntemp);
}

/* Naive lowerer: re-emit the raw op stream THROUGH the BB structure.  Identical
 * order to the linear (peephole-off) replay -> byte-identical, which proves the
 * BB partition covers every node exactly once and in order (the risk gate). */
static void
tac_lower(void)
{
    int b = 0, j = 0;
    while (j < g_ir_n) {
        if (b < g_bb_n && g_bb[b].lo == j) {
            int k;
            for (k = g_bb[b].lo; k < g_bb[b].hi; k++) emit_lower_op(&g_ir[k]);
            j = g_bb[b].hi; b++;
        } else if (g_ir[j].op == IR_TEXT) {
            if (g_ir[j].text_len) fwrite(g_ir[j].text, 1, g_ir[j].text_len, g_out);
            j++;
        } else if (ir_node_is_bb_barrier(&g_ir[j])) {
            emit_lower_op(&g_ir[j]);   /* structured barrier (e.g. IR_DEREF_LOCAL) */
            j++;
        } else {
            fprintf(stderr, "fcc: TAC partition gap: op %d at index %d not in a BB\n",
                    (int)g_ir[j].op, j);
            exit(1);
        }
    }
}

/* P1.3 — linear-scan spill allocation over a CLEAN basic block [lo,hi).
 *
 * In a clean BB the structured ops touch only A / _fcc_tmp_b / the hw stack —
 * never X or Y — so a PUSH_A'd value can live in X or Y instead of on the stack.
 * Spills nest LIFO, so a tiny register file {X, Y} (overflow -> hw stack) colours
 * them.  Eliminating a stack push makes the hw stack 2 bytes shallower for that
 * push's window, so every n,S access in the window (IR_LOAD_LOCAL/IR_STORE_LOCAL,
 * which carry the emit-time g_s_delta in u0 from P1.1) drops its offset by the
 * outstanding moved-push bytes.  PUSH_LONG/POP_LONG stay on the stack (a 32-bit
 * value doesn't fit a 16-bit index reg) and so do not move / adjust. */
static int g_alloc_sp[IR_MAX_NODES];   /* per-BB spill-location stack (0=X,1=Y,2/3=stack) */

static void
ir_alloc_bb(int lo, int hi)
{
    int j, spn = 0, reg_inuse = 0, moved = 0;   /* reg_inuse: bit0=X, bit1=Y; moved=bytes */
    for (j = lo; j < hi; j++) {
        switch (g_ir[j].op) {
        case IR_PUSH_A:
            if (!(reg_inuse & 1)) {
                reg_inuse |= 1; g_ir[j].op = IR_TAX; moved += 2; g_alloc_sp[spn++] = 0;
            } else if (!(reg_inuse & 2)) {
                reg_inuse |= 2; g_ir[j].op = IR_TAY; moved += 2; g_alloc_sp[spn++] = 1;
            } else {
                g_alloc_sp[spn++] = 2;          /* overflow: stays on the hw stack */
            }
            break;
        case IR_POP_A: {
            int loc = (spn > 0) ? g_alloc_sp[--spn] : 2;
            if (loc == 0)      { g_ir[j].op = IR_TXA; reg_inuse &= ~1; moved -= 2; }
            else if (loc == 1) { g_ir[j].op = IR_TYA; reg_inuse &= ~2; moved -= 2; }
            /* loc==2: stays IR_POP_A */
            break;
        }
        case IR_PUSH_LONG: g_alloc_sp[spn++] = 3; break;   /* on the hw stack, not moved */
        case IR_POP_LONG:  if (spn > 0) spn--; break;
        case IR_LOAD_LOCAL: case IR_STORE_LOCAL: case IR_INCDEC_LOCAL:
        case IR_BINOP_MEM_LOCAL:
            /* n,S offset (u0) is SP-relative: fix it for pushes lifted to X/Y.
             * IR_INCDEC_LOCAL's load and store share this one offset (no push/pop
             * within the op).  IR_INCDEC_LOCAL_IMG is DP -> falls through, no fixup.
             * IR_BINOP_MEM_LOCAL is a folded `<op> n,S` (u0 already -2 for the
             * removed PUSH_A); it gets the same fixup for other moved pushes. */
            if ((int)g_ir[j].u0 >= moved) g_ir[j].u0 -= (unsigned)moved;
            break;
        default: break;
        }
    }
}

/* ===========================================================================
 * P1.3 increment 2 — local promotion (DP-IMG register file).
 *
 * Give each of the hottest int/char scalar LOCALS a dedicated DP-IMG slot
 * (_fcc_img{k} @ task-page $C0+2k) for the WHOLE function, retargeting its
 * IR_LOAD_LOCAL/STORE_LOCAL accesses to the IMG variants (LDA/STA _fcc_img{k},
 * DP-relative).  This replaces every per-access `n,S` frame reference (4 cyc)
 * with a direct-page reference (3 cyc) — the per-iteration loop thrash.
 *
 * Whole-function dedication: slot k is owned by one local for the entire
 * function, so promoted locals never interfere and no liveness pass is needed.
 *
 * Safety (each verified — see docs/history/resume/RESUME-2026-06-27-...):
 *   - int/char scalar LOCALS only (params: a later increment + entry seeding);
 *     pointers/longs/arrays/structs keep their n,S / 4-byte paths.
 *   - addr_taken excluded: the local's address escaped, its stack slot IS its
 *     identity.
 *   - raw_accessed excluded: a raw n,S access the IR can't retarget would
 *     diverge from the IMG slot (the ++/-- store net).
 *   - call-clean: a JSR/JSL/FARCALL to anything but a _fcc_ runtime helper may
 *     reach another C function that reuses this task DP page's $C0..$DF.  _fcc_
 *     helpers touch only $E8+; syscalls run on the kernel's separate DP page
 *     but are conservatively excluded too.
 *   - the slot is uninitialized at entry; reading a never-written local is UB
 *     either way (same as the unseeded stack slot).
 * ========================================================================== */
#define IR_NIMG       16    /* _fcc_img0.._fcc_img15 ($C0..$DF) */
#define IR_PROMOTE_MIN 3    /* min weighted accesses to bother promoting */
/* P1.3-inc3: a loop-body access (IR node u1==1) is read every iteration, so it
 * is worth far more than a straight-line access.  Weighting it lets a loop-bound
 * var with a low STATIC count (e.g. `n` in `for(i<n)`, 1 static access) clear the
 * threshold and promote.  >= IR_PROMOTE_MIN so a single loop access qualifies. */
#define IR_LOOP_WEIGHT 8
/* P1.4 B1b: min static pointer-op accesses to promote a pointer local to an img
 * PAIR.  A deref is ~5 instrs -> 1, so even 2 accesses pay for the 2 slots. */
#define IR_PTR_PROMOTE_MIN 2

/* P1.4 B1b: a pointer local is promotable to a DP-IMG PAIR iff it is a single-
 * level pointer whose pointee is a 2-byte-or-smaller scalar (int/char/void) so
 * the promoted deref is a simple `LDA [_fcc_img{k}]` (+char/void mask).  Excludes
 * ptr-to-ptr (deref yields a pointer), long-ptr/float-ptr (4-byte pointee), and
 * struct-ptr (field paths); those keep the n,S deref. */
int
ir_ptr_promotable(Local *lc)
{
    tword pointee;
    if (!ISPTR(lc->type)) return 0;
    pointee = DECREF(lc->type);
    if (ISPTR(pointee)) return 0;       /* ptr-to-ptr: deref yields a pointer */
    if (ISFTN(pointee)) return 0;       /* fn-ptr (DECREF -> FTN<VOID>): not data */
    return BTYPE(pointee) == BT_INT  ||
           BTYPE(pointee) == BT_CHAR ||
           BTYPE(pointee) == BT_VOID;
}

/* B1c-2a-step-2: 1 iff `op` is safe to sit in a walk-store RHS span being
 * push-ELIDED — i.e. its lowering is SP-INDEPENDENT and carries no `n,S`, so
 * removing the SETUP's 4-byte push shifts no offset.  The promoted img ops, the
 * absolute global/literal ops, the DP _fcc_tmp_b stash, and the A-only ALU ops
 * qualify; every n,S op, PUSH/POP (SP-changing), long push/pop, the deref/store
 * BARRIERS in their n,S forms, and any opaque IR_TEXT do NOT (default 0 -> the
 * caller keeps the push, byte-identical to today).  A separate pc-reference test
 * in the caller handles a RHS that reads/writes the dest pointer itself. */
static int
ir_walk_span_sp_indep(IrOp op)
{
    switch (op) {
    case IR_LOAD_LOCAL_IMG:  case IR_STORE_LOCAL_IMG:
    case IR_INCDEC_LOCAL_IMG:
    case IR_DEREF_LOCAL_IMG:  case IR_LOAD_PTR_LOCAL_IMG:
    case IR_STORE_PTR_LOCAL_IMG: case IR_STORE_PTR_OFFSET_IMG:
    /* P3-2.5a FPR-native IMG forms: img DP + FPR DP only, no n,S, SP-indep. */
    case IR_FPR_LOAD_PTR_LOCAL_IMG: case IR_FPR_STORE_PTR_LOCAL_IMG:
    case IR_DEREF_POSTINC_LOCAL_IMG:
    /* IR_DEREF_POSTINC_LOCAL_IMG (int stride>1) wobbles the stack with a BALANCED
     * PHA..PLA over DP-only ops -> net 0, no n,S exposed -> safe.  NOT here:
     * IR_INDEX_DEREF_LOCAL_IMG does a LONE PLA (net SP -2, consuming a base pushed
     * by an earlier IR_PUSH_A) -> not SP-independent.  It is dead for collapse
     * anyway (its mandatory IR_PUSH_A partner is non-whitelisted and co-resident,
     * so the span is already rejected), but excluding it keeps this predicate's
     * contract literally true and forecloses a future `p[i]`-promotion footgun. */
    case IR_LOAD_LIT: case IR_LOAD_GLOBAL:
    case IR_STORE_GLOBAL_INT: case IR_STORE_GLOBAL_CHAR:
    case IR_STASH_RHS_INT:
    case IR_BINOP: case IR_MULCONST: case IR_SHIFT_CONST:
        return 1;
    default:
        return 0;
    }
}

/* Promoted PARAMS need a one-time entry seed (copy the incoming arg from its
 * `n,S` stack home into its DP-IMG slot).  ir_promote_locals records them here;
 * ir_emit_param_seeds (called at the IR_SEED_MARK replay point) emits the seeds.
 * Promoted LOCALS need no seed (an uninitialized local is UB either way). */
static Local *g_promoted_param[IR_NIMG];
static int    g_promoted_param_slot[IR_NIMG];
static int    g_n_promoted_params = 0;

/* 1 iff rendered asm `t` contains a call (JSR/JSL/FARCALL) to anything other
 * than a `_fcc_`-prefixed runtime helper.  Fail-safe: any call whose target we
 * can't positively confirm as _fcc_ counts as unsafe. */
static int
ir_call_target_unsafe(const char *t, const char *mn)
{
    size_t mlen = strlen(mn);
    const char *p = t;
    while ((p = strstr(p, mn)) != NULL) {
        const char *q = p + mlen;
        p = q;
        while (*q == ' ' || *q == '\t') q++;
        if (strncmp(q, "_fcc_", 5) != 0) return 1;
    }
    return 0;
}

static int
ir_text_has_unsafe_call(const char *t)
{
    if (strstr(t, "FARCALL")) return 1;              /* always a user far call */
    /* Pile-internal near call (emit_pile_call): PHK/PEA tgt-1/PHK/RTL — carries
     * NO JSR/JSL/FARCALL token but DOES clobber the _fcc_img loop-promotion slots
     * (fgets etc. use them).  Without treating it as a call, a --pile loop that
     * pile-calls a libc fn was wrongly deemed call-clean; a live local promoted
     * into _fcc_img got clobbered across the call (the resolver's `f = fopen();
     * while (fgets(...,f)) ...` hung — fgets trashed f in _fcc_img2/3).  The RTL
     * transfer is tagged `; PILECALL` (only emit_pile_call, only in --pile) so we
     * don't confuse it with an early-return epilogue RTL (which has no tag). */
    if (strstr(t, "PILECALL")) return 1;
    if (ir_call_target_unsafe(t, "JSR")) return 1;
    if (ir_call_target_unsafe(t, "JSL")) return 1;
    return 0;
}

/* P1.4 loop-scoped (region) promotion plan: (local, DP-IMG slot) pairs to seed at
 * IR_LOOP_BEGIN and write back at IR_LOOP_END, keyed by loop id.  Filled by
 * ir_promote_loops, consumed by ir_emit_loop_seeds/writeback. */
#define IR_MAX_LOOP_REG 32
typedef struct { unsigned loop_id; Local *lc; int slot; } LoopReg;
static LoopReg g_loop_reg[IR_MAX_LOOP_REG];
static int     g_loop_reg_n;

static int
loop_reg_claimed(Local *lc)
{
    int i;
    for (i = 0; i < g_loop_reg_n; i++) if (g_loop_reg[i].lc == lc) return 1;
    return 0;
}

/* Region-scoped scalar promotion for a function the WHOLE-function gate rejected
 * (it makes a non-_fcc_ call, so $C0..$DF can't be held function-wide).  For each
 * CALL-FREE loop region [IR_LOOP_BEGIN..IR_LOOP_END], promote hot int scalars
 * accessed inside it to a DP-IMG slot FOR THE DURATION OF THE LOOP: seed
 * n,S->slot at entry, write slot->n,S at exit.  The seed/write-back bridge
 * promoted (in-loop) <-> n,S (everywhere else), so correctness is independent of
 * outside accesses; each var is promoted in at most ONE region (loop_reg_claimed),
 * and slots are allocated monotonically and NOT reused across regions (no overlap
 * -> no conflict).  break + the normal loop-exit both land at the region's exit
 * label where the write-back sits; continue stays in-region (slot persists = the
 * win); a return inside the loop is safe (the value dies).  INT only for now (a
 * char's n,S write-back width is a separate verification); pointers later.
 * Indirect calls are excluded by the caller (tokenless -> can't be localized). */
static void
ir_promote_loops(void)
{
    int rb, chosen = 0;
    for (rb = 0; rb < g_ir_n && chosen < IR_NIMG; rb++) {
        Local *cand[MAX_LOCALS];
        int    cnt[MAX_LOCALS];
        int    ncand = 0, j, c, lo, hi, callfree;
        unsigned id;
        if (g_ir[rb].op != IR_LOOP_BEGIN) continue;
        id = g_ir[rb].u0;
        lo = rb;
        hi = -1;
        for (j = rb + 1; j < g_ir_n; j++)
            if (g_ir[j].op == IR_LOOP_END && g_ir[j].u0 == id) { hi = j; break; }
        if (hi < 0) continue;                         /* unmatched (shouldn't happen) */
        /* region promotable?  Disqualify on (a) any non-_fcc_ call (would reuse
         * $C0..$DF), or (b) any user label / goto (the "_uL_" marker): a goto OUT
         * of the region (BRL <fn>_uL_x inside [lo,hi)) jumps past IR_LOOP_END and
         * skips the slot->n,S write-back -> stale read; a goto INTO the region
         * (a <fn>_uL_x: label def inside [lo,hi)) skips the IR_LOOP_BEGIN seed ->
         * garbage slot.  break/continue use compiler labels (_L<n>, not _uL_) and
         * stay within the structured BEGIN/END bracketing, so they are safe.
         * (indirect calls already excluded function-wide.) */
        callfree = 1;
        for (j = lo + 1; j < hi; j++)
            if (g_ir[j].op == IR_TEXT && g_ir[j].text &&
                (ir_text_has_unsafe_call(g_ir[j].text) ||
                 strstr(g_ir[j].text, "_uL_"))) { callfree = 0; break; }
        if (!callfree) continue;
        /* tally promotable int scalars accessed within the region (all loop-hot). */
        for (j = lo + 1; j < hi; j++) {
            Local *lc; IrOp op = g_ir[j].op;
            if (op != IR_LOAD_LOCAL && op != IR_STORE_LOCAL && op != IR_INCDEC_LOCAL)
                continue;
            lc = (Local *)g_ir[j].ptr;
            if (!lc || (lc->kind != LK_LOCAL && lc->kind != LK_PARAM)) continue;
            if (lc->type != LT_INT) continue;          /* int-only v1 */
            if (lc->addr_taken || lc->raw_accessed) continue;
            if (loop_reg_claimed(lc)) continue;        /* already promoted in an enclosing/earlier region */
            for (c = 0; c < ncand; c++) if (cand[c] == lc) break;
            if (c == ncand) { if (ncand >= MAX_LOCALS) continue; cand[ncand]=lc; cnt[ncand]=0; ncand++; }
            cnt[c] += IR_LOOP_WEIGHT;                   /* every region access is loop-hot */
        }
        /* assign slots to the hottest; rewrite THIS region's ops to _IMG. */
        while (chosen < IR_NIMG && g_loop_reg_n < IR_MAX_LOOP_REG) {
            int best = -1, bi;
            for (bi = 0; bi < ncand; bi++)
                if (cnt[bi] >= IR_PROMOTE_MIN && (best < 0 || cnt[bi] > cnt[best])) best = bi;
            if (best < 0) break;
            for (j = lo + 1; j < hi; j++) {
                if (g_ir[j].ptr != cand[best]) continue;
                if (g_ir[j].op == IR_LOAD_LOCAL)        { g_ir[j].op = IR_LOAD_LOCAL_IMG;   g_ir[j].u0 = (unsigned)chosen; }
                else if (g_ir[j].op == IR_STORE_LOCAL)  { g_ir[j].op = IR_STORE_LOCAL_IMG;  g_ir[j].u0 = (unsigned)chosen; }
                else if (g_ir[j].op == IR_INCDEC_LOCAL) { g_ir[j].op = IR_INCDEC_LOCAL_IMG; g_ir[j].u0 = (unsigned)chosen; }
            }
            g_loop_reg[g_loop_reg_n].loop_id = id;
            g_loop_reg[g_loop_reg_n].lc      = cand[best];
            g_loop_reg[g_loop_reg_n].slot    = chosen;
            g_loop_reg_n++;
            cnt[best] = -1;
            chosen++;
        }
    }
    if (g_tac_stats && g_loop_reg_n)
        fprintf(stderr, "fcc-promote-loop: %-16s %d region slot(s)\n",
                g_func_name[0] ? g_func_name : "?", g_loop_reg_n);
}

static void
ir_promote_locals(void)
{
    Local *cand[MAX_LOCALS];
    int    cnt[MAX_LOCALS];
    int    ncand = 0, chosen = 0, j, c;

    g_n_promoted_params = 0;
    g_loop_reg_n = 0;
    if (!g_ir_opt) return;

    /* 1. Eligibility: any call that may reach another C function (which could
     * reuse this task DP page's $C0..$DF) disqualifies WHOLE-function promotion.
     *  (a) indirect (fn-ptr) calls — tokenless computed-RTS trampoline that the
     *      text scan below cannot see; flagged directly by emit_call_indirect.
     *      Also blocks region promotion (can't localize a tokenless call).
     *  (b) any token-bearing JSR/JSL/FARCALL to a non-_fcc_ target -> fall back to
     *      LOOP-SCOPED promotion of the function's CALL-FREE loop regions. */
    if (g_has_indirect_call) return;
    for (j = 0; j < g_ir_n; j++)
        if (g_ir[j].op == IR_TEXT && g_ir[j].text &&
            ir_text_has_unsafe_call(g_ir[j].text)) {
            ir_promote_loops();
            return;
        }

    /* 2. Tally accesses per promotable int/char scalar local OR param. */
    for (j = 0; j < g_ir_n; j++) {
        Local *lc;
        IrOp  op = g_ir[j].op;
        int   loop;
        if (op != IR_LOAD_LOCAL && op != IR_STORE_LOCAL &&
            op != IR_INCDEC_LOCAL) continue;
        lc = (Local *)g_ir[j].ptr;
        if (!lc || (lc->kind != LK_LOCAL && lc->kind != LK_PARAM)) continue;
        if (lc->type != LT_INT && lc->type != LT_CHAR) continue;
        if (lc->addr_taken || lc->raw_accessed) continue;
        /* PARAMS cost a 4-byte entry seed -> only promote when loop-hot so the
         * seed is amortized; LOCALS have no seed and stay un-gated. */
        if (lc->kind == LK_PARAM && !lc->loop_accessed) continue;
        for (c = 0; c < ncand; c++) if (cand[c] == lc) break;
        if (c == ncand) {
            if (ncand >= MAX_LOCALS) continue;
            cand[ncand] = lc; cnt[ncand] = 0; ncand++;
        }
        /* loop-hot flag: LOAD/STORE carry it in u1; IR_INCDEC_LOCAL packs is_inc
         * in bit0 and loop in bit1 (P1.4). */
        loop = (op == IR_INCDEC_LOCAL) ? (g_ir[j].u1 & 2) : (int)g_ir[j].u1;
        cnt[c] += loop ? IR_LOOP_WEIGHT : 1;   /* P1.3-inc3: weight loop accesses */
    }

    /* 3. Greedily assign DP-IMG slots to the hottest (>= IR_PROMOTE_MIN). */
    while (chosen < IR_NIMG) {
        int best = -1, bi;
        for (bi = 0; bi < ncand; bi++)
            if (cnt[bi] >= IR_PROMOTE_MIN && (best < 0 || cnt[bi] > cnt[best]))
                best = bi;
        if (best < 0) break;
        for (j = 0; j < g_ir_n; j++) {
            if (g_ir[j].ptr != cand[best]) continue;
            if (g_ir[j].op == IR_LOAD_LOCAL) {
                g_ir[j].op = IR_LOAD_LOCAL_IMG;  g_ir[j].u0 = (unsigned)chosen;
            } else if (g_ir[j].op == IR_STORE_LOCAL) {
                g_ir[j].op = IR_STORE_LOCAL_IMG; g_ir[j].u0 = (unsigned)chosen;
            } else if (g_ir[j].op == IR_INCDEC_LOCAL) {
                /* discarded ++/-- -> single INC/DEC _fcc_img{chosen}.  u1 keeps
                 * is_inc in bit0 (the loop bit is now irrelevant). */
                g_ir[j].op = IR_INCDEC_LOCAL_IMG; g_ir[j].u0 = (unsigned)chosen;
            }
        }
        /* A promoted PARAM must be seeded from its stack home at entry. */
        if (cand[best]->kind == LK_PARAM) {
            g_promoted_param[g_n_promoted_params]      = cand[best];
            g_promoted_param_slot[g_n_promoted_params] = chosen;
            g_n_promoted_params++;
        }
        cnt[best] = -1;                                  /* consumed */
        chosen++;
    }

    /* 4. (B1b/B1c) Promote hot int/char/void-pointee pointer locals/params to a
     * CONTIGUOUS img PAIR {chosen (offset), chosen+1 (bank)}.  Reuses `chosen`
     * so pairs follow the scalar slots.  Correctness rests on the same net as
     * scalars: addr_taken / raw_accessed exclude any access not among the five
     * structured pointer ops (IR_DEREF_LOCAL, IR_LOAD_PTR_LOCAL, IR_STORE_PTR_
     * LOCAL, IR_STORE_PTR_OFFSET, the B1c IR_DEREF_POSTINC_LOCAL, and the
     * P3-2.5a FPR-native IR_FPR_LOAD/STORE_PTR_LOCAL), and
     * emit_load_base/deref/load/store/postinc all route a pointer's bytes through
     * those ops (or set raw_accessed), so a promoted pointer always sources from
     * its img pair. */
    {
        Local *pc[MAX_LOCALS];
        int    pn[MAX_LOCALS];
        int    nptr = 0, pi;
        for (j = 0; j < g_ir_n; j++) {
            Local *lc; IrOp op = g_ir[j].op;
            if (op != IR_DEREF_LOCAL && op != IR_LOAD_PTR_LOCAL &&
                op != IR_STORE_PTR_LOCAL && op != IR_STORE_PTR_OFFSET &&
                op != IR_FPR_LOAD_PTR_LOCAL &&
                op != IR_FPR_STORE_PTR_LOCAL &&
                op != IR_DEREF_POSTINC_LOCAL &&
                op != IR_INDEX_DEREF_LOCAL &&
                op != IR_WALK_STORE_SETUP) continue;
            /* B1c-2b: a p[i] whose index sub-expr STRUCTURALLY mutates the base must
             * NOT promote (stays un-promoted, reads the pushed pre-index snapshot). */
            if (op == IR_INDEX_DEREF_LOCAL && (g_ir[j].u1 & 2u)) continue;
            lc = (Local *)g_ir[j].ptr;
            if (!lc || (lc->kind != LK_LOCAL && lc->kind != LK_PARAM)) continue;
            if (!ir_ptr_promotable(lc)) continue;
            if (lc->addr_taken || lc->raw_accessed) continue;
            /* PARAMS cost a 4-byte entry seed -> only promote when loop-hot. */
            if (lc->kind == LK_PARAM && !lc->loop_accessed) continue;
            for (c = 0; c < nptr; c++) if (pc[c] == lc) break;
            if (c == nptr) {
                if (nptr >= MAX_LOCALS) continue;
                pc[nptr] = lc; pn[nptr] = 0; nptr++;
            }
            /* B1c: a folded `*p++` is one deref + one offset bump = 2 pointer
             * touches; weight it 2 so a lone `*p++` still meets IR_PTR_PROMOTE_MIN
             * (parity with the old separate LOAD_PTR + STORE_PTR_OFFSET pair).
             * B1c-2a-step-2: a folded `*p++ = RHS` SETUP likewise folds a load +
             * an offset store-back = 2 pointer touches -> the same weight 2. */
            pn[c] += (op == IR_DEREF_POSTINC_LOCAL ||
                      op == IR_WALK_STORE_SETUP) ? 2 : 1;
        }
        while (chosen + 1 < IR_NIMG) {     /* a pointer needs 2 contiguous slots */
            int best = -1;
            for (pi = 0; pi < nptr; pi++)
                if (pn[pi] >= IR_PTR_PROMOTE_MIN && (best < 0 || pn[pi] > pn[best]))
                    best = pi;
            if (best < 0) break;
            for (j = 0; j < g_ir_n; j++) {
                if (g_ir[j].ptr != pc[best]) continue;
                switch (g_ir[j].op) {
                case IR_DEREF_LOCAL:                            /* u1 = pointee type */
                    g_ir[j].op = IR_DEREF_LOCAL_IMG;      g_ir[j].u0 = (unsigned)chosen; break;
                case IR_LOAD_PTR_LOCAL:
                    g_ir[j].op = IR_LOAD_PTR_LOCAL_IMG;   g_ir[j].u0 = (unsigned)chosen; break;
                case IR_STORE_PTR_LOCAL:                        /* u1 = bank-zero flag */
                    g_ir[j].op = IR_STORE_PTR_LOCAL_IMG;  g_ir[j].u0 = (unsigned)chosen; break;
                case IR_FPR_LOAD_PTR_LOCAL:                     /* u1 = FPR index (kept) */
                    g_ir[j].op = IR_FPR_LOAD_PTR_LOCAL_IMG;  g_ir[j].u0 = (unsigned)chosen; break;
                case IR_FPR_STORE_PTR_LOCAL:
                    g_ir[j].op = IR_FPR_STORE_PTR_LOCAL_IMG; g_ir[j].u0 = (unsigned)chosen; break;
                case IR_STORE_PTR_OFFSET:
                    g_ir[j].op = IR_STORE_PTR_OFFSET_IMG; g_ir[j].u0 = (unsigned)chosen; break;
                case IR_DEREF_POSTINC_LOCAL:                    /* u1 = (stride<<1)|is_inc */
                    g_ir[j].op = IR_DEREF_POSTINC_LOCAL_IMG; g_ir[j].u0 = (unsigned)chosen; break;
                case IR_INDEX_DEREF_LOCAL:                     /* u1 bit0=is_byte, bit1=base_mutated */
                    if (g_ir[j].u1 & 2u) break;                /* index-mutates-base: stay un-promoted */
                    g_ir[j].op = IR_INDEX_DEREF_LOCAL_IMG; g_ir[j].u0 = (unsigned)chosen; break;
                case IR_WALK_STORE_SETUP:                      /* u1 = (stride<<1)|is_inc */
                    /* Promote to the push-RETAINED img form (byte-identical to today's
                     * promoted `*p++=`).  A separate post-pass below collapses it when
                     * the RHS span is push-elision-safe.  The paired IR_WALK_STORE
                     * stays un-collapsed here (its default lowering pops the push). */
                    g_ir[j].op = IR_WALK_STORE_SETUP_IMG; g_ir[j].u0 = (unsigned)chosen; break;
                default: break;
                }
            }
            if (pc[best]->kind == LK_PARAM) {  /* 4-byte seed (ir_emit_param_seeds detects the type) */
                g_promoted_param[g_n_promoted_params]      = pc[best];
                g_promoted_param_slot[g_n_promoted_params] = chosen;
                g_n_promoted_params++;
            }
            pn[best] = -1;
            chosen += 2;                                  /* consumed the pair */
        }
    }

    /* 4b. Promote hot LONG locals/params to a contiguous img PAIR
     * {chosen (low word), chosen+1 (high word)}, after the scalars and
     * pointers and out of the same slot budget.
     *
     * Why longs matter enough to spend two slots on: a filesystem is made of
     * 32-bit block numbers.  The 0.1 gate measured 2.11BSD's bmap compiled by
     * fcc at 2480 bytes, a quarter of it direct-page traffic, and NOTHING in
     * it could promote -- every hot variable is a daddr_t and step 2 above
     * takes only LT_INT and LT_CHAR.
     *
     * Correctness rests on the same net as the scalars and pointers: a long
     * local is reached ONLY through IR_LOAD_LONG_LOCAL / IR_STORE_LONG_LOCAL
     * (emit_load_local and emit_store_local funnel both), and anything else
     * that can see its bytes -- &x, a raw access, a struct copy -- sets
     * addr_taken or raw_accessed and disqualifies it here.  LT_FLOAT shares
     * those two ops and is EXCLUDED: it is also 4 bytes, but its value travels
     * through the _fcc_fb* soft-float cells rather than A + _fcc_long_hi, so
     * the pair would not be where the float code looks. */
    {
        Local *gc[MAX_LOCALS];
        int    gn[MAX_LOCALS];
        int    nlong = 0, gi;
        for (j = 0; j < g_ir_n; j++) {
            Local *lc; IrOp op = g_ir[j].op;
            if (op != IR_LOAD_LONG_LOCAL && op != IR_STORE_LONG_LOCAL) continue;
            lc = (Local *)g_ir[j].ptr;
            if (!lc || (lc->kind != LK_LOCAL && lc->kind != LK_PARAM)) continue;
            if (lc->type != LT_LONG) continue;         /* not LT_FLOAT: see above */
            if (lc->addr_taken || lc->raw_accessed) continue;
            /* A promoted PARAM costs a 4-byte entry seed, so it has to be
             * loop-hot to pay for itself -- same gate as scalars and pointers. */
            if (lc->kind == LK_PARAM && !lc->loop_accessed) continue;
            for (c = 0; c < nlong; c++) if (gc[c] == lc) break;
            if (c == nlong) {
                if (nlong >= MAX_LOCALS) continue;
                gc[nlong] = lc; gn[nlong] = 0; nlong++;
            }
            gn[c] += 1;
        }
        while (chosen + 1 < IR_NIMG) {   /* a long needs 2 contiguous slots */
            int best = -1;
            for (gi = 0; gi < nlong; gi++)
                if (gn[gi] >= IR_PTR_PROMOTE_MIN && (best < 0 || gn[gi] > gn[best]))
                    best = gi;
            if (best < 0) break;
            for (j = 0; j < g_ir_n; j++) {
                if (g_ir[j].ptr != gc[best]) continue;
                if (g_ir[j].op == IR_LOAD_LONG_LOCAL) {
                    g_ir[j].op = IR_LOAD_LONG_LOCAL_IMG;
                    g_ir[j].u0 = (unsigned)chosen;
                } else if (g_ir[j].op == IR_STORE_LONG_LOCAL) {
                    g_ir[j].op = IR_STORE_LONG_LOCAL_IMG;
                    g_ir[j].u0 = (unsigned)chosen;   /* u1 (widen arm) is kept */
                }
            }
            if (gc[best]->kind == LK_PARAM) {
                g_promoted_param[g_n_promoted_params]      = gc[best];
                g_promoted_param_slot[g_n_promoted_params] = chosen;
                g_n_promoted_params++;
            }
            gn[best] = -1;
            chosen += 2;
        }
    }

    /* 5. (B1c-2a-step-2) COLLAPSE a promoted `*p++ = RHS` walk-WRITE.  The promoted
     * SETUP (IR_WALK_STORE_SETUP_IMG) still pushes the 4-byte dest only to keep
     * old-p alive across the RHS — but img{k} ALREADY holds old-p (the bump hasn't
     * happened), so when the RHS span needs no stack the setup is pure overhead.
     * Drop it (-> _NONE) and store straight through the slot, bumping AFTER (->
     * IR_WALK_STORE_IMG).  Runs AFTER every promotion rewrite so the span test sees
     * each RHS op in its FINAL img-vs-n,S form (e.g. `*d++=*s++` collapses only once
     * s is promoted to its img deref).  Two gates, both behaviour-preserving:
     *   (a) every op strictly inside (SETUP, STORE) is push-elision-safe — SP-
     *       independent, no n,S, no IR_TEXT barrier (ir_walk_span_sp_indep), so
     *       eliding the push shifts no offset;
     *   (b) no op inside REFERENCES p (ptr == pc): today the setup bumps p's slot
     *       BEFORE the RHS, so a RHS that reads p sees the bumped value, while the
     *       collapsed form bumps AFTER — any read/write of p would diverge.  This
     *       also covers self-mutation (`*p++ = *p++`).
     * Any failure leaves the byte-identical promoted-not-collapsed form. */
    {
        int s;
        for (s = 0; s < g_ir_n; s++) {
            Local *pc; int st, t, safe;
            if (g_ir[s].op != IR_WALK_STORE_SETUP_IMG) continue;
            pc = (Local *)g_ir[s].ptr;
            /* paired store = next IR_WALK_STORE with the same ptr (no nesting: a
             * statement RHS can't hold another statement-level `*q++ =`). */
            st = -1;
            for (t = s + 1; t < g_ir_n; t++)
                if (g_ir[t].op == IR_WALK_STORE && g_ir[t].ptr == pc) { st = t; break; }
            if (st < 0) continue;                         /* unpaired (shouldn't happen) */
            safe = 1;
            for (t = s + 1; t < st; t++) {
                if (!ir_walk_span_sp_indep(g_ir[t].op)) { safe = 0; break; }
                if (g_ir[t].ptr == pc)                  { safe = 0; break; }
            }
            if (!safe) continue;                          /* keep promoted-not-collapsed */
            g_ir[s].op  = IR_WALK_STORE_SETUP_NONE;       /* img{k} holds old-p: no setup */
            g_ir[st].op = IR_WALK_STORE_IMG;              /* STA [_fcc_img{k}] + bump */
            g_ir[st].u0 = g_ir[s].u0;                     /* the slot k */
            /* g_ir[st].u1 already = (stride<<1)|is_inc from emit_walk_store. */
        }
    }

    if (g_tac_stats && chosen)
        fprintf(stderr, "fcc-promote: %-20s %d slot(s) -> DP-IMG (%d param)\n",
                g_func_name[0] ? g_func_name : "?", chosen, g_n_promoted_params);
}

/* Emit the entry seeds for promoted PARAMS at the IR_SEED_MARK replay point:
 * copy each incoming arg from its `n,S` stack home into its DP-IMG slot.  Runs
 * right after the prologue (frame established, g_s_delta == 0 at entry) — forced
 * here so the param's `off+FRAMESIZE,S` operand is the entry offset regardless
 * of the live replay g_s_delta.  No-op when no param was promoted. */
void
ir_emit_param_seeds(void)
{
    int s, saved = g_s_delta;
    g_s_delta = 0;
    for (s = 0; s < g_n_promoted_params; s++) {
        Local *p = g_promoted_param[s];
        int    k = g_promoted_param_slot[s];
        /* Seed via the DO/256-GATED emit_slot_lda16, NOT a raw `LDA n,S`: a
         * param's stack home is off+FRAMESIZE, which overflows the 65816's 8-bit
         * n,S displacement once the frame exceeds ~255 bytes — emit_slot_lda16's
         * DO/ELSE/FIN far path is mandatory (a raw LDA n,S is rejected by merlin32
         * / silently truncated by fas -> wild seed -> wild deref).  Safe at the
         * IR_SEED_MARK replay point: emit_slot_lda16 only sets raw_accessed while
         * recording (g_recording==0 here), and g_s_delta is forced 0 above. */
        emit_slot_lda16(p, 0);                    /* A = offset / low word */
        ir_emitf("                STA     _fcc_img%d\n", k);
        if (ISPTR(p->type) || p->type == LT_LONG) {  /* 4 bytes: seed the pair's second slot */
            emit_slot_lda16(p, 2);                /* A = bank / high word */
            ir_emitf("                STA     _fcc_img%d\n", k + 1);
        }
    }
    g_s_delta = saved;
}

/* P1.4 loop-scoped promotion: region entry seeds (IR_LOOP_BEGIN) and exit
 * write-backs (IR_LOOP_END).  Increment A: the region plan (g_loop_reg, filled by
 * ir_promote_locals) is empty, so these are no-ops -> byte-identical.  Increment B
 * fills the plan and these emit `LDA <local>,S / STA _fcc_img{k}` (seed) and the
 * reverse (write-back) via the DO/256-gated emit_slot_lda16/sta16. */
void
ir_emit_loop_seeds(unsigned loop_id)
{
    int i, saved = g_s_delta;
    g_s_delta = 0;                          /* loop markers sit at a statement boundary (SP=frame base) */
    for (i = 0; i < g_loop_reg_n; i++) {
        if (g_loop_reg[i].loop_id != loop_id) continue;
        emit_slot_lda16(g_loop_reg[i].lc, 0);              /* A = local's n,S home value */
        ir_emitf("                STA     _fcc_img%d\n", g_loop_reg[i].slot);
    }
    g_s_delta = saved;
}

void
ir_emit_loop_writeback(unsigned loop_id)
{
    int i, saved = g_s_delta;
    g_s_delta = 0;
    for (i = 0; i < g_loop_reg_n; i++) {
        if (g_loop_reg[i].loop_id != loop_id) continue;
        ir_emitf("                LDA     _fcc_img%d\n", g_loop_reg[i].slot);
        emit_slot_sta16(g_loop_reg[i].lc, 0);             /* local's n,S home = A */
    }
    g_s_delta = saved;
}

/* fcc2 isel Phase 1: rewrite generic structured ops into explicit-machine-form
 * ops (load-op fold etc.).  Runs after ir_promote_locals (so it sees promoted
 * _fcc_img operands) and before ir_build_tac (so node-removing rewrites
 * re-partition cleanly).  Phase 1 Task 1: no-op skeleton (byte-identical risk
 * gate); the load-op fold matcher is added in a later task. */
/* fcc2 isel Phase 1 load-op fold: collapse the RHS-leaf binop window
 *   IR_PUSH_A / <leaf load> / IR_STASH_RHS_INT / IR_POP_A / IR_BINOP
 * into one `IR_BINOP_MEM_*` (LHS stays in A, leaf becomes the memory operand).
 * Single forward pass with a write cursor (stream filter): a folded window emits
 * one op for five.  The pattern is unambiguous (IR_STASH_RHS_INT is binop-only);
 * a non-leaf RHS puts extra ops between PUSH_A and STASH and never matches. */
static void
ir_select(void)
{
    int r = 0, w = 0;
    while (r < g_ir_n) {
        if (r + 4 < g_ir_n
            && g_ir[r].op   == IR_PUSH_A
            && g_ir[r+2].op == IR_STASH_RHS_INT
            && g_ir[r+3].op == IR_POP_A
            && g_ir[r+4].op == IR_BINOP) {
            IrNode *leaf = &g_ir[r+1];
            unsigned kind = g_ir[r+4].u0;
            /* Every field is set: a member left out is the caller's stack,
             * and `flags' read as stack garbage made IRF_RAW -- and with it
             * the BB partition and the allocator's choices -- depend on how
             * the host compiler laid out this frame (apple/fgx#544). */
            IrNode folded = {0};
            int matched = 0;
            if (leaf->op == IR_LOAD_GLOBAL && leaf->ptr
                && ((Global *)leaf->ptr)->type != LT_CHAR) {
                folded.op = IR_BINOP_MEM_GLOBAL; folded.ptr = leaf->ptr;
                folded.u0 = kind; folded.u1 = 0; matched = 1;
            } else if (leaf->op == IR_LOAD_LOCAL_IMG && leaf->ptr
                       && ((Local *)leaf->ptr)->type != LT_CHAR) {
                folded.op = IR_BINOP_MEM_IMG; folded.ptr = NULL;
                folded.u0 = leaf->u0; folded.u1 = kind; matched = 1;
            } else if (leaf->op == IR_LOAD_LOCAL && leaf->ptr
                       && ((Local *)leaf->ptr)->kind == LK_LOCAL    /* excludes params */
                       && ((Local *)leaf->ptr)->type != LT_CHAR
                       /* The folded `<op> n,S` lowers at g_s_delta = leaf->u0-2 (this
                        * pass runs at ambient g_s_delta==0), so check far-ness at that
                        * depth, NOT 0 — else a local near frame offset 255 under an
                        * outstanding push folds to an un-assemblable >255,S (it has no
                        * TSC far path, and can't have one: TSC would clobber the LHS in
                        * A).  The allocator's `moved` only shrinks the offset, so this
                        * pre-alloc depth is a sound conservative upper bound. */
                       && !slot_needs_far((Local *)leaf->ptr, (int)leaf->u0 - 2)) {
                folded.op = IR_BINOP_MEM_LOCAL; folded.ptr = leaf->ptr;
                folded.u0 = leaf->u0 - 2u;   /* removed PUSH_A -> stack 2 bytes shallower */
                folded.u1 = kind; matched = 1;
            }
            if (matched) {
                folded.text = NULL; folded.text_len = 0;
                /* The fold keeps the window's barrier-hood: if any of the
                 * five was recorded RAW, the one that replaces them is too. */
                folded.flags = g_ir[r].flags | g_ir[r+1].flags | g_ir[r+2].flags
                             | g_ir[r+3].flags | g_ir[r+4].flags;
                g_ir[w++] = folded;   /* one op replaces the five */
                r += 5;
                continue;
            }
        }
        if (w != r) g_ir[w] = g_ir[r];
        w++; r++;
    }
    g_ir_n = w;
}

/* ===========================================================================
 * fcc2 Phase 3 increment 0 — spill/reload measurement (READ-ONLY).
 *
 * Walks the FINAL IR (post-ir_allocate: PUSH_A held in X/Y is now TAX/TAY,
 * promoted locals are *_IMG, leaf binops are folded BINOP_MEM_*) using the
 * g_bb/g_t_* model ir_build_tac left in place.  Mutates NOTHING -> with
 * FCC_P3_STATS unset the pass never runs and the emitted bytes are identical to
 * a normal optimized build; with it set, only stderr differs.  Attributes
 * removable spill/reload bytes to levers L1-L5, bracketed floor/ceiling, so the
 * Phase-3 increment-1 lever is chosen from measurement (and the >=15% size-band
 * question is bracketed) BEFORE the global allocator is built.
 *
 * See toolchain/docs/superpowers/{specs,plans}/2026-06-29-fcc2-p3-inc0-*.
 * ------------------------------------------------------------------------- */

/* Emit one keyed measurement record for the current function (sparse). */
static void
p3_emit(const char *key, int count, int bytes)
{
    if (count == 0 && bytes == 0) return;
    fprintf(stderr, "fcc-p3\t%s\t%s\t%d\t%d\n",
            g_func_name[0] ? g_func_name : "?", key, count, bytes);
}

/* The Local-or-Global pointer a load/store op refers to (identity for same-
 * location matching); NULL for non-load/store ops.  Promoted IMG loads/stores
 * RETAIN .ptr (ir_promote_locals changes only .op/.u0), so this is uniform. */
static void *
p3_loc_ptr(int j)
{
    switch (g_ir[j].op) {
    case IR_LOAD_LOCAL:  case IR_LOAD_LOCAL_IMG:
    case IR_STORE_LOCAL: case IR_STORE_LOCAL_IMG:
    case IR_LOAD_GLOBAL: case IR_STORE_GLOBAL_INT: case IR_STORE_GLOBAL_CHAR:
        return g_ir[j].ptr;
    default: return NULL;
    }
}
static int p3_is_load(IrOp o)  { return o==IR_LOAD_LOCAL||o==IR_LOAD_LOCAL_IMG||o==IR_LOAD_GLOBAL; }
static int p3_is_store(IrOp o) { return o==IR_STORE_LOCAL||o==IR_STORE_LOCAL_IMG||
                                        o==IR_STORE_GLOBAL_INT||o==IR_STORE_GLOBAL_CHAR; }
/* a redef of loc: a store OR an INC/DEC of the same location (INCDEC isn't a
 * "producer" in p3_loc_ptr but DOES change the value -> must break a match). */
static int
p3_is_redef(int j, void *loc)
{
    IrOp o = g_ir[j].op;
    if (g_ir[j].ptr != loc) return 0;
    return p3_is_store(o) || o==IR_INCDEC_LOCAL || o==IR_INCDEC_LOCAL_IMG;
}

/* removable bytes for the reload at j: its load form (+char mask if applicable). */
static int
p3_reload_bytes(int j)
{
    IrOp o = g_ir[j].op;
    int  b = (o == IR_LOAD_GLOBAL) ? 3 : 2;            /* abs=3 ; ,S / dp = 2 */
    if (o == IR_LOAD_GLOBAL) {
        if (g_ir[j].ptr && ((Global *)g_ir[j].ptr)->type == LT_CHAR) b += 3; /* AND #$00FF */
    } else {
        if (g_ir[j].ptr && ((Local  *)g_ir[j].ptr)->type == LT_CHAR) b += 3;
    }
    return b;
}

/* exclude a reload whose backing memory may change behind us, or whose far n,S
 * build clobbers A (no residency possible — same constraint as the Phase-1 fold). */
static int
p3_alias_excluded(int j)
{
    Local *lc;
    if (g_ir[j].op == IR_LOAD_GLOBAL) return 0;        /* no addr_taken concept */
    lc = (Local *)g_ir[j].ptr;
    if (!lc) return 1;
    if (lc->addr_taken || lc->raw_accessed) return 1;
    if (g_ir[j].op == IR_LOAD_LOCAL && slot_needs_far(lc, (int)g_ir[j].u0)) return 1;
    return 0;
}

/* 1 iff op leaves A unchanged.  A store->load / load->load across ONLY such ops
 * is already forwarded by the existing textual peephole (pat_staload_forward),
 * so it is NOT an incremental Phase-3 reload.  Counting only A-clobbered spans
 * makes floor/ceiling measure the reloads BEYOND the shipped compiler — exactly
 * the structural spill/reloads (A clobbered between store and reload) the
 * re-grounding identified as removable only by global register allocation. */
static int
p3_a_preserving(IrOp o)
{
    switch (o) {
    case IR_STORE_LOCAL: case IR_STORE_LOCAL_IMG:
    case IR_STORE_GLOBAL_INT: case IR_STORE_GLOBAL_CHAR:
    case IR_STASH_RHS_INT:                            /* STA _fcc_tmp_b: reads A, keeps it */
    case IR_PUSH_A: case IR_TAX: case IR_TAY:         /* read A, leave it intact */
    case IR_INCDEC_LOCAL_IMG:                         /* INC/DEC dp: A untouched */
    case IR_SEED_MARK: case IR_LOOP_BEGIN: case IR_LOOP_END:
        return 1;
    default: return 0;   /* LOAD_* / BINOP / POP_A / TXA / TYA / deref / IR_TEXT ... clobber A */
    }
}
static int
p3_a_clobbered_between(int sj, int rj)
{
    int j;
    for (j = sj + 1; j < rj; j++)
        if (!p3_a_preserving(g_ir[j].op)) return 1;
    return 0;
}

/* index of the BB containing node j, else -1 (j is itself a barrier). */
static int
p3_bb_of(int j)
{
    int b;
    for (b = 0; b < g_bb_n; b++) if (j >= g_bb[b].lo && j < g_bb[b].hi) return b;
    return -1;
}

/* coverage class of a barrier op (for ranking which barrier to structure). */
static const char *
p3_barrier_class(int j)
{
    switch (g_ir[j].op) {
    case IR_INDEX_DEREF_LOCAL: case IR_INDEX_DEREF_LOCAL_IMG:
        return "index";
    case IR_TEXT:
        if (g_ir[j].text && ir_text_has_unsafe_call(g_ir[j].text)) return "call";
        if (g_ir[j].text && strchr(g_ir[j].text, ':'))             return "label";
        return "text";                                /* branch / other raw asm */
    default:
        return "deref";   /* the deref / ptr-load/store / walk-store barriers */
    }
}

static int
p3_class_idx(const char *cls)   /* call,deref,index,label,text -> 0..4 */
{
    if (!strcmp(cls, "call"))  return 0;
    if (!strcmp(cls, "deref")) return 1;
    if (!strcmp(cls, "index")) return 2;
    if (!strcmp(cls, "label")) return 3;
    return 4;                                          /* text / other */
}

/* First barrier class between producer sj and reload rj (NULL = none, i.e. one
 * clean region), and set *redef if loc is rewritten in (sj,rj).  *bnode gets the
 * blocking barrier's node index (for L5 sandwich dedup), else -1. */
static const char *
p3_barrier_between(int sj, int rj, void *loc, int *redef, int *bnode)
{
    int j;
    const char *cls = NULL;
    *redef = 0; *bnode = -1;
    for (j = sj + 1; j < rj; j++) {
        if (p3_is_redef(j, loc)) *redef = 1;
        if (!ir_node_is_bb_barrier(&g_ir[j])) continue;
        if (cls) continue;                            /* first barrier wins */
        cls = p3_barrier_class(j); *bnode = j;
    }
    return cls;
}

/* peak # of simultaneously-live temps over node span [a,b] within one BB (the
 * floor's register-pressure proxy: a temp is live from first-def to last-use). */
static int defi_buf[IR_MAX_NODES], usei_buf[IR_MAX_NODES];
static unsigned char p3_seen_bnode[IR_MAX_NODES];   /* L5 sandwich dedup (per fn) */
static int
p3_peak_live(int a, int b)
{
    int k, t, peak = 0;
    if (b - a > 512) return 99;                       /* huge BB: assume pressured */
    for (t = 0; t < g_ntemp; t++) { defi_buf[t] = -1; usei_buf[t] = -1; }
    for (k = a; k <= b; k++) {
        int o = g_t_out[k], i0 = g_t_in0[k], i1 = g_t_in1[k];
        if (o  >= 0 && defi_buf[o] < 0) defi_buf[o] = k;
        if (i0 >= 0) usei_buf[i0] = k;
        if (i1 >= 0) usei_buf[i1] = k;
    }
    for (k = a; k <= b; k++) {
        int cur = 0;
        for (t = 0; t < g_ntemp; t++)
            if (defi_buf[t] >= 0 && usei_buf[t] >= 0 && defi_buf[t] <= k && k <= usei_buf[t])
                cur++;
        if (cur > peak) peak = cur;
    }
    return peak;
}

/* L3: 1 iff this STASH at index j sits in a surviving PUSH_A / <leaf load> /
 * STASH_RHS_INT / POP_A / BINOP window whose leaf is a single-instr A-preserving
 * load -> ir_select WOULD have folded it but for a char/far/param GATE, so it is
 * fold-reachable (a coverage lever), not an allocator target.  A genuinely
 * complex RHS puts extra ops between PUSH_A and STASH so this never matches. */
static int
p3_stash_leaf_foldable(int j)
{
    IrOp lo, pu, po;
    if (j < 2 || j + 2 >= g_ir_n) return 0;
    pu = g_ir[j-2].op; po = g_ir[j+1].op;   /* post-ir_allocate: PUSH_A held -> TAX/TAY */
    if (pu != IR_PUSH_A && pu != IR_TAX && pu != IR_TAY) return 0;
    if (po != IR_POP_A  && po != IR_TXA && po != IR_TYA) return 0;
    if (g_ir[j+2].op != IR_BINOP)  return 0;
    lo = g_ir[j-1].op;                 /* the leaf load between PUSH_A and STASH */
    /* IR_LOAD_LIT: a const-immediate RHS is fold-reachable as `<op> #k` (an
     * immediate-operand fold ir_select doesn't do yet) -> a coverage lever too. */
    return lo == IR_LOAD_GLOBAL || lo == IR_LOAD_LOCAL_IMG ||
           lo == IR_LOAD_LOCAL  || lo == IR_LOAD_LIT;
}

static void
ir_p3_stats(void)
{
    int j, l3_leaf = 0, l3_cplx = 0, l4_ovf = 0;
    p3_emit("fn", 1, 0);

    /* L3 (_fcc_tmp_b RHS stash) + L4 (PUSH_A that ir_alloc_bb could not hold in
     * X/Y, so it stayed a real PHA/PLA -> byte-neutral; counted to CONFIRM
     * push/pull is not a size lever). */
    for (j = 0; j < g_ir_n; j++) {
        switch (g_ir[j].op) {
        case IR_STASH_RHS_INT:
            if (p3_stash_leaf_foldable(j)) l3_leaf++; else l3_cplx++;
            break;
        case IR_PUSH_A: l4_ovf++; break;   /* survived ir_alloc_bb: X and Y full */
        default: break;
        }
    }
    p3_emit("L3_leafmiss", l3_leaf, l3_leaf * 2);   /* STA _fcc_tmp_b = DP, 2 B */
    p3_emit("L3_complex",  l3_cplx, l3_cplx * 2);
    p3_emit("L4_ovf",      l4_ovf, 0);              /* PHA == TAX in bytes: 0 B */

    /* L1 (store->reload) + L2 (load->reload): each load scanned back to its
     * nearest same-location producer with no redef between; classify within-BB
     * (allocator-reachable now) vs barrier-blocked (needs coverage), and bracket
     * floor (within-BB + a register provably free) vs ceiling (any no-redef). */
    {
        int rj, l1wbb=0, l2wbb=0, l2xb=0, storedrop=0;
        int xc[5] = {0,0,0,0,0};     /* L1 cross-barrier: call,deref,index,label,text */
        int sand[5] = {0,0,0,0,0};   /* L5: distinct barriers (per class) blocking a reload */
        int floor_n=0, floor_b=0, ceil_n=0, ceil_b=0;
        memset(p3_seen_bnode, 0, (size_t)g_ir_n);
        for (rj = 0; rj < g_ir_n; rj++) {
            void *loc; int sj, redef, bnode, is_store_src, bytes; const char *cls;
            if (!p3_is_load(g_ir[rj].op) || p3_alias_excluded(rj)) continue;
            loc = p3_loc_ptr(rj);
            if (!loc) continue;
            sj = -1;
            for (j = rj - 1; j >= 0; j--)
                if (p3_loc_ptr(j) == loc &&
                    (p3_is_store(g_ir[j].op) || p3_is_load(g_ir[j].op))) { sj = j; break; }
            if (sj < 0) continue;
            if (!p3_a_clobbered_between(sj, rj)) continue;   /* peephole already forwards it */
            cls = p3_barrier_between(sj, rj, loc, &redef, &bnode);
            if (redef) continue;                       /* value changed -> not removable */
            is_store_src = p3_is_store(g_ir[sj].op);
            bytes = p3_reload_bytes(rj);
            ceil_n++; ceil_b += bytes;                 /* CEILING: any no-redef reload */
            if (cls == NULL) {                         /* within one clean region */
                if (is_store_src) l1wbb++; else l2wbb++;
                if (p3_bb_of(sj) >= 0 && p3_bb_of(sj) == p3_bb_of(rj) &&
                    p3_peak_live(sj, rj) <= 3) { floor_n++; floor_b += bytes; }   /* FLOOR */
                if (is_store_src) {                    /* store-drop: rj is the only reader */
                    int k, dead = 1;
                    for (k = rj + 1; k < g_ir_n; k++) {
                        if (p3_loc_ptr(k) == loc && p3_is_load(g_ir[k].op)) { dead = 0; break; }
                        if (p3_is_redef(k, loc)) break;
                    }
                    if (dead) storedrop++;
                }
            } else {                                   /* blocked by a barrier class */
                int ci = p3_class_idx(cls);
                if (is_store_src) xc[ci]++; else l2xb++;
                /* L5: a clean-BB|barrier|clean-BB sandwich with a value live across
                 * -> count the distinct blocking barrier once (coverage opportunity). */
                if (bnode >= 0 && !p3_seen_bnode[bnode]) {
                    p3_seen_bnode[bnode] = 1; sand[ci]++;
                }
            }
        }
        p3_emit("L1_wbb",        l1wbb, 0);
        p3_emit("L1_xbar_call",  xc[0], 0);
        p3_emit("L1_xbar_deref", xc[1], 0);
        p3_emit("L1_xbar_index", xc[2], 0);
        p3_emit("L1_xbar_label", xc[3], 0);
        p3_emit("L1_xbar_text",  xc[4], 0);
        p3_emit("L1_storedrop",  storedrop, storedrop * 2);   /* STA ,S/dp = 2 B */
        p3_emit("L2_wbb",        l2wbb, 0);
        p3_emit("L2_xbar",       l2xb, 0);
        p3_emit("L5_sand_call",  sand[0], 0);
        p3_emit("L5_sand_deref", sand[1], 0);
        p3_emit("L5_sand_index", sand[2], 0);
        p3_emit("L5_sand_label", sand[3], 0);
        p3_emit("L5_sand_text",  sand[4], 0);
        p3_emit("floor",         floor_n, floor_b);
        p3_emit("ceil",          ceil_n,  ceil_b);
    }
}

/* P1.3 allocator entry: per basic block (g_bb, from ir_build_tac), run the
 * SP-aware spill allocator on clean BBs and the PHA/PLA->TAX peephole on the
 * rest.  No-op when g_ir_opt is off (FCC_NO_REGALLOC -> raw v0.14.0 codegen). */
static void
ir_allocate(void)
{
    int b;
    if (!g_ir_opt) return;
    for (b = 0; b < g_bb_n; b++) {
        if (g_bb[b].clean) ir_alloc_bb(g_bb[b].lo, g_bb[b].hi);
        else               ir_opt_pha_pla(g_bb[b].lo, g_bb[b].hi);
    }
}

void
ir_begin_func(void)
{
    if (!g_ir_on) return;
    ir_reset();
    g_recording = 1;
    g_has_indirect_call = 0;
    g_self_recursive = 0;      /* P3-3 3.2b: per-function stack-guard trigger */
    g_n_promoted_params = 0;   /* defensive: never carry seed state across functions */
}

void
ir_end_func(void)
{
    int i;
    if (!g_ir_on) return;
    g_recording = 0;                 /* replay writes straight to g_out */

    if (g_tac_lower < 0) g_tac_lower = getenv("FCC_TAC_LOWER") ? 1 : 0;
    if (g_tac_stats < 0) g_tac_stats = getenv("FCC_TAC_STATS") ? 1 : 0;
    if (g_isel      < 0) g_isel      = getenv("FCC_NO_ISEL")   ? 0 : 1;

    /* P1.3-inc2: promote hot locals to DP-IMG slots BEFORE TAC is built (so the
     * TAC + allocator see the IMG ops).  Only on the real allocator path: never
     * under FCC_NO_REGALLOC (g_ir_opt==0 -> raw v0.14.0) nor the FCC_TAC_LOWER
     * round-trip gate (must stay byte-identical to raw). */
    if (g_ir_opt && !g_tac_lower) ir_promote_locals();

    /* fcc2 isel Phase 1: select explicit-machine-form ops (load-op fold) on the
     * real allocator path only; gated by FCC_NO_ISEL for bisection. */
    if (g_ir_opt && !g_tac_lower && g_isel) ir_select();

    /* Build the TAC when the allocator runs (g_ir_opt) or a TAC path is requested.
     * Under FCC_NO_REGALLOC (g_ir_opt==0) with no TAC flags, skip it entirely so
     * the raw v0.14.0 replay is byte-for-byte unchanged. */
    if (g_tac_lower || g_tac_stats || g_ir_opt) ir_build_tac();

    if (g_tac_lower) {
        /* P1.2 round-trip gate: lower the raw ops via the BB structure (no
         * allocator) -- byte-identical to the FCC_NO_REGALLOC linear replay. */
        tac_lower();
    } else {
        ir_allocate();               /* P1.3 allocator (uses g_bb); no-op if g_ir_opt==0 */
        if (g_p3_stats < 0) g_p3_stats = getenv("FCC_P3_STATS") ? 1 : 0;
        if (g_p3_stats) ir_p3_stats();   /* read-only Phase-3 measurement */
        for (i = 0; i < g_ir_n; i++) {
            if (g_ir[i].op == IR_TEXT) {
                if (g_ir[i].text_len)
                    fwrite(g_ir[i].text, 1, g_ir[i].text_len, g_out);
            } else {
                emit_lower_op(&g_ir[i]);
            }
        }
    }
    ir_reset();
}
