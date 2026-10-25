#include "fcc.h"

/* Deref/indexed/parenthesized fn-ptr calls (`tbl[i].fn(a)`, `conv[i](a)`,
 * `(*tbl[i].fn)(a)`) evaluate their ARGUMENTS after the callee — the index/base
 * is already consumed, so the callee can't be reloaded.  They stash the full
 * 4-byte far callee (offset+bank — it may live in another code bank) below
 * the args, eval+push the args, then reload it. */
/* Reload the stashed callee into an FPR, call through it, then drop the
 * args + the stash while preserving the return value in A.  Mirrors the
 * original inline sequence with the stash width folded in. */
static void
call_stashed_fnptr(int total_arg_bytes, int line, int col)
{
    int stash = 4;                     /* far pointer: offset + bank+pad */
    if (total_arg_bytes + stash - 1 > 255)
        die(line, col, "too many argument bytes for an indirect fn-ptr call");
    /* P3-2.5b: pull the stash into an FPR.  (The old "single-bank leaves
     * the bank half stale" caveat retired with the P3-2.6 mode collapse --
     * far-call + stored-bank is now the only lowering, see main.c's
     * --data-segment note.  This FPR is dropped just below, so it never
     * reaches a truth test either way.) */
    int kc = fpr_alloc();
    ir_emitf("                LDA     %d,S\n", total_arg_bytes + 1);   /* offset (top of stash) */
    ir_emitf("                STA     _fcc_fpr%d\n", kc);
    ir_emitf("                LDA     %d,S\n", total_arg_bytes + 3); /* bank (below offset) */
    ir_emitf("                STA     _fcc_fpr%d+2\n", kc);
    emit_call_indirect(kc);
    fpr_drop(kc);
    ir_record_raw(IR_TAY, 0, 0, NULL);
    ir_emitf("                TSC\n");
    ir_record_raw(IR_ADD_CONST, (unsigned)(total_arg_bytes + stash), 0, NULL);
    ir_emitf("                TCS\n");
    ir_record_raw(IR_TYA, 0, 0, NULL);
    g_s_delta -= (total_arg_bytes + stash);
}

/* ===== P3-2.2: walker FPR discipline =====================================
 * g_fpr_res = the FPR slot holding the LAST walked node's pointer result
 * (-1 when the result is scalar, in A).  Set by every pointer-valued arm,
 * read by the parent immediately after the child walk. */
static int g_fpr_res = -1;

/* Free an expression register AND clear the result marker — arms that
 * consume a child's FPR must never leave g_fpr_res pointing at a freed
 * slot (the parent reads it right after the walk). */
void
fpr_drop(int k)
{
    fpr_free(k);
    g_fpr_res = -1;
}

/* Collapse a pointer result to its offset word in A (the legacy
 * "A = offset" convention for truth tests / int contexts). */
static void
fpr_collapse(void)
{
    if (g_fpr_res >= 0) {
        emit_fpr_to_a(g_fpr_res);
        fpr_drop(g_fpr_res);
        g_fpr_res = -1;
    }
}

/* Is `n` a compile-time INTEGER constant?  Gates the int->pointer cast bank
 * (N_CAST): a constant operand -- NULL `(T*)0`, the `(T*)-1` error sentinel, a
 * `(char*)0xC000` hardware register -- reconstitutes into bank 0 (bank-agnostic,
 * so the sentinel matches across TUs and banks); a RUNTIME integer -- the
 * 2.11BSD blok arena's BLK(Rcheat(ptr)) round-trip -- reconstitutes into the
 * task data bank.  Correctly FALSE for `Rcheat(x)&~BUSY`: its `(int)(x->word)`
 * arm is a deref (default: 0), so the enclosing N_BINOP is not const. */
int
cast_operand_is_const(int n)
{
    switch (g_ast[n].kind) {
    case N_LIT_INT: case N_LIT_CHAR: case N_ENUM_CONST:
        return 1;
    case N_NEG: case N_BNOT: case N_LNOT:
        return cast_operand_is_const(g_ast[n].a);
    case N_BINOP:
        return cast_operand_is_const(g_ast[n].a) &&
               cast_operand_is_const(g_ast[n].b);
    case N_CAST:
        return cast_operand_is_const(g_ast[n].a);
    default:
        return 0;
    }
}


/* The VALUE of a node cast_operand_is_const accepts.  Returns 1 and fills
 * *out, 0 for anything that is not a compile-time integer.  It exists because
 * the predicate above answers "is it constant" and the constant paths in the
 * multiplicative and shift builders need "and what is it" -- a macro like
 * DEVB_PER_FSB reaches them as `(daddr_t)(FS_BLKSIZE / DEV_BLKSIZE)', a cast
 * around a parenthesised expression, which the token-level TOK_INT_LIT test
 * cannot see.  Folding at the AST instead of the tokens needs no speculative
 * parse: the operand has already been built.
 *
 * EVERY STEP TRUNCATES TO THE NODE'S OWN TYPE.  fcc's int is 16 bits and the
 * host's is not, so an unguarded host fold would answer what the COMPILER
 * computes rather than what the TARGET does, and a wrapped intermediate would
 * silently license the wrong inline sequence.  That is the same class as the
 * long-vs-int overflow fsparam.h's own comment warns about, one level down.
 *
 * It also folds the builder's OWN constant-folded kinds, which
 * cast_operand_is_const does not: `FS_BLKSIZE / DEV_BLKSIZE' never reaches the
 * AST as an N_BINOP, because the multiplicative builder has already turned a
 * literal over a literal into N_MUL_INLINE_CONST.  Teaching the predicate the
 * same kinds would widen which casts take bank 0, which is a separate decision
 * with its own callers, so the two deliberately differ here. */
static long
ast_const_trunc(int n, long v)
{
    unsigned long m = (g_ast[n].type == LT_LONG) ? 0xFFFFFFFFuL : 0xFFFFuL;
    unsigned long r = (unsigned long)v & m;
    unsigned long sign = (m >> 1) + 1;
    if (!g_ast[n].is_unsigned && (r & sign))
        return (long)r - (long)(m + 1);
    return (long)r;
}

int
ast_const_int(int n, long *out)
{
    long a, b;

    /* A long long node is never folded: a folded node is materialised as an
     * int or long constant, which has no w2/w3.  64-bit constants are
     * apple/fgx#447 increment 1e. */
    if (IS_QUAD(g_ast[n].type))
        return 0;
    switch (g_ast[n].kind) {
    case N_LIT_INT: case N_LIT_CHAR: case N_ENUM_CONST:
    /* K&R A.7.4.8 p.165: sizeof's "result is an unsigned integral
     * constant", and the node already holds it. */
    case N_SIZEOF:
        *out = ast_const_trunc(n, (long)g_ast[n].val);
        return 1;
    case N_LIT_LONG:
        *out = (long)(((unsigned long)g_ast[n].val_hi << 16)
                      | ((unsigned long)g_ast[n].val & 0xFFFFuL));
        return 1;
    case N_NEG:
        if (!ast_const_int(g_ast[n].a, &a)) return 0;
        *out = ast_const_trunc(n, -a);   return 1;
    case N_BNOT:
        if (!ast_const_int(g_ast[n].a, &a)) return 0;
        *out = ast_const_trunc(n, ~a);   return 1;
    case N_LNOT:
        if (!ast_const_int(g_ast[n].a, &a)) return 0;
        *out = !a;                       return 1;
    case N_CAST:
        /* Only a cast to an integral type wide enough not to narrow.  A
         * `(char)' cast has a truncation rule of its own and no caller here. */
        if (g_ast[n].type != LT_INT && g_ast[n].type != LT_LONG) return 0;
        if (!ast_const_int(g_ast[n].a, &a)) return 0;
        *out = ast_const_trunc(n, a);    return 1;
    case N_BINOP:
        if (!ast_const_int(g_ast[n].a, &a)) return 0;
        if (!ast_const_int(g_ast[n].b, &b)) return 0;
        switch (g_ast[n].op) {
        case TOK_STAR:    *out = ast_const_trunc(n, a * b); return 1;
        case TOK_PLUS:    *out = ast_const_trunc(n, a + b); return 1;
        case TOK_MINUS:   *out = ast_const_trunc(n, a - b); return 1;
        case TOK_AMP:     *out = ast_const_trunc(n, a & b); return 1;
        case TOK_PIPE:    *out = ast_const_trunc(n, a | b); return 1;
        case TOK_CARET:   *out = ast_const_trunc(n, a ^ b); return 1;
        /* K&R A.7.6 p.166: "if the second operand is 0, the result is
         * undefined" -- so decline rather than fold a trap. */
        case TOK_SLASH:   if (b == 0) return 0;
                          *out = ast_const_trunc(n, a / b); return 1;
        case TOK_PERCENT: if (b == 0) return 0;
                          *out = ast_const_trunc(n, a % b); return 1;
        /* A.7.8 p.166: undefined for a negative or too-large right operand. */
        case TOK_LSHIFT:  if (b < 0 || b > 31) return 0;
                          *out = ast_const_trunc(n, a << b); return 1;
        case TOK_RSHIFT:  if (b < 0 || b > 31) return 0;
                          *out = ast_const_trunc(n, a >> b); return 1;
        default: return 0;
        }
    case N_SHIFT_NOP:
        /* x << 0 / x >> 0, already reduced to the identity. */
        return ast_const_int(g_ast[n].a, out);
    case N_SHIFT_INLINE:
        if (!ast_const_int(g_ast[n].a, &a)) return 0;
        b = (long)g_ast[n].val;
        if (b < 0 || b > 31) return 0;
        *out = ast_const_trunc(n, (g_ast[n].op == TOK_LSHIFT) ? (a << b)
                                                              : (a >> b));
        return 1;
    case N_MUL_INLINE_CONST: case N_MUL_CONST_LIBCALL:
        /* `.val' is a 16-bit literal the builder already took off the token
         * stream, so it is never negative. */
        if (!ast_const_int(g_ast[n].a, &a)) return 0;
        b = (long)g_ast[n].val;
        switch (g_ast[n].op) {
        case TOK_STAR:    *out = ast_const_trunc(n, a * b); return 1;
        case TOK_SLASH:   if (b == 0) return 0;
                          *out = ast_const_trunc(n, a / b); return 1;
        case TOK_PERCENT: if (b == 0) return 0;
                          *out = ast_const_trunc(n, a % b); return 1;
        default: return 0;
        }
    default:
        return 0;
    }
}

/* apple/fgx#42: the TYPE of a value after casts are peeled away.
 *
 * A STRUCT VALUE rides the legacy carrier -- A = offset, _fcc_ptr+2 = bank --
 * and its bank is the frame's: bank 0 for a hardware frame, DBR for a soft one
 * or a global.  So it must be BRIDGED into an FPR, never re-banked by the
 * int->pointer rule, which stamps DBR unconditionally (_fcc_bank_for_int).
 *
 * walk_fpr already knew this, but asked `g_ast[n].type == LT_STRUCT` -- and a
 * cast spells the struct-ness away: `(char *)env` is a node of type char*.  So
 * every cast of a struct value to a pointer fell through to the ITP rule and
 * took the DATA bank while the storage sat on the bank-0 stack.
 *
 * That is #42.  tcsh's sh.parse.c alias() has `jmp_buf osetexit` -- an
 * automatic -- and getexit() expands to copy((char *)(osetexit), ...).  The
 * destination reached copy() as DBR:frame_offset, so 12 bytes landed in the
 * malloc heap at whatever block happened to sit at that offset.  With tcsh's
 * shipping data segment that offset was harmless; grow the segment ~6 KB and
 * the heap moves under it, the write lands on a live free-list block, and the
 * next free() walks a cycle forever -- a login that never prints its prompt.
 *
 * setjmp.h documents the stack-local jmp_buf hazard and says fcc fails closed
 * on it; that guard only fires at a setjmp() CALL, and alias() never calls
 * setjmp on osetexit -- it only copies it. */
static LocalType
cast_peel_type(int n)
{
    while (g_ast[n].kind == N_CAST || g_ast[n].kind == N_CAST_FNPTR)
        n = g_ast[n].a;
    return g_ast[n].type;
}

/* Materialize the just-walked value of node `n` into FPR k: bridge a struct
 * value's carrier, apply the int->pointer bank rule to everything else.  Every
 * "the walk left no FPR, home it myself" site must go through here, or the
 * cast-of-a-struct-address class comes straight back. */
void
fpr_from_walked(int k, int n)
{
    if (cast_peel_type(n) == LT_STRUCT)
        emit_fpr_from_carrier_a(k);
    else
        emit_fpr_from_a(k, BANK_OF_RHS(g_ast[n].type,
                                       cast_operand_is_const(n)));
}

/* Walk a child for a plain 16-bit value. */
void
walk_val(int n)
{
    walk_expr(n);
    fpr_collapse();
}

/* Walk a child used as a TRUTH VALUE and leave Z set (Z=1 -> false).
 *
 * A POINTER condition is evaluated through the FPR carrier so the bank byte
 * counts too: `if (p)` has to agree with `p != (T *)0`, which has always
 * compared both halves.  Collapsing to A first would throw the bank away and
 * read a bank:0000 pointer as NULL (issue #6).  ISPTR is a type-word
 * predicate, so function pointers take this path as well.
 *
 * Everything else keeps the legacy A-holds-the-value test. */
/* Can this condition be its own branch?  Only an INT comparison: pointers go
 * through the FPR carrier so the bank byte counts, and long/float have their
 * own comparators.  Returns 1 if it emitted the operands, the compare and the
 * branch. */
static int
fuse_cmp_branch(int n, int label, int want_true)
{
    TokKind op;
    Node *a, *b;
    int uns;
    long zero;

    if (g_ast[n].kind != N_BINOP) return 0;
    op = g_ast[n].op;
    if (op != TOK_LT && op != TOK_GT && op != TOK_LE &&
        op != TOK_GE && op != TOK_EQEQ && op != TOK_NE) return 0;
    a = &g_ast[g_ast[n].a];
    b = &g_ast[g_ast[n].b];
    if (ISPTR(a->type) || ISPTR(b->type)) return 0;
    if (a->type == LT_LONG  || b->type == LT_LONG)  return 0;
    if (a->type == LT_FLOAT || b->type == LT_FLOAT) return 0;
    if (IS_QUAD(a->type) || IS_QUAD(b->type)) return 0;

    /* The usual arithmetic conversions, as emit_scalar_binop applies them. */
    uns = arith_unsigned(a->type, a->is_unsigned, b->type, b->is_unsigned);

    if (ast_const_int(g_ast[n].b, &zero) && zero == 0 &&
        (op == TOK_EQEQ || op == TOK_NE ||
         (!uns && (op == TOK_LT || op == TOK_GE)))) {
        walk_expr(g_ast[n].a);
        emit_cmp_zero_branch(op, label, want_true);
        g_expr_type     = LT_INT;
        g_expr_unsigned = uns;
        return 1;
    }

    /* emit_scalar_binop's int arm, inlined: LHS pushed, RHS stashed to
     * _fcc_tmp_b, LHS popped back into A. */
    walk_expr(g_ast[n].a);
    emit_push_a();
    walk_expr(g_ast[n].b);
    g_expr_type = LT_INT;            /* emit_stash_rhs dispatches on this */
    emit_stash_rhs();
    emit_pop_a();
    emit_cmp_branch(op, uns, label, want_true);
    g_expr_type     = LT_INT;
    g_expr_unsigned = uns;
    return 1;
}

/* Walk a condition and emit the branch to `label` taken when it is TRUE
 * (want_true) or FALSE.
 *
 * A COMPARISON IS ITS OWN BRANCH -- see emit_cmp_branch.  Everything else
 * keeps the Z protocol walk_cond has always had, which is also what `!` needs,
 * because N_LNOT wants the VALUE rather than a branch. */
void
walk_cond_branch(int n, int label, int want_true)
{
    /* K&R A.7.14: "the first operand is evaluated, including all side
     * effects; if it is equal to 0, the value of the expression is 0.
     * Otherwise, the right operand is evaluated" -- and A.7.15 the same for
     * || with "unequal".  In a condition that order is two branches; the 0/1
     * the operator returns as a value is never built. */
    if (g_ast[n].kind == N_LOGIC_AND || g_ast[n].kind == N_LOGIC_OR) {
        int is_and = g_ast[n].kind == N_LOGIC_AND;
        if (is_and != want_true) {        /* either operand decides alone */
            walk_cond_branch(g_ast[n].a, label, want_true);
            walk_cond_branch(g_ast[n].b, label, want_true);
        } else {                          /* the first can only rule out */
            int lab_skip = new_label();
            walk_cond_branch(g_ast[n].a, lab_skip, !want_true);
            walk_cond_branch(g_ast[n].b, label, want_true);
            emit_label(lab_skip);
        }
        g_expr_type = LT_INT;
        return;
    }
    if (g_ast[n].kind == N_LNOT) {
        walk_cond_branch(g_ast[n].a, label, !want_true);
        g_expr_type = LT_INT;
        return;
    }
    if (fuse_cmp_branch(n, label, want_true)) return;
    walk_cond(n);
    emit_bcond(want_true ? IRC_BNE : IRC_BEQ, label, 1);
}

void
walk_cond(int n)
{
    if (ISPTR(g_ast[n].type)) {
        int k = walk_fpr(n);
        emit_fpr_test_zero(k);         /* clobbers A; callers branch at once */
        fpr_drop(k);
        return;
    }
    walk_val(n);
    /* A 32-bit value keeps its HIGH word in _fcc_long_hi, so testing A alone
     * would miss it -- the same defect as the pointer case above, one type
     * over (issue #8).  Dispatch on g_expr_type, which walk_val leaves set;
     * that is how emit_cmp_eq already picks its long/float comparator. */
    if (g_expr_type == LT_LONG || g_expr_type == LT_FLOAT) {
        emit_test_long_zero(g_expr_type == LT_FLOAT);
        return;
    }
    if (g_expr_type == LT_LLONG) {           /* all four words */
        emit_test_llong_zero();
        return;
    }
    if (g_expr_type == LT_DOUBLE) {          /* -0.0 is false: not a bit test */
        emit_test_double_zero();
        return;
    }
    emit_test_a_zero();
}

/* The address of a homed parameter would be its frame copy, not the slot the
 * caller pushed.  params_home leaves every parameter in place when the body
 * takes one's address, by the same test, so this is reached only if the two
 * disagree. */
static void
refuse_homed_addr(int n)
{
    Local *lc = param_addr_node(n);
    if (lc && lc->homed_from >= 0)
        die(g_ast[n].line, g_ast[n].col,
            "internal: the address of a homed parameter");
}

/* Walk a child that must yield a far pointer; materialize an int-valued child
 * as (A, bank per apple/fgx#12).
 *
 * The FIRST #12 attempt converted this wholesale to the data bank and was
 * reverted as too broad -- walk_fpr is every value-to-pointer materialization
 * (1512 sites in tcsh), most of them CARRIAGE (comparison operands, argument
 * passing) rather than conversion.  The SECOND added a separate walk_fpr_conv
 * entry point for the conversion sites, which was never wired to a caller and
 * so did nothing.
 *
 * Gating on cast_operand_is_const(n) makes the split unnecessary, because the
 * carriage cases are exactly the constant ones.  `p == 0` and `f(NULL)` pass a
 * literal 0, take BANK_ZERO, and emit byte-identical code to before; only a
 * genuine runtime integer becoming a pointer changes.  That is also the rule
 * the reference compiler uses -- ccom exempts a CON of value 0 and cancels the
 * conversion for everything else (c01.c:245-247). */
int
walk_fpr(int n)
{
    walk_expr(n);
    if (g_fpr_res < 0) {
        int k = fpr_alloc();
        /* struct VALUES stay legacy carrier-carried (2.2 decision): their
         * address+bank ride A+_fcc_ptr+2 — bridge, don't stamp bank 0 (c11
         * struct-copy dest regression).  #42: peel casts before asking, or
         * `(char *)env` hides it. */
        fpr_from_walked(k, n);
        g_fpr_res = k;
    }
    return g_fpr_res;
}

/* (fpr_out — the carrier bridge for the retired printf staging — was
 * deleted with the N_CALL_PRINTF arm, T5-C C5.) */

/* Bridge a legacy-helper carrier result INTO a fresh FPR. */
int
fpr_in(void)
{
    int k = fpr_alloc();
    emit_fpr_from_carrier(k);
    g_fpr_res = k;
    return k;
}

/* P3-2.4 pointer-return capture: a C-compiled callee homes its pointer
 * return in FPR0, which restore_live is about to overwrite when outer
 * FPRs were spilled — move it above the spill window FIRST.  fpr_alloc
 * lands above the spilled slots (spill_live leaves them allocated), so
 * k == 0 exactly when nothing spilled and the value is already home. */
static void
fpr_capture_ret(int nspill)
{
    int k = fpr_alloc();
    if (k != 0)
        emit_fpr_mov(k, 0);
    emit_fpr_restore_live(nspill);
    g_fpr_res = k;
}

/* Pointer VALUE of a symbol -> FPR, native both homes (P3-2.5a: ptr
 * LOCALS record the FPR-form structured IR op — promotion retargets it
 * to the img pair).  Contract: A = the offset word on return. */
int
fpr_load_sym(Local *lc, Global *gv)
{
    int k;
    if (lc) {
        if (ISPTR(lc->type)) {
            k = fpr_alloc();
            emit_fpr_load_ptr_local(k, lc);   /* sets g_expr_*; A = offset */
            g_fpr_res = k;
        } else {
            emit_load_local(lc);
            k = fpr_in();
        }
    } else if (ISPTR(gv->type) && is_block_static(gv)) {
        /* --libso: a block static pointer's value, loaded through its
         * block address (the walker follows an arrow the same way). */
        k = fpr_alloc();
        emit_fpr_addr_global(k, gv);
        emit_fpr_deref_field(k, gv->type, 0);
        g_expr_type      = gv->type;
        g_expr_struct_id = gv->struct_id;
        g_expr_unsigned  = gv->is_unsigned;
        g_expr_fn_sig    = (gv->type == LT_FN_PTR) ? gv->fn_sig_id : -1;
        g_fpr_res = k;
    } else if (ISPTR(gv->type)) {
        k = fpr_alloc();
        emit_fpr_load_global_ptr(k, gv);
        g_expr_type      = gv->type;
        g_expr_struct_id = gv->struct_id;
        g_expr_unsigned  = gv->is_unsigned;
        g_expr_fn_sig    = (gv->type == LT_FN_PTR) ? gv->fn_sig_id : -1;
        g_fpr_res = k;
    } else {
        emit_load_global(gv);
        k = fpr_in();
    }
    return k;
}

/* &symbol -> FPR (array decay typed as the legacy helpers did). */
int
fpr_addr_sym(Local *lc, Global *gv)
{
    int k;
    if (lc) {
        if (lc->kind == LK_LOCAL) {
            k = fpr_alloc();
            emit_fpr_addr_local_soft(k, lc);
            if (ISARY(lc->type))
                g_expr_type = INCREF(DECREF(lc->type), DERIV_PTR);
            else
                g_expr_type = INCREF(lc->type, DERIV_PTR);
            g_expr_struct_id = lc->struct_id;
            g_fpr_res = k;
        } else {
            emit_addr_of_local(lc);   /* IR_ADDR_PARAM structured; bank 0 */
            k = fpr_in();
        }
    } else {
        k = fpr_alloc();
        emit_fpr_addr_global(k, gv);
        if (ISARY(gv->type))
            g_expr_type = INCREF(DECREF(gv->type), DERIV_PTR);
        else
            g_expr_type = INCREF(gv->type, DERIV_PTR);
        g_expr_struct_id = gv->struct_id;
        g_fpr_res = k;
    }
    return k;
}

/* ------------------------------------------------------------------------
 * RTL-ABI: right-to-left argument marshalling for a VARIADIC callee.
 *
 * A function EXPLICITLY declared with unspecified args (`void msg();`) or `...`
 * has its callee param offsets flipped (param0 at offset 0, shallowest) so a
 * K&R varargs call reads param0 from a fixed slot regardless of arg count.  To
 * match, every call to such a function pushes its args RIGHT-TO-LEFT (param0
 * last).
 *
 * T5-C C5: walk_call_args simply WALKS the arg subtrees in reverse order when
 * rtl->active (the whole-TU AST makes that free).  Every n,S offset — raw
 * IR_TEXT bake or structured-op u0 snapshot — is therefore taken at its TRUE
 * stack depth, retiring the record-and-reverse machinery
 * (ir_reverse_call_args) and its unreachable-by-reversal die()s (long/float
 * param reads, &param, struct-local fields — the abiprobe sb.st_mode find).
 * Only the by-value-struct guard remains: a struct VALUE as a vararg is
 * unproven against va_arg's slot walk, so it still fails loud.
 * ------------------------------------------------------------------------ */
void
rtl_begin(RtlArgs *r, int active, int varargs)
{
    r->active = active;
    r->varargs = varargs;
    r->has_struct = 0;
}

void
rtl_note_struct(RtlArgs *r) { if (r->varargs) r->has_struct = 1; }

/* After the arg loop, before the call is emitted.  Only a by-value struct
 * passed to a genuine varargs/`()` callee is rejected — the uniform R-to-L
 * ordering (active) is otherwise universal and unguarded. */
void
rtl_finish(RtlArgs *r, int line, int col)
{
    if (r->varargs && r->has_struct)
        die(line, col,
            "right-to-left varargs ABI: a by-value struct argument is not "
            "yet supported in a variadic call");
}


/* --- Increment 3a foundation (additive; unreachable until the flip) ------ */

static void emit_scale_index_by(int stride);   /* defined below (mid-ladder) */

Node g_ast[MAX_AST_NODES];
int  g_n_ast = 0;               /* reset per function at the flip */
int  g_ast_peak = 0;            /* T2-0: max g_n_ast across the TU (Part-V memory measurement) */
int  g_ast_kids[MAX_AST_KIDS];
int  g_n_ast_kids = 0;
Field *g_ast_fields[MAX_AST_KIDS];
int    g_n_ast_fields = 0;

int
ast_new(NodeKind kind, int line, int col)
{
    if (g_n_ast >= MAX_AST_NODES)
        die(line, col, "expression AST exceeds node pool");
    Node *n = &g_ast[g_n_ast];
    n->kind = kind; n->line = line; n->col = col;
    n->type = LT_INT; n->struct_id = -1; n->fn_sig = -1; n->is_unsigned = 0;
    n->a = -1; n->b = -1; n->c = -1; n->op = TOK_EOF; n->val = 0; n->val_hi = 0;
    n->val2 = 0; n->val3 = 0;
    n->name = NULL; n->name_len = 0;
    n->sym_lc = NULL; n->sym_gv = NULL; n->sym_f = NULL;
    n->sym_f2 = NULL; n->flags = 0;
    n->kid0 = 0; n->n_kids = 0;
    return g_n_ast++;
}

/* Pure predicate mirror of emit_inline_divmod_pow2's internal decision (the
 * builder must pick the node variant without emitting). */
int
divmod_pow2_inlineable(unsigned k)
{
    if (k == 1) return 1;
    return (k >= 2 && (k & (k - 1)) == 0 && k <= 0x8000u);
}

/* ...and the SIGNED division counterpart.  A signed /2^k cannot be a run of
 * LSR: it needs a sign test, a bias add, and an arithmetic shift, and the
 * 65816 has no arithmetic shift right -- emit_inline_divs_pow2 spells one as
 * CMP #$8000 + ROR, four bytes a step.  So the sequence GROWS with the shift
 * count where the libcall is a fixed three bytes, and k is capped where the
 * two stop being comparable.  4096 is nine steps for the block sizes this
 * tree actually divides by (512, 1024) with room above them. */
static int
divs_pow2_inlineable(unsigned k)
{
    if (k == 1) return 1;
    return (k >= 2 && (k & (k - 1)) == 0 && k <= 4096u);
}

/* Builder for the multiplicative level — the 3a EXEMPLAR pair (build here,
 * emission in walk_expr below).  Decision structure transcribed from
 * parse_mul_expr; sub-expression types come from node->type instead of
 * post-emission g_expr_type. */
static int build_primary_ast(void);
static int build_comma_entry(void);
static int build_assign(void);
static int incdec_stride(LocalType lf, int sid);

static int build_comma(void);
static int peek_chain_dot_bridges(void);
static int peek_arrow_ptrarr_index(int sid);
static void ast_type_scalar_binop(int n, int is_cmp, LocalType lt, int lu,
                                  LocalType rt, int ru);
static void build_call_args(int *kid0, int *n_kids);
static void set_arr_read_type(int n, Local *lc, Global *gv, int cnt, int n_dims);
static int build_struct_elem_access(Local *lc, Global *gv, LocalType atype, int asid, int line, int col);
static int build_dot_access(Local *lc, Global *gv, int cur_sid, int line, int col);
static int build_named_run_postincdec(void);
static void require_mulshift_operand(int n, TokKind op, int line, int col);
static int named_run_incdec_at(void);
static TokKind compound_base_op(TokKind k);
static int build_arrow_access(Local *lc, Global *gv, int cur_sid, int line, int col);

/* Result-type ladder for an N_ARR_READ node (mirror of the emit_air(g)_tail
 * lowering).  `cnt` subscripts consumed of `n_dims` total.  Shared by the
 * indexed-read site (`arr[i]`) and the `*arr` reroute in build_unary. */
static void
set_arr_read_type(int n, Local *lc, Global *gv, int cnt, int n_dims)
{
    if (lc) {
        int is_byte = (lc->type == LT_CHAR_ARRAY ||
                       lc->type == LT_CHAR_PTR  ||
                       lc->type == LT_VOID_PTR);
        if (cnt < n_dims) {
            g_ast[n].type = is_byte ? LT_CHAR_PTR : LT_INT_PTR;
        } else if (lc->type == LT_LONG_ARRAY || lc->type == LT_FLOAT_ARRAY) {
            g_ast[n].type = (lc->type == LT_FLOAT_ARRAY) ? LT_FLOAT : LT_LONG;
        } else if (lc->type == LT_LONG_PTR || lc->type == LT_FLOAT_PTR) {
            g_ast[n].type = (lc->type == LT_FLOAT_PTR) ? LT_FLOAT : LT_LONG;
        } else if (ISPTR(lc->type) && ISPTR(DECREF(lc->type))) {
            g_ast[n].type = DECREF(lc->type);
            g_ast[n].struct_id = lc->struct_id;
        } else if (is_ptr_array(lc->type)) {
            /* Local ptr-element array (char *v[4]): the element
             * is the array's pointer element type — mirrors
             * emit_air_tail's 4-byte far-ptr load (P3-2.6,
             * ptr_typedef).  The walker's ISPTR(node type)
             * fpr_in() then boxes offset+carrier bank. */
            g_ast[n].type = DECREF(lc->type);
            g_ast[n].struct_id = lc->struct_id;
        } else {
            g_ast[n].type = is_byte ? LT_CHAR : LT_INT;
            g_ast[n].is_unsigned = lc->is_unsigned;
        }
        g_ast[n].fn_sig = lc->fn_sig_id;
    } else {
        int is_byte = (gv->type == LT_CHAR_ARRAY);
        if (cnt < n_dims) {
            g_ast[n].type = is_byte ? LT_CHAR_PTR : LT_INT_PTR;
        } else if (gv->type == LT_LONG_ARRAY || gv->type == LT_FLOAT_ARRAY) {
            g_ast[n].type = (gv->type == LT_FLOAT_ARRAY) ? LT_FLOAT : LT_LONG;
        } else if (is_ptr_array(gv->type)) {
            g_ast[n].type = DECREF(gv->type);
        } else if (gv->type == LT_CHAR_PTR || gv->type == LT_INT_PTR ||
                   gv->type == LT_VOID_PTR) {
            g_ast[n].type = (gv->type == LT_CHAR_PTR ||
                             gv->type == LT_VOID_PTR) ? LT_CHAR : LT_INT;
            g_ast[n].is_unsigned = gv->is_unsigned;
        } else if (gv->type == LT_LONG_PTR || gv->type == LT_FLOAT_PTR) {
            /* Global long / float subscript element is a 4-byte scalar; the
             * LOCAL branch above sets this, but the global branch omitted it,
             * so `long *htab; htab[i]` was typed LT_INT and every consumer
             * (binop, compare) sign-extended the low word, dropping the high. */
            g_ast[n].type = (gv->type == LT_FLOAT_PTR) ? LT_FLOAT : LT_LONG;
        } else if (ISPTR(gv->type) && ISPTR(DECREF(gv->type))) {
            g_ast[n].type = DECREF(gv->type);
            g_ast[n].struct_id = (BTYPE(DECREF(gv->type)) == BT_STRUCT)
                               ? gv->struct_id : -1;
        } else {
            g_ast[n].type = is_byte ? LT_CHAR : LT_INT;
            g_ast[n].is_unsigned = gv->is_unsigned;
        }
        g_ast[n].fn_sig = gv->fn_sig_id;
    }
}

/* Compute sizeof's operand size as a compile-time constant.  The cursor is
 * positioned just past the SIZEOF keyword; this consumes the operand tokens.
 * Shared by the runtime expression path (build_unary) and the constant-
 * expression evaluator (array dims, static/global initializers) so both paths
 * accept the same operand forms: (type), (ident[.field][ [i] ]), (*ident),
 * ("str"), *ident, ident[.field][ [i] ], "str". */

/* The subscripts after a member chain in a sizeof operand, g_cur at the first
 * '[' if any: none leaves the member's own size; one is an element -- or, on a
 * RANK-2 member, a ROW, "an array of 5 arrays" by K&R A.8.6.2, which A.7.4.8
 * sizes whole ("the total number of bytes in the array"), and row_stride holds
 * that; a second on a rank-2 member is the element.  Unevaluated, as sizeof's
 * operand is.  Both spellings of the operator come here, parenthesized and
 * bare, so they cannot disagree. */
static int
sizeof_member_subscripts(Field *ff, int sz)
{
    if (g_cur.kind != TOK_LBRACKET)
        return sz;
    sz = (ff->n_dims == 2 && ff->row_stride > 0)
       ? ff->row_stride
       : elem_size_for(ff->type, ff->struct_id);
    next_tok();
    (void)build_comma_entry();
    expect(TOK_RBRACKET, "']'");
    if (ff->n_dims == 2 && g_cur.kind == TOK_LBRACKET) {
        sz = elem_size_for(ff->type, ff->struct_id);
        next_tok();
        (void)build_comma_entry();
        expect(TOK_RBRACKET, "']'");
    }
    return sz;
}

/* Does the parenthesized sizeof operand -- from g_cur to its closing ')' --
 * have an operator at its top level?  If so it is a general expression, and
 * its value is a scalar, a pointer or a struct, never an array: every size the
 * named-operand arms below exist to recover (an array's length, a member's
 * dimensions, a string's bytes) is gone once an operator has been applied.
 * A LEADING `*' is not counted: that is the deref shape the arm below keeps. */
static int
sizeof_paren_has_operator(void)
{
    int i = g_tok_idx - 1, depth = 0;
    int first = 1;

    for (; g_toks[i].kind != TOK_EOF; i++, first = 0) {
        TokKind k = g_toks[i].kind;
        if (k == TOK_LPAREN || k == TOK_LBRACKET) { depth++; continue; }
        if (k == TOK_RPAREN || k == TOK_RBRACKET) {
            if (depth == 0)
                return 0;
            depth--;
            continue;
        }
        if (depth)
            continue;
        switch (k) {
        case TOK_STAR:
            if (first)
                continue;
            return 1;
        case TOK_PLUS: case TOK_MINUS: case TOK_SLASH: case TOK_PERCENT:
        case TOK_LSHIFT: case TOK_RSHIFT: case TOK_LT: case TOK_GT:
        case TOK_LE: case TOK_GE: case TOK_EQEQ: case TOK_NE:
        case TOK_AMP: case TOK_CARET: case TOK_PIPE: case TOK_AMPAMP:
        case TOK_PIPEPIPE: case TOK_QMARK: case TOK_COMMA: case TOK_EQ:
        case TOK_PLUSEQ: case TOK_MINUSEQ: case TOK_STAREQ: case TOK_SLASHEQ:
        case TOK_PERCENTEQ: case TOK_AMPEQ: case TOK_PIPEEQ: case TOK_CARETEQ:
        case TOK_LSHIFTEQ: case TOK_RSHIFTEQ: case TOK_BANG: case TOK_TILDE:
        case TOK_PLUSPLUS: case TOK_MINUSMINUS:
            return 1;
        default:
            continue;
        }
    }
    return 0;
}

static int build_unary(void);
static int build_unary_operand(void);

/* A numeric or character constant: sized by the type its AST node carries
 * (A.2.5.1's ladder for an integer constant, A.2.5.3's suffix for a floating
 * one, and int for a character constant, which K&R 2.3 says "is an
 * integer"). */
static int
sizeof_is_constant_token(void)
{
    return g_cur.kind == TOK_INT_LIT || g_cur.kind == TOK_CHAR_LIT ||
           g_cur.kind == TOK_FLOAT_LIT;
}

/* The bytes an expression's value occupies, from its AST type. */
static int
sizeof_node_size(int e)
{
    LocalType t = g_ast[e].type;

    if (ISPTR(t))
        return 4;
    if (t == LT_STRUCT)
        return (g_structs[g_ast[e].struct_id].total_size + 1) & ~1;
    return type_size_bytes(t, 1);
}

/* sizeof NAME[i]...[j], the cursor on the first '['.  The indices are not
 * evaluated.  A subscript of a multi-dimensional array steps a whole row
 * (K&R A.8.6.2), so k subscripts of an n-dimensional array leave its total
 * bytes over dims[0] * ... * dims[k-1]; otherwise each subscript peels one
 * pointer or array level off the type. */
static int
sizeof_subscripted(Local *lc, Global *gv)
{
    LocalType t    = lc ? lc->type      : gv->type;
    int       sid  = lc ? lc->struct_id : gv->struct_id;
    int       nd   = lc ? lc->n_dims    : gv->n_dims;
    int      *dims = lc ? lc->dims      : gv->dims;
    int       total = lc ? lc->array_bytes : (int)gv->n_bytes;
    int       k = 0, prod = 1;

    while (g_cur.kind == TOK_LBRACKET) {
        next_tok();                         /* consume '[' */
        (void)build_comma_entry();          /* index expr (discarded) */
        expect(TOK_RBRACKET, "']'");
        if (k < nd) prod *= dims[k];
        k++;
    }
    if (ISARY(t) && nd > 1 && k <= nd && prod > 0)
        return total / prod;
    for (int i = 0; i < k; i++) t = DECREF(t);
    if (ISPTR(t))       return 4;
    if (t == LT_STRUCT) return (g_structs[sid].total_size + 1) & ~1;
    return type_size_bytes(t, 1);
}

static int
sizeof_operand_size(void)
{
    int sz = 0;
    if (g_cur.kind == TOK_LPAREN) {
            next_tok();
            int is_type = cur_begins_type();
            if (!is_type && (sizeof_paren_has_operator() ||
                             sizeof_is_constant_token())) {
                /* K&R A.7.4.8: "The operand is either an expression, which
                 * is not evaluated, or a parenthesized type name."  The
                 * expression is built -- for its type -- and never walked,
                 * so nothing is emitted for it. */
                sz = sizeof_node_size(build_comma_entry());
            } else if (is_type) {
                sz = (int)sizeof_type_value();
            } else if (g_cur.kind == TOK_IDENT) {
                const char *id_ptr = g_cur.id_ptr;
                int id_len = g_cur.id_len;
                Local  *lc = locals_lookup(id_ptr, id_len);
                Global *gv = (lc == NULL) ? globals_lookup(id_ptr, id_len) : NULL;
                if (lc == NULL && gv == NULL)
                    die(g_cur.line, g_cur.col, "sizeof: undeclared identifier");
                if (lc != NULL) {
                    if (lc->type == LT_STRUCT)
                        sz = (g_structs[lc->struct_id].total_size + 1) & ~1;
                    else if (ISARY(lc->type) && lc->array_bytes > 0)
                        sz = lc->array_bytes;   /* A.7.4.8: the whole array */
                    else
                        sz = type_size_bytes(lc->type, 1);
                } else {
                    sz = gv->n_bytes;
                }
                next_tok();
                /* sizeof(arr[i]) -> ONE element size (the array-count idiom
                 * `sizeof(a) / sizeof(a[0])`, tcsh's `sizeof(errorlist) /
                 * sizeof(errorlist[0])`).  Mirrors the unparenthesized
                 * `sizeof arr[i]` arm below; the index is unevaluated. */
                if (g_cur.kind == TOK_LBRACKET)
                    sz = sizeof_subscripted(lc, gv);
                /* sizeof(var.field[.field]...) — walk the member chain and
                 * take the FINAL field's byte_size (tar: sizeof chksum[8]).
                 * Overrides the base sz computed above. */
                if (g_cur.kind == TOK_DOT || g_cur.kind == TOK_ARROW) {
                    int cur_sid = lc ? lc->struct_id : gv->struct_id;
                    Field *ff = NULL;
                    while (g_cur.kind == TOK_DOT || g_cur.kind == TOK_ARROW) {
                        /* Which operator got us here decides whether the K&R
                         * global pun applies: it does on '->', not on '.'
                         * (apple/fgx#85, see field_lookup_dot). */
                        int via_dot = (g_cur.kind == TOK_DOT);
                        next_tok();
                        if (g_cur.kind != TOK_IDENT)
                            die(g_cur.line, g_cur.col,
                                "sizeof: expected field name after '.'");
                        if (cur_sid < 0)
                            die(g_cur.line, g_cur.col,
                                "sizeof: '.' on a non-struct operand");
                        ff = via_dot
                           ? field_lookup_dot(cur_sid, g_cur.id_ptr,
                                              g_cur.id_len)
                           : struct_field_lookup(cur_sid, g_cur.id_ptr,
                                                 g_cur.id_len);
                        if (ff == NULL)
                            die(g_cur.line, g_cur.col, "sizeof: no such field");
                        cur_sid = ff->struct_id;
                        next_tok();
                    }
                    sz = sizeof_member_subscripts(ff, ff->byte_size);
                }
            } else if (g_cur.kind == TOK_STAR) {
                /* Parenthesized deref: sizeof(*ptr), sizeof(**ptr).  Same
                 * type-of-deref logic as the unparenthesized `sizeof *ptr`
                 * arm below. */
                int derefs = 0;
                while (g_cur.kind == TOK_STAR) { derefs++; next_tok(); }
                if (g_cur.kind != TOK_IDENT)
                    die(g_cur.line, g_cur.col, "sizeof '*': expected identifier");
                Local  *plc = locals_lookup(g_cur.id_ptr, g_cur.id_len);
                Global *pgv = (plc == NULL) ? globals_lookup(g_cur.id_ptr, g_cur.id_len) : NULL;
                if (plc == NULL && pgv == NULL)
                    die(g_cur.line, g_cur.col, "sizeof: undeclared identifier");
                LocalType pty = plc ? plc->type : pgv->type;
                int       psid = plc ? plc->struct_id : pgv->struct_id;
                for (int d = 0; d < derefs; d++) pty = DECREF(pty);
                next_tok();
                if (pty == LT_STRUCT)
                    sz = (g_structs[psid].total_size + 1) & ~1;
                else if (ISPTR(pty))
                    sz = 4;
                else
                    sz = type_size_bytes(pty, 1);
            } else if (g_cur.kind == TOK_STR_LIT) {
                /* sizeof("literal") — string length + NUL (telnet's
                 * HELPINDENT = sizeof("connect")). */
                sz = g_cur.str_len + 1;
                next_tok();
            } else if (g_cur.kind == TOK_LPAREN) {
                /* sizeof( (struct TAG *) <expr> ->field[ ->field | .field ]* )
                 * — "size of a struct member without an instance" (tcsh tc.who
                 * `sizeof(((struct utmp *) 0)->ut_name)`).  Parse the cast to
                 * learn the pointee struct, skip its (unevaluated) operand up to
                 * the '->', then walk the member chain to the final field's
                 * byte_size.  Compile-time only. */
                /* skip leading grouping/cast parens (tracking depth): the cast
                 * type is the first struct/union kw just inside them. */
                int cd2 = 0;
                while (g_cur.kind == TOK_LPAREN) { cd2++; next_tok(); }
                if (g_cur.kind != TOK_STRUCT_KW && g_cur.kind != TOK_UNION_KW)
                    die(g_cur.line, g_cur.col,
                        "sizeof(expr): only a (struct TAG *) member cast is supported");
                next_tok();                       /* struct/union */
                if (g_cur.kind != TOK_IDENT)
                    die(g_cur.line, g_cur.col, "sizeof: expected struct/union tag");
                int msid = structs_lookup(g_cur.id_ptr, g_cur.id_len);
                if (msid < 0)
                    die(g_cur.line, g_cur.col, "sizeof: unknown struct/union in cast");
                next_tok();                       /* tag */
                if (g_cur.kind != TOK_STAR)
                    die(g_cur.line, g_cur.col, "sizeof(expr): cast must be to a struct pointer");
                while (g_cur.kind == TOK_STAR) next_tok();
                expect(TOK_RPAREN, "')' after cast type");
                cd2--;                            /* the cast paren just closed */
                /* skip the unevaluated cast operand + remaining grouping parens
                 * until the top-level '->'/'.' member access. */
                while (!(cd2 == 0 &&
                         (g_cur.kind == TOK_ARROW || g_cur.kind == TOK_DOT))) {
                    if (g_cur.kind == TOK_LPAREN) cd2++;
                    else if (g_cur.kind == TOK_RPAREN) {
                        if (cd2 == 0)
                            die(g_cur.line, g_cur.col,
                                "sizeof(expr): expected '->field' after the cast");
                        cd2--;
                    } else if (g_cur.kind == TOK_EOF)
                        die(g_cur.line, g_cur.col, "sizeof(expr): unterminated");
                    next_tok();
                }
                int cur_sid = msid;
                Field *mf = NULL;
                while (g_cur.kind == TOK_ARROW || g_cur.kind == TOK_DOT) {
                    int via_dot = (g_cur.kind == TOK_DOT);   /* see #85 above */
                    next_tok();
                    if (g_cur.kind != TOK_IDENT)
                        die(g_cur.line, g_cur.col, "sizeof: expected field name");
                    if (cur_sid < 0)
                        die(g_cur.line, g_cur.col, "sizeof: member of a non-struct");
                    mf = via_dot
                       ? field_lookup_dot(cur_sid, g_cur.id_ptr, g_cur.id_len)
                       : struct_field_lookup(cur_sid, g_cur.id_ptr, g_cur.id_len);
                    if (mf == NULL)
                        die(g_cur.line, g_cur.col, "sizeof: no such field");
                    cur_sid = mf->struct_id;
                    next_tok();
                }
                sz = mf->byte_size;
            } else {
                die(g_cur.line, g_cur.col,
                    "sizeof(expr) not supported — use sizeof IDENT or sizeof(type)");
            }
            expect(TOK_RPAREN, "')'");
        } else if (g_cur.kind == TOK_STAR) {
            int derefs = 0;
            while (g_cur.kind == TOK_STAR) { derefs++; next_tok(); }
            if (g_cur.kind != TOK_IDENT)
                die(g_cur.line, g_cur.col, "sizeof '*': expected identifier");
            Local  *slc = locals_lookup(g_cur.id_ptr, g_cur.id_len);
            Global *sgv = (slc == NULL) ? globals_lookup(g_cur.id_ptr, g_cur.id_len) : NULL;
            if (slc == NULL && sgv == NULL)
                die(g_cur.line, g_cur.col, "sizeof: undeclared identifier");
            LocalType sty = slc ? slc->type : sgv->type;
            int       ssid = slc ? slc->struct_id : sgv->struct_id;
            for (int d = 0; d < derefs; d++) sty = DECREF(sty);
            next_tok();
            if (sty == LT_STRUCT)
                sz = (g_structs[ssid].total_size + 1) & ~1;
            else if (ISPTR(sty))
                sz = 4;
            else
                sz = type_size_bytes(sty, 1);
        } else if (g_cur.kind == TOK_IDENT) {
            const char *id_ptr = g_cur.id_ptr;
            int id_len = g_cur.id_len;
            Local  *lc = locals_lookup(id_ptr, id_len);
            Global *gv = (lc == NULL) ? globals_lookup(id_ptr, id_len) : NULL;
            if (lc == NULL && gv == NULL)
                die(g_cur.line, g_cur.col, "sizeof: undeclared identifier");
            if (lc != NULL) {
                if (lc->type == LT_STRUCT) {
                    sz = (g_structs[lc->struct_id].total_size + 1) & ~1;
                } else if (ISARY(lc->type) && lc->array_bytes > 0) {
                    sz = lc->array_bytes;   /* A.7.4.8: the whole array */
                } else {
                    sz = type_size_bytes(lc->type, 1);
                }
            } else {
                sz = gv->n_bytes;
            }
            next_tok();
            /* sizeof arr[i] -> ONE element size (the array-count idiom
             * `sizeof a / sizeof a[0]`, telnet's telopts).  The index is
             * unevaluated (sizeof doesn't execute its operand). */
            if (g_cur.kind == TOK_LBRACKET)
                sz = sizeof_subscripted(lc, gv);
            /* sizeof var.field[.field]... -- THE SAME WALK THE PARENTHESIZED ARM
             * ABOVE ALREADY DOES, which is the whole of apple/fgx#477's second
             * half: this arm accepted the base and `arr[i]' and stopped, so
             * `sizeof sun.sun_path' (syslogd) died "expected ')'" while
             * `sizeof(sun.sun_path)' compiled.  K&R 2nd ed A.7.4.8 gives the
             * operator two forms and puts no such distinction between them --
             * "The operand is either an expression, which is not evaluated, or
             * a parenthesized type name" -- and A.7.3's postfix grammar makes
             * `sun.sun_path' and `f->m.n' expressions, so both spellings must
             * take them.  Overrides the base sz computed above. */
            if (g_cur.kind == TOK_DOT || g_cur.kind == TOK_ARROW) {
                int cur_sid = lc ? lc->struct_id : gv->struct_id;
                Field *ff = NULL;
                while (g_cur.kind == TOK_DOT || g_cur.kind == TOK_ARROW) {
                    int via_dot = (g_cur.kind == TOK_DOT);  /* #85: pun on '->' */
                    next_tok();
                    if (g_cur.kind != TOK_IDENT)
                        die(g_cur.line, g_cur.col,
                            "sizeof: expected field name after '.'");
                    if (cur_sid < 0)
                        die(g_cur.line, g_cur.col,
                            "sizeof: '.' on a non-struct operand");
                    ff = via_dot
                       ? field_lookup_dot(cur_sid, g_cur.id_ptr, g_cur.id_len)
                       : struct_field_lookup(cur_sid, g_cur.id_ptr, g_cur.id_len);
                    if (ff == NULL)
                        die(g_cur.line, g_cur.col, "sizeof: no such field");
                    cur_sid = ff->struct_id;
                    next_tok();
                }
                sz = ff->byte_size;
                /* ... and a subscript AFTER the chain is one element of it:
                 * `sizeof f->f_un.f_forw.f_addr' needs no index, but
                 * `sizeof p->row[0]' is the same array-count idiom as above.
                 * On a RANK-2 member one subscript is a ROW, "an array of 5
                 * arrays" by A.8.6.2, and A.7.4.8 sizes an array whole: the
                 * row's bytes, which row_stride holds.  A second subscript is
                 * the element. */
                sz = sizeof_member_subscripts(ff, sz);
            }
        } else if (g_cur.kind == TOK_STR_LIT) {
            sz = g_cur.str_len + 1;
            next_tok();
    } else if (sizeof_is_constant_token()) {
        /* A constant is a unary-expression (A.7.1 primary), so
         * `sizeof 5000000000' needs no parentheses: its type's size. */
        sz = sizeof_node_size(build_unary());
    } else {
        die(g_cur.line, g_cur.col,
            "sizeof: expected '(', identifier, or string literal");
    }
    return sz;
}

/* Peek (token-vector scan, no consume): does the `&IDENT<suffix run>' starting
 * at the current token need the uniform lvalue walker?  Called with g_cur at
 * the run's first `.' or `->', from both address-of arms.
 *
 * This is the COMPLEMENT of what the fixed-shape arms below already cover, and
 * that set is ad-hoc rather than principled -- so it was MEASURED, one compile
 * per shape, not reasoned about.  Writing a run as its hop kinds (A = `->f',
 * D = `.f', I = one `[...]' run), the arms accepted exactly:
 *
 *      arrow base   A    AI    AAI    AADI          (and AII, the `p->y[a][b]'
 *      dot base     D    DI    DD     DDD    DDI     double-subscript arm)
 *
 * and rejected every other shape.  Note ADI (`&p->M.arr[i]') rejects while
 * AADI (`&h->tp->M.arr[i]') is fine: the arrow-chain loop handles dots mid-run,
 * but the bare-field arm intercepts the single-arrow case first and returns
 * with the `.' unread.  That inconsistency is the defect, and it is why the
 * table below is a table and not a rule.
 *
 * The three families it says yes to, all of which die or drop tokens today:
 *   - a hop AFTER a subscript (AID = &p->MA[i].z, DID = &v.MA[i].z);
 *   - an arrow reached from a dot base (DA = &v.MP->z);
 *   - an arrow base that is neither a lone hop nor a covered chain (AA =
 *     &h->tp->w, AD = &p->M.z -- the reported shape -- AAD, ADI).
 *
 * apple/fgx#212.  Keeping this narrow is the point: the covered arms have their
 * own emitters, and diverting even one of them moves its golden -- AADI was
 * diverted by a first cut of this scan and arrowdotchain caught it. */
static int
addr_run_needs_walker(void)
{
    int i = g_tok_idx - 1;                    /* at the run's first '.'/'->' */
    TokKind first = g_toks[i].kind;
    int n_arrow = 0, n_dot = 0, has_index = 0;
    for (;;) {
        TokKind k = g_toks[i].kind;
        if (k == TOK_DOT || k == TOK_ARROW) {
            if (g_toks[i + 1].kind != TOK_IDENT) return 0;   /* not this shape */
            if (has_index) return 1;          /* a hop after a subscript */
            if (k == TOK_ARROW) n_arrow++; else n_dot++;
            i += 2; continue;
        }
        if (k == TOK_LBRACKET) {
            int d = 1; i++;
            while (d && g_toks[i].kind != TOK_EOF) {
                if (g_toks[i].kind == TOK_LBRACKET) d++;
                else if (g_toks[i].kind == TOK_RBRACKET) d--;
                i++;
            }
            has_index = 1; continue;
        }
        break;
    }
    if (first == TOK_DOT) return (n_arrow > 0);          /* D... A  */
    if (has_index)        return (n_dot > 0 && n_arrow < 2);  /* ADI, not AADI */
    return (n_arrow != 1 || n_dot != 0);                 /* only bare A is covered */
}

/* Transcribed decision structure of parse_unary (3a-D).  Result-descriptor
 * annotations mirror what the historical emission left in g_expr_*; arms that
 * historically left a field as a LEFTOVER get the nearest principled value —
 * the golden gate at the flip arbitrates any consequential divergence. */
static int
build_unary(void)
{
    if (g_cur.kind == TOK_SIZEOF_KW) {
        int op_line = g_cur.line, op_col = g_cur.col;
        next_tok();
        int sz = sizeof_operand_size();
        int n = ast_new(N_SIZEOF, op_line, op_col);
        g_ast[n].val = (unsigned)sz;
        g_ast[n].type = LT_INT;
        return n;
    }
    if (g_cur.kind == TOK_PLUSPLUS || g_cur.kind == TOK_MINUSMINUS) {
        int is_inc = (g_cur.kind == TOK_PLUSPLUS);
        int op_line = g_cur.line, op_col = g_cur.col;
        next_tok();
        /* --libso: `++s' / `--s[i]' on a block static bumps it through the
         * lvalue walker (K&R A.7.4.1: the value is the new one). */
        if (g_cur.kind == TOK_IDENT) {
            Global *bgv = block_static_named(g_cur.id_ptr, g_cur.id_len);
            if (bgv) {
                int line = g_cur.line, col = g_cur.col;
                next_tok();
                int head = ast_new(N_LV_CHAIN, line, col);
                g_ast[head].c = -1;
                g_ast[head].sym_lc = NULL; g_ast[head].sym_gv = bgv;
                build_lvalue_suffixes(head, bgv->type, bgv->struct_id);
                LocalType lf = g_ast[head].type;
                require_assignable(lf, is_inc ? TOK_PLUSPLUS : TOK_MINUSMINUS);
                int nn = ast_new(N_LV_INCDEC_E, op_line, op_col);
                g_ast[nn].a     = head;
                g_ast[nn].val   = (unsigned)incdec_stride(lf, g_ast[head].struct_id);
                g_ast[nn].flags = is_inc ? AF_IS_INC : 0;
                g_ast[nn].type  = lf;
                g_ast[nn].struct_id = g_ast[head].struct_id;
                g_ast[nn].is_unsigned = g_ast[head].is_unsigned;
                return nn;
            }
        }
        /* `++(base)->m` / `--(base)[i]` -- a PARENTHESIZED base with a postfix
         * member/index chain AFTER the close paren.  The pfx_paren loop below
         * consumes a leading '(' as pure grouping around a bare-IDENT lvalue,
         * which mis-parses this: the paren wraps only the base and the '->'
         * follows the ')', so every arm below (which keys on `IDENT ->`) misses
         * and the parse died "expected ';'".  Route the whole operand through
         * g_preincdec_chain -- build_unary parses the postfix chain and
         * build_postfix_value_chain closes it as a bump -- exactly as
         * `++f(args)->m` already does.  joe screen.h's `outatr' uses `++(t)->x'.
         * Only fires when a chain operator actually follows the balanced parens,
         * so `++(x)`, `++(*p)` and plain `++(lvalue)` keep their existing arms. */
        if (g_cur.kind == TOK_LPAREN) {
            int i = g_tok_idx - 1;               /* g_cur == g_toks[g_tok_idx-1] */
            int d = 0;
            for (; g_toks[i].kind != TOK_EOF; i++) {
                if (g_toks[i].kind == TOK_LPAREN) d++;
                else if (g_toks[i].kind == TOK_RPAREN && --d == 0) { i++; break; }
            }
            TokKind after = g_toks[i].kind;
            if (after == TOK_ARROW || after == TOK_DOT || after == TOK_LBRACKET) {
                int saved = g_preincdec_chain;
                g_preincdec_chain = is_inc ? 1 : -1;
                int v = build_unary();           /* (base)->m chain -> bump */
                g_preincdec_chain = saved;
                return v;
            }
        }
        int pfx_paren = 0;
        while (g_cur.kind == TOK_LPAREN) { pfx_paren++; next_tok(); }
        if (g_cur.kind == TOK_STAR) {
            /* Prefix ++/-- on a single deref lvalue: `++(*p)` / `++*p`
             * (K&R getopt-style flag walking: `while (*++(*argv))`).
             * Desugar to `*p = *p ± 1` on the proven N_DSTORE path so the
             * pointer-stride and the multibank far-store are reused, not
             * re-derived.  Restricted to a simple `*IDENT` target — exactly
             * what N_DSTORE accepts; anything deeper (e.g. `++(**p)`) rewinds
             * and falls through to the identifier arm's die() below. */
            LexPeek star_pk;
            lex_peek_save(&star_pk);
            next_tok();                                /* consume '*' */
            if (g_cur.kind == TOK_IDENT) {
                Local  *dlc = locals_lookup(g_cur.id_ptr, g_cur.id_len);
                Global *dgv = (dlc == NULL) ? globals_lookup(g_cur.id_ptr, g_cur.id_len) : NULL;
                LocalType pt = dlc ? dlc->type : (dgv ? dgv->type : LT_INT);
                if ((dlc != NULL || dgv != NULL) && ISPTR(pt)) {
                    LocalType tgt = DECREF(pt);
                    int tgt_sid = dlc ? dlc->struct_id : dgv->struct_id;
                    int is_byte = (BTYPE(tgt) == BT_CHAR || BTYPE(tgt) == BT_VOID);
                    int is_ptr  = ISPTR(tgt);
                    /* re-parse `*ident` as the rhs deref-load (uniform over
                     * local/global + result type). */
                    lex_peek_restore(&star_pk);
                    int dref = build_unary();
                    while (pfx_paren-- > 0) expect(TOK_RPAREN, "')'");
                    int lit = ast_new(N_LIT_INT, op_line, op_col);
                    g_ast[lit].val = 1; g_ast[lit].type = LT_INT;
                    int lstride = (tgt == LT_LONG || tgt == LT_FLOAT)
                                ? 0 : elem_size_for(tgt, tgt_sid);
                    int add;
                    if (lstride > 0) {
                        /* pointer ± int: mirror build_add_expr's stride node. */
                        add = ast_new(is_inc ? N_ADD_PPLUSI : N_SUB_PTR_INT,
                                      op_line, op_col);
                        g_ast[add].a = dref; g_ast[add].b = lit;
                        g_ast[add].val = (unsigned)lstride;
                        g_ast[add].type = tgt; g_ast[add].struct_id = tgt_sid;
                        g_ast[add].is_unsigned = g_ast[dref].is_unsigned;
                    } else {
                        add = ast_new(N_BINOP, op_line, op_col);
                        g_ast[add].a = dref; g_ast[add].b = lit;
                        g_ast[add].op = is_inc ? TOK_PLUS : TOK_MINUS;
                        ast_type_scalar_binop(add, 0, tgt, g_ast[dref].is_unsigned,
                                              LT_INT, 0);
                    }
                    int n = ast_new(N_DSTORE, op_line, op_col);
                    g_ast[n].sym_lc = dlc; g_ast[n].sym_gv = dgv;
                    g_ast[n].op = TOK_EQ;   /* plain store: the ± is in `add` */
                    g_ast[n].a = add;
                    g_ast[n].val = 1; g_ast[n].val_hi = 1;   /* no ptr pre/post-inc */
                    g_ast[n].flags = (is_byte ? AF_IS_BYTE : 0) |
                                     (is_ptr ? AF_IS_PTRSTORE : 0);
                    g_ast[n].type = is_ptr ? tgt : (is_byte ? LT_CHAR : LT_INT);
                    return n;
                }
            }
            lex_peek_restore(&star_pk);            /* not *IDENT-ptr: general arm */
            /* `++(*(computed))` / `--(*(computed))` -- prefix RMW through a
             * COMPUTED pointer, yielding the NEW value (frotz z_dec_chk's
             * `value = --(*(fp - zargs[0]))`).  Model `*(p)` as `p[0]` on
             * the uniform lvalue walker: N_LV_CHAIN with the computed base
             * + one synthetic zero-index step -- the same array-form
             * retype as build_postfix_value_chain's computed-base incdec
             * arm, and no AF_RET_OLD because prefix returns the new value
             * (K&R A.7.4.1). */
            next_tok();                            /* consume '*' */
            {
                int pbase = build_unary();         /* the pointer expression */
                if (!ISPTR(g_ast[pbase].type) || g_ast[pbase].type == LT_FN_PTR)
                    die(op_line, op_col,
                        "expected identifier after '++' / '--'");
                while (pfx_paren-- > 0) expect(TOK_RPAREN, "')'");
                LocalType aty = INCREF(DECREF(g_ast[pbase].type), DERIV_ARY);
                LocalType ety = DECREF(aty);
                int esid = (BTYPE(ety) == BT_STRUCT)
                         ? g_ast[pbase].struct_id : -1;
                int es = elem_size_for(aty, g_ast[pbase].struct_id);
                if (es == 0) es = 1;
                int lit0 = ast_new(N_LIT_INT, op_line, op_col);
                g_ast[lit0].val = 0; g_ast[lit0].type = LT_INT;
                int step = ast_new(N_LV_STEP_INDEX, op_line, op_col);
                g_ast[step].b = lit0; g_ast[step].val = (unsigned)es;
                g_ast[step].flags = 0;             /* array-form base: no deref */
                g_ast[step].type = ety; g_ast[step].a = -1;
                int head = ast_new(N_LV_CHAIN, op_line, op_col);
                g_ast[head].c = pbase;             /* computed pointer base */
                g_ast[head].sym_lc = NULL; g_ast[head].sym_gv = NULL;
                g_ast[head].b = step;
                g_ast[head].type = ety;
                g_ast[head].struct_id = esid;
                g_ast[head].is_unsigned = g_ast[pbase].is_unsigned;
                require_assignable(ety, TOK_PLUSPLUS);
                int st2 = incdec_stride(ety, esid);
                int nn = ast_new(N_LV_INCDEC_E, op_line, op_col);
                g_ast[nn].a         = head;
                g_ast[nn].val       = (unsigned)st2;
                g_ast[nn].flags     = (is_inc ? AF_IS_INC : 0);
                g_ast[nn].type      = ety;
                g_ast[nn].struct_id = esid;
                return nn;
            }
        }
        if (g_cur.kind != TOK_IDENT)
            die(op_line, op_col, "expected identifier after '++' / '--'");
        /* `++f(args)->m` -- a CALL as the base of the chain being bumped, not
         * the increment of a function.  Distinguished by the '(', exactly as
         * `&f(args)->m` is, and handled the same way: a one-shot flag tells
         * build_postfix_value_chain to close the chain as a bump rather than a
         * read.  K&R A.7.4.1 takes ++/-- on ANY modifiable lvalue and A.7.3.3
         * makes the '->' result an lvalue however the base was computed, so
         * the postfix twin below has no claim the prefix one lacks.  Prefix
         * yields the NEW value, hence no AF_RET_OLD at the build site. */
        if (funcs_lookup(g_cur.id_ptr, g_cur.id_len) >= 0) {
            LexPeek cpk;
            lex_peek_save(&cpk);
            next_tok();                          /* past the function name */
            if (g_cur.kind == TOK_LPAREN) {
                lex_peek_restore(&cpk);          /* back to the name */
                int saved_pic = g_preincdec_chain;
                g_preincdec_chain = is_inc ? 1 : -1;
                int v = build_unary();           /* call + chain -> bump */
                g_preincdec_chain = saved_pic;
                if (g_ast[v].kind != N_LV_INCDEC_E)
                    die(op_line, op_col,
                        "prefix '++'/'--' on a call result requires a "
                        "'->'/'.'/'[' member chain");
                while (pfx_paren-- > 0) expect(TOK_RPAREN, "')'");
                return v;
            }
            lex_peek_restore(&cpk);
        }
        {
            Local  *plc = locals_lookup(g_cur.id_ptr, g_cur.id_len);
            Global *pgv = plc ? NULL : globals_lookup(g_cur.id_ptr, g_cur.id_len);
            if ((plc && plc->type == LT_STRUCT_PTR) ||
                (pgv && pgv->type == LT_STRUCT_PTR)) {
                LexPeek pk_lp;
                lex_peek_save(&pk_lp);
                next_tok();                       /* peek past IDENT */
                if (g_cur.kind == TOK_ARROW) {
                    int sid = plc ? plc->struct_id : pgv->struct_id;
                    next_tok();                   /* consume '->' */
                    if (g_cur.kind != TOK_IDENT)
                        die(g_cur.line, g_cur.col,
                            "expected field name after '->'");
                    Field *f = struct_field_lookup(sid, g_cur.id_ptr,
                                                   g_cur.id_len);
                    if (f == NULL)
                        die(g_cur.line, g_cur.col, "no such field");
                    /* ONE hop only: `--p->s[i]' bumps the ELEMENT, not the
                     * pointer member `s', so a run that continues past the
                     * member is the walker's (below), whatever its type. */
                    TokKind after_f = peek_tok().kind;
                    if ((f->type == LT_INT || f->type == LT_LONG ||
                         f->type == LT_FLOAT ||
                         f->type == LT_CHAR ||       /* apple/fgx#215 */
                         f->type == LT_CHAR_PTR ||
                         f->type == LT_INT_PTR || f->type == LT_VOID_PTR ||
                         f->type == LT_LONG_PTR) &&
                        after_f != TOK_LBRACKET && after_f != TOK_DOT &&
                        after_f != TOK_ARROW) {
                        next_tok();               /* consume field name */
                        int n = ast_new(N_PREINC_MEMBER, op_line, op_col);
                        g_ast[n].sym_lc = plc; g_ast[n].sym_gv = pgv;
                        g_ast[n].sym_f = f; g_ast[n].val = (unsigned)is_inc;
                        g_ast[n].type = f->type;
                        g_ast[n].struct_id = f->struct_id;
                        g_ast[n].struct_id = f->struct_id;
                        while (pfx_paren-- > 0) expect(TOK_RPAREN, "')'");
                        return n;
                    }
                    /* The chain CONTINUES past this member (`--pp->p_cwd->
                     * di_count`, tcsh sh.proc): the arm above handles exactly
                     * ONE hop to a scalar/pointer leaf, so a member that is
                     * itself a struct pointer landed here.  K&R A.7.4.1 takes
                     * ++/-- on ANY modifiable lvalue, and N_LV_INCDEC_E already
                     * has a chain mode -- so route the whole run through the
                     * uniform walker.  Prefix yields the NEW value, hence no
                     * AF_RET_OLD.  Gated on the chain really continuing so any
                     * OTHER unsupported leaf type still fails closed here
                     * rather than quietly taking a different path. */
                    {
                        LexPeek ck;
                        int     chains;
                        lex_peek_save(&ck);
                        next_tok();               /* past the field name */
                        chains = (g_cur.kind == TOK_ARROW ||
                                  g_cur.kind == TOK_DOT ||
                                  g_cur.kind == TOK_LBRACKET);
                        lex_peek_restore(&ck);
                        if (chains) {
                            lex_peek_restore(&pk_lp);   /* back to the base */
                            next_tok();                 /* consume base IDENT */
                            int head = ast_new(N_LV_CHAIN, op_line, op_col);
                            g_ast[head].c = -1;
                            g_ast[head].sym_lc = plc; g_ast[head].sym_gv = pgv;
                            build_lvalue_suffixes(head,
                                                  plc ? plc->type : pgv->type,
                                                  sid);
                            LocalType lf = g_ast[head].type;
                            require_assignable(lf, TOK_PLUSPLUS);
                            int st = incdec_stride(lf, g_ast[head].struct_id);
                            int nn = ast_new(N_LV_INCDEC_E, op_line, op_col);
                            g_ast[nn].a         = head;
                            g_ast[nn].val       = (unsigned)st;
                            g_ast[nn].flags     = is_inc ? AF_IS_INC : 0;
                            g_ast[nn].type      = lf;
                            g_ast[nn].struct_id = g_ast[head].struct_id;
                            while (pfx_paren-- > 0) expect(TOK_RPAREN, "')'");
                            return nn;
                        }
                    }
                    die(g_cur.line, g_cur.col,
                        "prefix '++'/'--' on this '->'member type "
                        "not supported");
                }
                lex_peek_restore(&pk_lp);
            }
            /* Prefix ++/-- on a DOT member in RVALUE position: `++c.b`, where
             * `c` is a struct VALUE rather than a struct pointer.  The arrow
             * form above already worked in rvalue position, and the dot form
             * already worked as a STATEMENT (parse_stmt.c's S_LV_INCDEC), so
             * this was the one empty cell in that matrix -- and it is the cell
             * 2.11BSD telnetd lands in, via
             *     #define settimer(x)  (clocks.x = ++clocks.system)
             * where ++clocks.system sits in rvalue position.  K&R A.7.4.1
             * takes ++/-- on ANY modifiable lvalue, so there was no reason for
             * the dot form to be special.
             *
             * Routed through the same uniform walker the arrow chain uses
             * (N_LV_CHAIN + build_lvalue_suffixes + N_LV_INCDEC_E) rather than
             * a bespoke node: build_lvalue_suffixes already parses '.', '->'
             * and '[' uniformly, so `++a.b.c` and `++a.b[i]` come along for
             * free.  Prefix yields the NEW value, hence no AF_RET_OLD. */
            if ((plc && plc->type == LT_STRUCT) ||
                (pgv && pgv->type == LT_STRUCT)) {
                LexPeek pk_dot;
                lex_peek_save(&pk_dot);
                next_tok();                       /* peek past base IDENT */
                if (g_cur.kind == TOK_DOT) {
                    int sid = plc ? plc->struct_id : pgv->struct_id;
                    lex_peek_restore(&pk_dot);    /* back to the base */
                    next_tok();                   /* consume base IDENT */
                    int head = ast_new(N_LV_CHAIN, op_line, op_col);
                    g_ast[head].c = -1;
                    g_ast[head].sym_lc = plc; g_ast[head].sym_gv = pgv;
                    build_lvalue_suffixes(head, plc ? plc->type : pgv->type,
                                          sid);
                    LocalType lf = g_ast[head].type;
                    require_assignable(lf, TOK_PLUSPLUS);
                    int st = incdec_stride(lf, g_ast[head].struct_id);
                    int nn = ast_new(N_LV_INCDEC_E, op_line, op_col);
                    g_ast[nn].a         = head;
                    g_ast[nn].val       = (unsigned)st;
                    g_ast[nn].flags     = is_inc ? AF_IS_INC : 0;
                    g_ast[nn].type      = lf;
                    g_ast[nn].struct_id = g_ast[head].struct_id;
                    while (pfx_paren-- > 0) expect(TOK_RPAREN, "')'");
                    return nn;
                }
                lex_peek_restore(&pk_dot);
            }
            /* `++arr[i]' / `++p[i]' -- a named base whose first suffix is an
             * INDEX.  The postfix twin has always worked; K&R A.7.4.1 takes
             * ++/-- on any modifiable lvalue and A.7.3.1 makes `E1[E2]' one,
             * so the prefix form had no claim to be the exception.  Same
             * uniform walker as the '.'/'->' arms above -- which is why
             * `++a[i].f' and `++a[i]->f' arrive with it. */
            if (plc || pgv) {
                LocalType bt = plc ? plc->type : pgv->type;
                if (ISPTR(bt) || ISARY(bt)) {
                    LexPeek pk_ix;
                    lex_peek_save(&pk_ix);
                    next_tok();                   /* peek past base IDENT */
                    if (g_cur.kind == TOK_LBRACKET) {
                        int bsid = plc ? plc->struct_id : pgv->struct_id;
                        int head = ast_new(N_LV_CHAIN, op_line, op_col);
                        g_ast[head].c = -1;
                        g_ast[head].sym_lc = plc; g_ast[head].sym_gv = pgv;
                        build_lvalue_suffixes(head, bt, bsid);
                        LocalType lf = g_ast[head].type;
                        require_assignable(lf, TOK_PLUSPLUS);
                        int st = incdec_stride(lf, g_ast[head].struct_id);
                        int nn = ast_new(N_LV_INCDEC_E, op_line, op_col);
                        g_ast[nn].a         = head;
                        g_ast[nn].val       = (unsigned)st;
                        g_ast[nn].flags     = is_inc ? AF_IS_INC : 0;
                        g_ast[nn].type      = lf;
                        g_ast[nn].struct_id = g_ast[head].struct_id;
                        while (pfx_paren-- > 0) expect(TOK_RPAREN, "')'");
                        return nn;
                    }
                    lex_peek_restore(&pk_ix);
                }
            }
        }
        Local *lc = locals_lookup(g_cur.id_ptr, g_cur.id_len);
        if (lc == NULL) {
            Global *gv = globals_lookup(g_cur.id_ptr, g_cur.id_len);
            if (gv == NULL) {
                char buf[64];
                snprintf(buf, sizeof buf, "'%.*s' undeclared",
                         g_cur.id_len, g_cur.id_ptr);
                die(g_cur.line, g_cur.col, buf);
            }
            /* LT_LONG globals: handled by the N_PREINC_GLOBAL long branch
             * (32-bit load-modify-store); fall through to build the node. */
            require_assignable(gv->type, TOK_PLUSPLUS);
            int gs = elem_size_for(gv->type, gv->struct_id);
            if (gs == 0) gs = 1;
            int n = ast_new(N_PREINC_GLOBAL, op_line, op_col);
            g_ast[n].sym_gv = gv; g_ast[n].val = (unsigned)is_inc;
            g_ast[n].val_hi = (unsigned)gs;
            g_ast[n].type = gv->type;
            g_ast[n].struct_id = gv->struct_id;
            g_ast[n].is_unsigned = gv->is_unsigned;   /* from the load */
            next_tok();
            while (pfx_paren-- > 0) expect(TOK_RPAREN, "')'");
            return n;
        }
        require_assignable(lc->type, TOK_PLUSPLUS);
        int st = elem_size_for(lc->type, lc->struct_id);
        if (st == 0) st = 1;
        int n = ast_new(N_PREINC_LOCAL, op_line, op_col);
        g_ast[n].sym_lc = lc; g_ast[n].val = (unsigned)is_inc;
        g_ast[n].val_hi = (unsigned)st;
        g_ast[n].type = lc->type;
        g_ast[n].struct_id = lc->struct_id;        /* from the load */
        g_ast[n].is_unsigned = lc->is_unsigned;    /* from the load */
        g_ast[n].fn_sig = (lc->type == LT_FN_PTR) ? lc->fn_sig_id : -1;
        next_tok();
        while (pfx_paren-- > 0) expect(TOK_RPAREN, "')'");
        return n;
    }
    if (g_cur.kind == TOK_MINUS) {
        int op_line = g_cur.line, op_col = g_cur.col;
        next_tok();
        int a = build_unary();          /* allow --x, ---x, etc. */
        int n = ast_new(N_NEG, op_line, op_col);
        g_ast[n].a = a;
        g_ast[n].type = (g_ast[a].type == LT_DOUBLE) ? LT_DOUBLE
                      : (g_ast[a].type == LT_FLOAT) ? LT_FLOAT
                      : (g_ast[a].type == LT_LLONG) ? LT_LLONG
                      : (g_ast[a].type == LT_LONG)  ? LT_LONG : LT_INT;
        /* A.7.4.5: the operand is promoted first (A.6.1). */
        g_ast[n].is_unsigned = promoted_unsigned(g_ast[a].type,
                                                 g_ast[a].is_unsigned);
        return n;
    }
    if (g_cur.kind == TOK_TILDE) {
        int op_line = g_cur.line, op_col = g_cur.col;
        next_tok();
        int a = build_unary();
        if (g_ast[a].type == LT_FLOAT || g_ast[a].type == LT_DOUBLE)
            die(op_line, op_col, "the operand of '~' must have integral type "
                "(K&R A.7.4.6)");
        int n = ast_new(N_BNOT, op_line, op_col);
        g_ast[n].a = a;
        /* A LONG OPERAND STAYS LONG.  This said LT_INT unconditionally --
         * "helper forces int" -- so `~aLong' was typed int and the emitter
         * inverted only the low word.  N_NEG directly above propagates
         * LT_LONG and always has; this is apple/fgx#155's pairs rule with the
         * two arms three lines apart.  K&R A.7.4.6 performs "the usual
         * arithmetic conversions", which do not narrow a long. */
        g_ast[n].type = (g_ast[a].type == LT_LONG || g_ast[a].type == LT_LLONG)
                      ? g_ast[a].type : LT_INT;
        g_ast[n].is_unsigned = promoted_unsigned(g_ast[a].type,
                                                 g_ast[a].is_unsigned);
        return n;
    }
    if (g_cur.kind == TOK_BANG) {
        int op_line = g_cur.line, op_col = g_cur.col;
        next_tok();
        int a = build_unary();
        int n = ast_new(N_LNOT, op_line, op_col);
        g_ast[n].a = a;
        g_ast[n].type = LT_INT;
        g_ast[n].is_unsigned = 0;            /* A.7.4.7: "The result is int" */
        return n;
    }
    if (g_cur.kind == TOK_AMP) {
        int op_line = g_cur.line, op_col = g_cur.col;
        next_tok();
        LexPeek amp_pk;
        lex_peek_save(&amp_pk);            /* checkpoint just after '&' */
        int amp_paren = 0;
        while (g_cur.kind == TOK_LPAREN) { amp_paren++; next_tok(); }
        /* `&(*p)[i]` — address of an element of the pointee: semantically
         * `*p + i` (2.11BSD touch's `argp = &(*argv)[1]`).  Desugar to
         * VAR_LOAD -> DEREF -> PPLUSI; no new emitter. */
        if (g_cur.kind == TOK_STAR) {
            next_tok();
            if (g_cur.kind != TOK_IDENT)
                die(g_cur.line, g_cur.col, "expected identifier in '&(*p)[i]'");
            Local  *plc = locals_lookup(g_cur.id_ptr, g_cur.id_len);
            Global *pgv = (plc == NULL)
                        ? globals_lookup(g_cur.id_ptr, g_cur.id_len) : NULL;
            if (plc == NULL && pgv == NULL)
                die(g_cur.line, g_cur.col, "undeclared pointer in '&(*p)[i]'");
            {
                LocalType pt = plc ? plc->type : pgv->type;
                if (!ISPTR(pt) || !ISPTR(DECREF(pt)))
                    die(g_cur.line, g_cur.col,
                        "'&(*p)[i]' requires a pointer-to-pointer p");
                next_tok();
                if (amp_paren > 0) { expect(TOK_RPAREN, "')'"); amp_paren--; }
                int v = ast_new(N_VAR_LOAD, op_line, op_col);
                g_ast[v].sym_lc = plc; g_ast[v].sym_gv = pgv;
                g_ast[v].type = pt;
                g_ast[v].struct_id = plc ? plc->struct_id : pgv->struct_id;
                int d = ast_new(N_DEREF_GENERAL, op_line, op_col);
                g_ast[d].a = v;
                g_ast[d].type = deref_result_expr_type(DECREF(pt));
                g_ast[d].struct_id = g_ast[v].struct_id;
                /* `&(*p)->m' and `&(*p)->m[i]' -- the pointee is a pointer to a
                 * struct and '->' names a member of what IT points to (ProDOS's
                 * `&(*bpp)->b_addr[off]').  K&R A.7.3.3 (p.164): "the result is
                 * an lvalue if the type is not an array type", and A.7.4.2: "The
                 * operand must be an lvalue referring neither to a bit-field nor
                 * to an object declared as register".  `*p' is a pointer value
                 * like the cast arm's base below, so it takes that arm's chain
                 * reader with g_addr_of_chain set; a subscript on the member is
                 * part of the chain. */
                if (g_cur.kind == TOK_ARROW) {
                    int saved_aoc = g_addr_of_chain;
                    g_addr_of_chain = 1;
                    int c = build_postfix_value_chain(d);
                    g_addr_of_chain = saved_aoc;
                    if (g_ast[c].kind != N_ADDR_LV_E)
                        die(op_line, op_col,
                            "'&(*p)->' requires a member chain");
                    while (amp_paren-- > 0) expect(TOK_RPAREN, "')'");
                    return c;
                }
                expect(TOK_LBRACKET, "'[' in '&(*p)[i]'");
                int idx = build_comma_entry();
                expect(TOK_RBRACKET, "']'");
                {
                    int es = elem_size_for(g_ast[d].type, g_ast[d].struct_id);
                    if (es == 0) es = 1;
                    int n = ast_new(N_ADD_PPLUSI, op_line, op_col);
                    g_ast[n].a = d; g_ast[n].b = idx;
                    g_ast[n].val = (unsigned)es;
                    g_ast[n].type = g_ast[d].type;
                    g_ast[n].struct_id = g_ast[d].struct_id;
                    while (amp_paren-- > 0) expect(TOK_RPAREN, "')'");
                    return n;
                }
            }
        }
        /* `&(EXPR)[i]` — address of an element of a pointer VALUE (not an
         * ident/pointee): semantically `EXPR + i`.  Handles the compress
         * de_stack macro `&((char_type *)(htab))[idx]`.  The greedy amp-paren
         * loop above may have eaten EXPR's own '(' (a cast opens with '('), so
         * rewind to just after '&' and re-parse with a single amp-wrap.  Only
         * for a cast/type inner (keyword OR typedef-name, e.g. char_type) — the
         * ident/`&(*p)[i]` cases keep their existing paths above; the original
         * code die()'d here anyway. */
        if (amp_paren > 0 && cur_begins_type()) {
            lex_peek_restore(&amp_pk);           /* back to just after '&' */
            expect(TOK_LPAREN, "'('");           /* the single amp-wrap '(' */
            int base = build_unary();            /* EXPR (e.g. a cast value) */
            if (ISPTR(g_ast[base].type)) {
                expect(TOK_RPAREN, "')'");
                /* apple/fgx#174: `&((cast)expr)->member`, which is the natural
                 * spelling of `&VFSTOUFS(mp)->um_sb` -- the tree's VFSTOUFS and
                 * VTOI are both `((struct T *)(...))`.  Only the SUBSCRIPT
                 * continuation was handled here, so a '->' after the cast hit
                 * `expect(TOK_LBRACKET)` and reported the '[' it wanted.
                 *
                 * K&R A.7.4.2 (p.164): "The unary operator & takes the address
                 * of its operand.  The operand must be an lvalue referring
                 * neither to a bit-field nor to an object declared as
                 * register."  A.7.3.3 makes `E1->MOS` an lvalue "if the type is
                 * not an array type", and the cast yields a pointer VALUE, so
                 * the operand qualifies however it was computed.  Nothing in
                 * either sentence distinguishes a cast base from an identifier.
                 *
                 * The mechanism is the one `&f(args)->m` already uses two arms
                 * below -- g_addr_of_chain tells the chain reader to yield the
                 * ADDRESS -- so this teaches an existing path a second kind of
                 * base rather than adding a path. */
                if (g_cur.kind == TOK_ARROW || g_cur.kind == TOK_DOT) {
                    int saved_aoc = g_addr_of_chain;
                    g_addr_of_chain = 1;
                    int v = build_postfix_value_chain(base);
                    g_addr_of_chain = saved_aoc;
                    if (g_ast[v].kind != N_ADDR_LV_E)
                        die(op_line, op_col,
                            "'&' of a cast result requires a '->'/'.' member "
                            "chain");
                    /* amp_paren is NOT rebalanced here, for the same reason the
                     * subscript arm below does not: the rewind above re-parsed
                     * from just after '&' with a single amp-wrap, so the count
                     * the greedy loop left is already spent. */
                    return v;
                }
                expect(TOK_LBRACKET, "'[' in '&(expr)[i]'");
                int idx = build_comma_entry();
                expect(TOK_RBRACKET, "']'");
                LocalType bt = g_ast[base].type;
                int bsid = g_ast[base].struct_id;
                int es = elem_size_for(bt, bsid);
                if (es == 0) es = 1;
                int n = ast_new(N_ADD_PPLUSI, op_line, op_col);
                g_ast[n].a = base; g_ast[n].b = idx;
                g_ast[n].val = (unsigned)es;
                g_ast[n].type = bt; g_ast[n].struct_id = bsid;
                g_ast[n].is_unsigned = g_ast[idx].is_unsigned;
                return n;
            }
            /* not a pointer value: restore and fall through to the die below. */
            lex_peek_restore(&amp_pk);
            while (g_cur.kind == TOK_LPAREN) next_tok();
        }
        if (g_cur.kind != TOK_IDENT)
            die(g_cur.line, g_cur.col, "expected identifier after '&'");
        const char *id_ptr = g_cur.id_ptr;
        int         id_len = g_cur.id_len;
        Local  *lc = locals_lookup(id_ptr, id_len);
        Global *gv = (lc == NULL) ? globals_lookup(id_ptr, id_len) : NULL;
        if (lc == NULL && gv == NULL) {
            int fn_idx_amp = funcs_lookup(id_ptr, id_len);
            if (fn_idx_amp >= 0) {
                /* `&f(args)->m` (tcsh sh.lex `&enthist(-1000,&lexi,0)->Hlex`):
                 * a CALL used as the chain's base, NOT the address of the
                 * function.  Distinguished by the '(' -- without this check the
                 * whole thing parsed as `&f` and choked on the leftover
                 * `(args)->m`.  K&R A.7.3.3 makes the '->' result an lvalue, so
                 * '&' of it is legal however the base was computed; the value
                 * chain already accepts a call base for STORES, so this only
                 * teaches it the address case.  g_addr_of_chain tells
                 * build_postfix_value_chain to yield the ADDRESS. */
                LexPeek fpk;
                lex_peek_save(&fpk);
                next_tok();                      /* past the function name */
                if (g_cur.kind == TOK_LPAREN) {
                    lex_peek_restore(&fpk);      /* back to the name */
                    int saved_aoc = g_addr_of_chain;
                    g_addr_of_chain = 1;
                    int v = build_unary();       /* call + chain -> address */
                    g_addr_of_chain = saved_aoc;
                    if (g_ast[v].kind != N_ADDR_LV_E)
                        die(op_line, op_col,
                            "'&' of a call result requires a '->'/'.' member "
                            "chain or a subscript");
                    while (amp_paren-- > 0) expect(TOK_RPAREN, "')'");
                    return v;
                }
                lex_peek_restore(&fpk);
                next_tok();
                int n = ast_new(N_ADDR_FUNC, op_line, op_col);
                g_ast[n].val = (unsigned)fn_idx_amp;
                g_ast[n].type = LT_FN_PTR;
                while (amp_paren-- > 0) expect(TOK_RPAREN, "')'");
                return n;
            }
            char buf[64];
            snprintf(buf, sizeof buf, "'%.*s' undeclared", id_len, id_ptr);
            die(g_cur.line, g_cur.col, buf);
        }
        next_tok();
        /* An inner grouping paren around the addressed IDENT -- `&((p)[1])`,
         * `&(p)->f`, `&(p).m` (tcsh sh.dir's UC(&((c)[1])) after ISDOTDOT):
         * the greedy amp-paren loop ate `(p)`'s opening '(' as if an amp-wrap,
         * so the postfix `[`/`->`/`.` below would mis-associate.  Give it back:
         * a ')' immediately after the ident that is followed by a postfix op
         * closed a grouping paren, not '&'s wrap -- consume it and rebalance. */
        while (amp_paren > 0 && g_cur.kind == TOK_RPAREN) {
            LexPeek gp;
            lex_peek_save(&gp);
            next_tok();                       /* past the ')' */
            if (g_cur.kind == TOK_LBRACKET || g_cur.kind == TOK_ARROW ||
                g_cur.kind == TOK_DOT) {
                amp_paren--;                  /* '(p)' grouped the ident */
            } else {
                lex_peek_restore(&gp);        /* a real amp-wrap close */
                break;
            }
        }
        if (g_cur.kind == TOK_ARROW) {
            LocalType bt  = lc ? lc->type      : gv->type;
            int       sid = lc ? lc->struct_id : gv->struct_id;
            if (bt != LT_STRUCT_PTR)
                die(g_cur.line, g_cur.col, "'&...->' on non-struct-pointer");
            /* `&p->m.n' -- a dot after the arrow -- and its two siblings
             * `&p->q->f' (two arrows, bare leaf) and `&p->a[i].f'.  The arms
             * below each consume a fixed-shape PREFIX of the suffix run: the
             * bare-field arm returned `&p->m' with `.n' unread and the caller
             * then reported "expected ')'" at the dot, the array-field arm left
             * a trailing `.f' the same way, and the arrow-chain loop refuses a
             * bare leaf outright.  2.11BSD's tty.h reaches all of this through
             * `#define t_rawq t_nu.t_t.T_rawq', so `nextc(&tp->t_rawq, cp)' in
             * ttyrub and ttyretype is exactly the shape.  apple/fgx#212.
             *
             * K&R p.164 A.7.4 gives `unary-expression: postfix expression', and
             * the p.198 grammar makes `postfix-expression.identifier' itself a
             * postfix-expression, so the run is ONE operand however deep it
             * goes.  A.7.3.3 (p.164) supplies the lvalue: "The result refers to
             * the named member of the structure or union to which the pointer
             * expression points, and the type is the type of the member; the
             * result is an lvalue if the type is not an array type."  A.7.4.2
             * then puts no bound on how that lvalue was reached: "The unary
             * operator & takes the address of its operand.  The operand must be
             * an lvalue referring neither to a bit-field nor to an object
             * declared as register."  Depth is not one of the exceptions.
             *
             * Routed through the uniform lvalue walker for the same reason the
             * `&p[i].f' arm below is: it walks `.', `->' and `[i]' in one
             * type-driven pass and carries the far-pointer bank, which a scaled
             * add on a bare pointer node drops.  Fourth of this family after
             * #189/#200/#202/#207 -- the address-of production has one arm per
             * base kind, and the arrow-plus-dot base is the one nobody wrote. */
            if (addr_run_needs_walker()) {
                int head = ast_new(N_LV_CHAIN, op_line, op_col);
                g_ast[head].c = -1;
                g_ast[head].sym_lc = lc; g_ast[head].sym_gv = gv;
                build_lvalue_suffixes(head, bt, sid);
                int an = ast_new(N_ADDR_LV_E, op_line, op_col);
                g_ast[an].a = head;
                g_ast[an].type = (g_ast[head].type == LT_STRUCT)
                               ? LT_STRUCT_PTR
                               : INCREF(g_ast[head].type, DERIV_PTR);
                g_ast[an].struct_id = g_ast[head].struct_id;
                while (amp_paren-- > 0) expect(TOK_RPAREN, "')'");
                return an;
            }
            {
                LexPeek pk_lp;
                lex_peek_save(&pk_lp);
                next_tok();                       /* peek '->' */
                Field *f0 = (g_cur.kind == TOK_IDENT)
                    ? struct_field_lookup(sid, g_cur.id_ptr, g_cur.id_len)
                    : NULL;
                next_tok();                       /* peek token after field */
                int after_lbr = (g_cur.kind == TOK_LBRACKET);
                int is_bare = (f0 != NULL && !after_lbr &&
                               g_cur.kind != TOK_ARROW);
                LocalType ftype = f0 ? f0->type       : LT_INT;
                int       fsid  = f0 ? f0->struct_id  : -1;
                int is_arrfield = (f0 != NULL && after_lbr &&
                                   (ftype == LT_CHAR_ARRAY ||
                                    ftype == LT_INT_ARRAY ||
                                    ftype == LT_LONG_ARRAY ||
                                    ftype == LT_FLOAT_ARRAY ||
                                    ftype == LT_STRUCT_ARRAY));
                lex_peek_restore(&pk_lp);
                if (is_bare) {
                    next_tok();                   /* consume '->' */
                    next_tok();                   /* consume field name */
                    int n = ast_new(N_ADDR_ARROW_BARE, op_line, op_col);
                    g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                    g_ast[n].sym_f = f0;
                    g_ast[n].type = INCREF(ftype, DERIV_PTR);
                    g_ast[n].struct_id = fsid;
                    while (amp_paren-- > 0) expect(TOK_RPAREN, "')'");
                    return n;
                }
                if (is_arrfield) {
                    int es = elem_size_for(ftype, fsid);
                    next_tok();                   /* consume '->' */
                    next_tok();                   /* consume field name */
                    next_tok();                   /* consume '[' */
                    int idx = build_comma_entry();
                    expect(TOK_RBRACKET, "']'");
                    int n = ast_new(N_ADDR_ARROW_ARRFIELD, op_line, op_col);
                    g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                    g_ast[n].sym_f = f0; g_ast[n].a = idx;
                    g_ast[n].val = (unsigned)es;
                    g_ast[n].type = INCREF(DECREF(ftype), DERIV_PTR);
                    g_ast[n].struct_id = (ftype == LT_STRUCT_ARRAY) ? fsid : -1;
                    while (amp_paren-- > 0) expect(TOK_RPAREN, "')'");
                    return n;
                }
            }
            /* chained '&base->f->...->p[i]': capture the arrow-chain hops the
             * way emit_arrow_chain consumed them. */
            int hop0 = g_n_ast_fields, n_hops = 0;
            LocalType chain_ty = LT_INT;
            int       chain_sid = -1;
            int       cur_sid = sid;
            for (;;) {
                next_tok();                        /* consume '->' */
                if (g_cur.kind != TOK_IDENT)
                    die(g_cur.line, g_cur.col, "expected field name after '->'");
                Field *f = struct_field_lookup(cur_sid, g_cur.id_ptr, g_cur.id_len);
                if (f == NULL) die(g_cur.line, g_cur.col, "no such field");
                next_tok();
                if (g_n_ast_fields >= MAX_AST_KIDS)
                    die(g_cur.line, g_cur.col, "arrow-chain hop pool overflow");
                g_ast_fields[g_n_ast_fields++] = f; n_hops++;
                if (f->type == LT_CHAR_ARRAY || f->type == LT_INT_ARRAY) {
                    chain_ty = (f->type == LT_CHAR_ARRAY) ? LT_CHAR_PTR
                                                          : LT_INT_PTR;
                    chain_sid = -1;
                    break;
                }
                if (f->type == LT_STRUCT_ARRAY || f->type == LT_LONG_ARRAY ||
                    f->type == LT_FLOAT_ARRAY)
                    die(g_cur.line, g_cur.col,
                        "chained '->' to in-struct struct/long/float array field not yet supported");
                chain_ty = f->type; chain_sid = f->struct_id;
                if (f->type == LT_STRUCT_PTR && g_cur.kind == TOK_ARROW) {
                    cur_sid = f->struct_id;
                    continue;
                }
                /* ...and through an EMBEDDED struct via '.', the third copy of
                 * this hop run and the same production the other two carry
                 * (apple/fgx#189).  `&' takes the address of a whole postfix
                 * expression -- K&R A.7.4's unary-expression is a
                 * postfix-expression, and A.7.3.3 makes `E->m.n' one -- so the
                 * run must reach the end of the chain before the address is
                 * taken.  Stopping at `.' left the tail unconsumed and the
                 * caller said "expected ')'", which points at the wrong thing.
                 * With the run complete, `&E->m.n' reaches the honest
                 * bare-field refusal below instead. */
                if (f->type == LT_STRUCT && g_cur.kind == TOK_DOT) {
                    cur_sid = f->struct_id;
                    continue;
                }
                break;
            }
            if (g_cur.kind != TOK_LBRACKET)
                die(g_cur.line, g_cur.col,
                    "addr-of chain requires an index '[' "
                    "(bare-field addr-of not supported yet)");
            /* elem_size_for, NOT ptr_stride with a fallback.  ptr_stride
             * returns 0 for a pointer-to-STRUCT *by design* -- its own default
             * arm says "struct handled by elem_size_for" -- so `if (!es) es = 2`
             * papered over that sentinel with the size of an int.  `&p->v[1]`
             * with v a `struct iovec *` therefore scaled the index by 2 where
             * the struct is 6 bytes, and K&R A.7.7 is explicit that it must be
             * the size of the pointee: "The latter is converted to an address
             * offset by multiplying it by the size of the object to which the
             * pointer points."
             *
             * The result was not a diagnosable error but a WILD POINTER: the
             * address landed inside the previous element, and the first caller
             * to find it was uiomove advancing to its second iovec, which
             * corrupted memory and left the machine wandering with a blank
             * screen.  The static-base and parameter-base emitters disagreed,
             * which is why `&s.v[1]` was correct while `&p->v[1]` was not --
             * the same twin-emitter shape as apple/fgx#155.
             *
             * elem_size_for DIES on a lost struct id rather than guessing, so
             * the failure mode for anything it cannot size is now loud. */
            int es = elem_size_for(chain_ty, chain_sid);
            next_tok();                            /* consume '[' */
            int idx = build_comma_entry();
            expect(TOK_RBRACKET, "']'");
            /* CU-1: '&p->y[a][b]' — y a pointer-to-pointer leaf: the
             * address is the VALUE p->y[a] plus b, i.e. exactly what
             * `p->y[a] + b` builds (N_ARROW_LOAD_CHAIN -> N_IPV_READ ->
             * N_ADD_PPLUSI).  The hops recorded above are reused minus
             * the leaf (the load-chain node carries it in sym_f). */
            if (g_cur.kind == TOK_LBRACKET &&
                ISPTR(chain_ty) && ISPTR(DECREF(chain_ty))) {
                Field *cu1_leaf = g_ast_fields[hop0 + n_hops - 1];
                next_tok();                        /* consume second '[' */
                int idx2 = build_comma_entry();
                expect(TOK_RBRACKET, "']'");
                int ch = ast_new(N_ARROW_LOAD_CHAIN, op_line, op_col);
                g_ast[ch].sym_lc = lc; g_ast[ch].sym_gv = gv;
                g_ast[ch].kid0 = hop0; g_ast[ch].n_kids = n_hops - 1;
                g_ast[ch].sym_f = cu1_leaf;
                g_ast[ch].type = chain_ty;
                g_ast[ch].struct_id = cu1_leaf->struct_id;
                g_ast[ch].is_unsigned = cu1_leaf->is_unsigned;
                int rd = ast_new(N_IPV_READ, op_line, op_col);
                g_ast[rd].a = ch; g_ast[rd].b = idx;
                g_ast[rd].val = (unsigned)es;
                g_ast[rd].val_hi = (unsigned)chain_ty;
                g_ast[rd].type = DECREF(chain_ty);
                int pn = ast_new(N_ADD_PPLUSI, op_line, op_col);
                g_ast[pn].a = rd; g_ast[pn].b = idx2;
                g_ast[pn].val = (unsigned)elem_size_for(DECREF(chain_ty),
                                                        g_ast[rd].struct_id);
                g_ast[pn].type = DECREF(chain_ty);
                g_ast[pn].is_unsigned = g_ast[idx2].is_unsigned;
                while (amp_paren-- > 0) expect(TOK_RPAREN, "')'");
                return pn;
            }
            int n = ast_new(N_ADDR_CHAIN_IDX, op_line, op_col);
            g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
            g_ast[n].kid0 = hop0; g_ast[n].n_kids = n_hops;
            g_ast[n].a = idx; g_ast[n].val = (unsigned)es;
            g_ast[n].val_hi = (unsigned)chain_ty;  /* chain result ptr type */
            g_ast[n].type = chain_ty;              /* &element == ptr-to-element */
            g_ast[n].struct_id = -1;
            (void)chain_sid;
            while (amp_paren-- > 0) expect(TOK_RPAREN, "')'");
            return n;
        }
        if (g_cur.kind == TOK_DOT &&
            ((lc && lc->type == LT_STRUCT) || (gv && gv->type == LT_STRUCT))) {
            int dsid = lc ? lc->struct_id : gv->struct_id;
            /* `&s.pfield[i]` -- tcsh sh.lex `blkcpy(B.Bfbuf, &B.Bfbuf[sb])`,
             * where Bfbuf is a `Char **`.  The dotted leaf is a POINTER, so the
             * '[' is a SUBSCRIPT of that pointer rather than an array-field
             * index: the arrfield arm below tests only ARRAY types and the bare
             * arm would return with '[' unread ("expected ')'").  Same
             * non-uniformity as the READ (52e32a4a) and STORE twins of this
             * shape; route the whole suffix run through the uniform walker
             * (K&R A.7.4.2: '&' applies to any lvalue).  Gated on the field
             * really being a pointer so the array-field arm keeps its cases. */
            {
                /* The pointer leaf may sit past embedded-struct hops --
                 * `&ifc.ifc_ifcu.ifcu_req[i]', net/if.h's ifc_req through its
                 * union -- so walk `.name' pairs while the member is a struct
                 * or union VALUE, and test the field the '[' follows. */
                int ti = g_tok_idx - 1;               /* at the first '.' */
                int hsid = dsid;
                Field *pf = NULL;
                while (hsid >= 0 && g_toks[ti].kind == TOK_DOT &&
                       g_toks[ti + 1].kind == TOK_IDENT) {
                    pf = field_lookup_dot(hsid, g_toks[ti + 1].id_ptr,
                                          g_toks[ti + 1].id_len);
                    if (pf == NULL || g_toks[ti + 2].kind != TOK_DOT ||
                        pf->type != LT_STRUCT)
                        break;
                    hsid = pf->struct_id;
                    ti += 2;
                }
                if (pf != NULL && g_toks[ti].kind == TOK_DOT &&
                    g_toks[ti + 2].kind == TOK_LBRACKET) {
                    if (ISPTR(pf->type)) {
                        int head = ast_new(N_LV_CHAIN, op_line, op_col);
                        g_ast[head].c = -1;
                        g_ast[head].sym_lc = lc; g_ast[head].sym_gv = gv;
                        build_lvalue_suffixes(head,
                                              lc ? lc->type : gv->type, dsid);
                        int an = ast_new(N_ADDR_LV_E, op_line, op_col);
                        g_ast[an].a = head;
                        g_ast[an].type = (g_ast[head].type == LT_STRUCT)
                                       ? LT_STRUCT_PTR
                                       : INCREF(g_ast[head].type, DERIV_PTR);
                        g_ast[an].struct_id = g_ast[head].struct_id;
                        while (amp_paren-- > 0) expect(TOK_RPAREN, "')'");
                        return an;
                    }
                }
            }
            /* The struct-VARIABLE twin of the arrow arm's routing above, and
             * the same fault one arm over: `&v.MA[i].z' (a dot after a
             * subscript) and `&v.MP->z' (an arrow after a dot) both return
             * from a fixed-shape arm with the tail unread.  Found writing
             * #212's fixture -- `&gt.MA[1].z' was there only as the trusted
             * cross-check for the pointer case and rejected in its own right,
             * which is the fifth time this family has had a silent sibling.
             * Same K&R reading as above: the run is one postfix-expression
             * (p.198 grammar, A.7.3.2/A.7.3.3) and A.7.4.2 does not bound its
             * depth.  The pointer-member case just above stays ahead of this
             * one: `&v.pfield[i]' is a covered shape by hop kinds and needs
             * the walker for a reason this scan cannot see (a POINTER leaf). */
            if (addr_run_needs_walker()) {
                int head = ast_new(N_LV_CHAIN, op_line, op_col);
                g_ast[head].c = -1;
                g_ast[head].sym_lc = lc; g_ast[head].sym_gv = gv;
                build_lvalue_suffixes(head, lc ? lc->type : gv->type, dsid);
                int an = ast_new(N_ADDR_LV_E, op_line, op_col);
                g_ast[an].a = head;
                g_ast[an].type = (g_ast[head].type == LT_STRUCT)
                               ? LT_STRUCT_PTR
                               : INCREF(g_ast[head].type, DERIV_PTR);
                g_ast[an].struct_id = g_ast[head].struct_id;
                while (amp_paren-- > 0) expect(TOK_RPAREN, "')'");
                return an;
            }
            int dot_cum = 0;                  /* summed offset of intermediate
                                               * value-member hops (a.b.c) */
            Field *f = NULL;
            for (;;) {
                next_tok();                   /* consume '.' */
                if (g_cur.kind != TOK_IDENT)
                    die(g_cur.line, g_cur.col, "field name after '.'");
                if (dsid < 0)
                    die(g_cur.line, g_cur.col, "'.' on a non-struct operand");
                f = field_lookup_dot(dsid, g_cur.id_ptr, g_cur.id_len);
                if (f == NULL) die(g_cur.line, g_cur.col, "no such field");
                next_tok();                   /* consume field name */
                /* Another embedded-struct hop (`a.b.c` with b a struct value):
                 * fold b's offset in and keep walking.  Only value members —
                 * pointer/array-in-the-middle chains take their own paths. */
                if (g_cur.kind == TOK_DOT && f->type == LT_STRUCT) {
                    dot_cum += f->byte_offset;
                    dsid = f->struct_id;
                    continue;
                }
                break;
            }
            if (g_cur.kind == TOK_LBRACKET &&
                (f->type == LT_CHAR_ARRAY || f->type == LT_INT_ARRAY ||
                 f->type == LT_LONG_ARRAY || f->type == LT_FLOAT_ARRAY ||
                 f->type == LT_STRUCT_ARRAY)) {
                int es = elem_size_for(f->type, f->struct_id);
                next_tok();                   /* consume '[' */
                int idx = build_comma_entry();
                expect(TOK_RBRACKET, "']'");
                int n = ast_new(N_ADDR_DOT_ARRFIELD, op_line, op_col);
                g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                g_ast[n].sym_f = f; g_ast[n].a = idx;
                g_ast[n].val = (unsigned)es;
                g_ast[n].val_hi = (unsigned)dot_cum;   /* extra hop offset */
                g_ast[n].type = INCREF(DECREF(f->type), DERIV_PTR);
                g_ast[n].struct_id = (f->type == LT_STRUCT_ARRAY) ? f->struct_id : -1;
                while (amp_paren-- > 0) expect(TOK_RPAREN, "')'");
                return n;
            }
            int n = ast_new(N_ADDR_DOT_BARE, op_line, op_col);
            g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv; g_ast[n].sym_f = f;
            g_ast[n].val_hi = (unsigned)dot_cum;       /* extra hop offset */
            g_ast[n].type = INCREF(f->type, DERIV_PTR);
            g_ast[n].struct_id = f->struct_id;
            while (amp_paren-- > 0) expect(TOK_RPAREN, "')'");
            return n;
        }
        /* THE ELEMENT TYPE IS NOT A CONDITION ON THIS PRODUCTION, which is
         * what the long and float arms below are for (apple/fgx#191).  K&R
         * A.7.3.1: "One of the two expressions must have type `pointer to T',
         * where T is some type, and the other must have integral type; the
         * type of the subscript expression is T."  T is universally
         * quantified -- there is no list of element types a subscript works
         * for.  A.7.4.2 then fixes the result: "If the type of the operand is
         * T, the type of the result is `pointer to T.'"
         *
         * LT_LONG_ARRAY and LT_FLOAT_ARRAY were simply absent from this test,
         * so `&tab[i]' on a long table fell PAST the arm with the '[' still
         * unread and the caller reported "expected ')'" -- a diagnostic
         * pointing at the paren rather than at the thing it cannot do.  int,
         * char, struct and pointer arrays all worked, and so did `&p[i]' on a
         * long POINTER, which is why the shape looked like an element-size
         * limit and is not one: a 6-byte struct element is fine. */
        if (g_cur.kind == TOK_LBRACKET &&
            ((lc && (lc->type == LT_STRUCT_ARRAY || lc->type == LT_CHAR_ARRAY ||
                     lc->type == LT_INT_ARRAY || lc->type == LT_LONG_ARRAY ||
                     lc->type == LT_FLOAT_ARRAY || lc->type == LT_LLONG_ARRAY ||
                     lc->type == LT_DOUBLE_ARRAY || is_ptr_array(lc->type))) ||
             (gv && (gv->type == LT_STRUCT_ARRAY || gv->type == LT_CHAR_ARRAY ||
                     gv->type == LT_INT_ARRAY || gv->type == LT_LONG_ARRAY ||
                     gv->type == LT_FLOAT_ARRAY || gv->type == LT_LLONG_ARRAY ||
                     gv->type == LT_DOUBLE_ARRAY || is_ptr_array(gv->type))))) {
            LocalType at  = lc ? lc->type      : gv->type;
            int       sid = lc ? lc->struct_id : gv->struct_id;
            int       es;
            LocalType rty;
            if (at == LT_STRUCT_ARRAY) {
                es = (g_structs[sid].total_size + 1) & ~1; rty = LT_STRUCT_PTR;
            } else if (at == LT_CHAR_ARRAY) {
                es = 1; rty = LT_CHAR_PTR;
            } else if (at == LT_LONG_ARRAY) {
                es = 4; rty = LT_LONG_PTR;
            } else if (at == LT_FLOAT_ARRAY) {
                es = 4; rty = LT_FLOAT_PTR;
            } else if (at == LT_LLONG_ARRAY) {
                es = 8; rty = LT_LLONG_PTR;
            } else if (at == LT_DOUBLE_ARRAY) {
                es = 8; rty = LT_DOUBLE_PTR;
            } else if (is_ptr_array(at)) {
                es = 4; rty = INCREF(DECREF(at), DERIV_PTR);
            } else {
                es = 2; rty = LT_INT_PTR;
            }
            next_tok();                       /* consume the first '[' */
            int nd = lc ? lc->n_dims : gv->n_dims;
            int n;
            if (nd > 1) {
                /* A MULTI-DIMENSIONAL BASE HAS A STRIDE PER LEVEL, and this
                 * arm used to have none (apple/fgx#192).  It took ONE
                 * subscript and scaled it by the ELEMENT size, which produced
                 * two different failures from one cause:
                 *
                 *   `&i2[1][2]'  -- the second '[' was left unread and the
                 *      caller said "expected ')'";
                 *   `&i2[1]'     -- COMPILED, and computed `&i2[0][1]'.  The
                 *      row stride is dims[1] * elem, not elem, so the address
                 *      was short by a whole row and nothing said so.  That is
                 *      the worse half: a reject is loud, a wild pointer is not.
                 *
                 * K&R A.7.3.1 is recursive by construction -- "A postfix
                 * expression followed by an expression in square brackets is a
                 * postfix expression", and E1[E2] is *((E1)+(E2)) -- so
                 * i2[1][2] is the subscript production applied to its own
                 * result, and A.8.6.2 gives the row its size.  The offset walk
                 * is therefore the read path's: seed with the row stride and
                 * divide it by the next dimension at each level, which is
                 * exactly what walk_cio already does for `arr[i][j]' as a
                 * VALUE.  Reusing it is what keeps the address and the read
                 * agreeing about where an element is.
                 *
                 * FEWER SUBSCRIPTS THAN DIMENSIONS IS LEGAL and lands here
                 * too: `&i2[1]' is the address of a row, and its type follows
                 * set_arr_read_type's rule for the same case -- the decayed
                 * row pointer.  This tree has no pointer-to-array type to give
                 * it, and the VALUE is the one C specifies either way. */
                int tmp[MAX_DIMS];
                int cnt = 0;
                tmp[cnt++] = build_comma_entry();
                expect(TOK_RBRACKET, "']'");
                while (g_cur.kind == TOK_LBRACKET && cnt < nd) {
                    next_tok();
                    if (cnt >= MAX_DIMS)
                        die(g_cur.line, g_cur.col, "too many subscripts");
                    tmp[cnt++] = build_comma_entry();
                    expect(TOK_RBRACKET, "']'");
                }
                if (g_n_ast_kids + cnt > MAX_AST_KIDS)
                    die(op_line, op_col, "index kid pool overflow");
                int kid0 = g_n_ast_kids;
                for (int q = 0; q < cnt; q++)
                    g_ast_kids[g_n_ast_kids++] = tmp[q];
                n = ast_new(N_ADDR_ARR_ELEM_MD, op_line, op_col);
                g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                g_ast[n].kid0 = kid0; g_ast[n].n_kids = cnt;
                g_ast[n].val = (unsigned)es;
                if (cnt < nd) {
                    g_ast[n].type = (at == LT_CHAR_ARRAY) ? LT_CHAR_PTR
                                                          : LT_INT_PTR;
                    g_ast[n].struct_id = -1;
                } else {
                    g_ast[n].type = rty;
                    g_ast[n].struct_id = (at == LT_STRUCT_ARRAY) ? sid : -1;
                }
            } else {
                int idx = build_comma_entry();
                expect(TOK_RBRACKET, "']'");
                n = ast_new(N_ADDR_ARR_ELEM, op_line, op_col);
                g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv; g_ast[n].a = idx;
                g_ast[n].val = (unsigned)es;
                g_ast[n].type = rty;
                g_ast[n].struct_id = (at == LT_STRUCT_ARRAY) ? sid : -1;
            }
            /* optional '.field...' chain on a struct-array element */
            if (at == LT_STRUCT_ARRAY && g_cur.kind == TOK_DOT) {
                int       cum  = 0;
                int       csid = sid;
                LocalType fty  = LT_STRUCT;
                int       fsid = sid;
                while (g_cur.kind == TOK_DOT) {
                    next_tok();
                    if (g_cur.kind != TOK_IDENT)
                        die(g_cur.line, g_cur.col, "field name after '.'");
                    Field *ff = field_lookup_dot(csid, g_cur.id_ptr, g_cur.id_len);
                    if (ff == NULL) die(g_cur.line, g_cur.col, "no such field");
                    next_tok();
                    cum += ff->byte_offset;
                    fty = ff->type; fsid = ff->struct_id; csid = ff->struct_id;
                }
                g_ast[n].val_hi = (unsigned)cum;
                g_ast[n].b = -2;                  /* marker: dot-chain present */
                /* `&arr[i].field[j]' -- A SUBSCRIPT ON THE ARRAY FIELD, which
                 * this arm built the address of and then left unread, so the
                 * `[' reached the statement parser as `expected ;'.
                 * apple/fgx#202.
                 *
                 * EVERY NEIGHBOUR ALREADY WORKED, which is what makes it an
                 * artificial reject rather than a missing feature:
                 * `&one.arr[j]' (struct-var base), `&p->arr[j]' (pointer
                 * base), `&g.inner.arr[j]' (nested dot) and BOTH the read and
                 * store twins of `arr[i].arr[j]' all compile.  Only the
                 * struct-ARRAY base lacked the arm -- the same
                 * one-hop-further-out shape as apple/fgx#207's second cell,
                 * and the same twin rule as #155.
                 *
                 * K&R A.7.3.1: "A postfix expression followed by an
                 * expression in square brackets is a postfix expression
                 * denoting a subscripted array reference ... E1[E2] is
                 * identical (by definition) to *((E1)+(E2))", and A.7.4.2
                 * makes `&' of that the pointer.  Nothing conditions either
                 * on how E1 was spelled.
                 *
                 * The index rides in `c' and the FIELD's element size in
                 * `n_kids', both free on this node -- and the size has to be
                 * carried because it is NOT the outer array's, which `val'
                 * already holds. */
                if ((fty == LT_CHAR_ARRAY || fty == LT_INT_ARRAY ||
                     fty == LT_LONG_ARRAY || fty == LT_FLOAT_ARRAY ||
                     fty == LT_STRUCT_ARRAY) && g_cur.kind == TOK_LBRACKET) {
                    next_tok();                       /* consume '[' */
                    int jdx = build_comma_entry();
                    expect(TOK_RBRACKET, "']'");
                    g_ast[n].c = jdx;
                    /* fty, NOT DECREF(fty): elem_size_for does its own
                     * DECREF, and double-decrementing yielded 0 -- which
                     * emit_index_scale reads as "no scaling" and silently
                     * adds an UNSCALED index.  Caught by the fixture, not by
                     * the compile: the first cut of this compiled and
                     * computed a wrong address (apple/fgx#153b's rule that a
                     * parse fix's test must assert VALUES). */
                    g_ast[n].n_kids = elem_size_for(fty, fsid);
                    g_ast[n].type      = INCREF(DECREF(fty), DERIV_PTR);
                    g_ast[n].struct_id = (fty == LT_STRUCT_ARRAY) ? fsid : -1;
                    while (amp_paren-- > 0) expect(TOK_RPAREN, "')'");
                    return n;
                }
                if (fty == LT_STRUCT) {
                    g_ast[n].type      = LT_STRUCT_PTR;
                    g_ast[n].struct_id = fsid;
                } else if (fty == LT_CHAR_ARRAY || fty == LT_INT_ARRAY ||
                           fty == LT_LONG_ARRAY || fty == LT_FLOAT_ARRAY ||
                           fty == LT_STRUCT_ARRAY) {
                    g_ast[n].type      = INCREF(DECREF(fty), DERIV_PTR);
                    g_ast[n].struct_id = (fty == LT_STRUCT_ARRAY) ? fsid : -1;
                } else {
                    g_ast[n].type      = INCREF(fty, DERIV_PTR);
                    g_ast[n].struct_id = fsid;
                }
            }
            while (amp_paren-- > 0) expect(TOK_RPAREN, "')'");
            return n;
        }
        /* `&p[i].field...` -- p a POINTER to struct.  The N_ADDR_PTR_ELEM arm
         * below consumes `[i]` and RETURNS, leaving the '.' unread, so the
         * caller reported "expected ')'" at the field.  `&arr[i].field` works
         * because the ARRAY twin (N_ADDR_ARR_ELEM, above) grew a dot-chain
         * block; the POINTER twin never did -- the same non-uniformity the
         * `&s.pfield[i]` case further up records, and the third instance of it.
         *
         * Found when the VFS pools moved from far-bank arrays to heap
         * pointers: `&namecache_pool[0].nc_forw` had compiled for a year as an
         * array and stopped parsing the day its base became a pointer, which
         * is why a TYPE change surfaced as a SYNTAX error.
         *
         * Routed through the uniform lvalue walker rather than given its own
         * offset arithmetic: it handles `[i]` and `.f` in one pass and carries
         * the far-pointer bank, and a pointer base here is typically a heap
         * address in ANOTHER bank -- exactly the case a scaled add on a bare
         * pointer node drops (feedback_fcc_ptr_arith_single_bank_gap). */
        if (g_cur.kind == TOK_LBRACKET &&
            ((lc && lc->type == LT_STRUCT_PTR) ||
             (gv && gv->type == LT_STRUCT_PTR))) {
            int ti = g_tok_idx - 1;           /* at the '[' */
            int d = 0, j = ti;
            for (; g_toks[j].kind != TOK_EOF; j++) {
                if (g_toks[j].kind == TOK_LBRACKET) d++;
                else if (g_toks[j].kind == TOK_RBRACKET && --d == 0) break;
            }
            if (g_toks[j].kind == TOK_RBRACKET &&
                g_toks[j + 1].kind == TOK_DOT) {
                int sid  = lc ? lc->struct_id : gv->struct_id;
                int head = ast_new(N_LV_CHAIN, op_line, op_col);
                g_ast[head].c = -1;
                g_ast[head].sym_lc = lc; g_ast[head].sym_gv = gv;
                build_lvalue_suffixes(head, lc ? lc->type : gv->type, sid);
                int an = ast_new(N_ADDR_LV_E, op_line, op_col);
                g_ast[an].a = head;
                g_ast[an].type = (g_ast[head].type == LT_STRUCT)
                               ? LT_STRUCT_PTR
                               : INCREF(g_ast[head].type, DERIV_PTR);
                g_ast[an].struct_id = g_ast[head].struct_id;
                while (amp_paren-- > 0) expect(TOK_RPAREN, "')'");
                return an;
            }
        }
        if (g_cur.kind == TOK_LBRACKET &&
            ((lc && (lc->type == LT_CHAR_PTR || lc->type == LT_INT_PTR ||
                     lc->type == LT_VOID_PTR || lc->type == LT_LONG_PTR ||
                     lc->type == LT_STRUCT_PTR)) ||
             (gv && (gv->type == LT_CHAR_PTR || gv->type == LT_INT_PTR ||
                     gv->type == LT_VOID_PTR || gv->type == LT_LONG_PTR ||
                     gv->type == LT_STRUCT_PTR)))) {
            LocalType pt  = lc ? lc->type      : gv->type;
            int       sid = lc ? lc->struct_id : gv->struct_id;
            int es;
            if (pt == LT_STRUCT_PTR) es = (g_structs[sid].total_size + 1) & ~1;
            else { es = ptr_stride(pt); if (!es) es = 2; }
            next_tok();
            int idx = build_comma_entry();
            expect(TOK_RBRACKET, "']'");
            int n = ast_new(N_ADDR_PTR_ELEM, op_line, op_col);
            g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv; g_ast[n].a = idx;
            g_ast[n].val = (unsigned)es;
            g_ast[n].type = pt;
            g_ast[n].struct_id = (pt == LT_STRUCT_PTR) ? sid : -1;
            while (amp_paren-- > 0) expect(TOK_RPAREN, "')'");
            return n;
        }
        /* '&p[i]' / '&p[i][j]' — p a pointer-to-pointer (char **yy, struct **, ...).
         * BARE '&p[i]' (address of an element of the T*-array p points at) is
         * `p + i*sizeof(T*)` with p's BANK intact -- route through the uniform
         * K&R walker (emit_lvalue_addr; K&R A.7.4.2 &, A.7.3.1 E1[E2]==*(E1+E2)),
         * whose deref-then-scaled-add carries the far-pointer bank (the plain
         * `p+i` node drops it -- feedback_fcc_ptr_arith_single_bank_gap).  The
         * two-subscript '&p[i][j]' keeps the existing N_ARR_READ->N_ADD_PPLUSI. */
        if (g_cur.kind == TOK_LBRACKET) {
            LocalType bt2 = lc ? lc->type : gv->type;
            if (ISPTR(bt2) && ISPTR(DECREF(bt2))) {
                LocalType ety = DECREF(bt2);        /* p[i]'s type (a T*) */
                int esid = (BTYPE(ety) == BT_STRUCT)
                         ? (lc ? lc->struct_id : gv->struct_id) : -1;
                next_tok();                         /* consume '[' */
                int idx = build_comma_entry();
                expect(TOK_RBRACKET, "']'");
                if (g_cur.kind != TOK_LBRACKET) {
                    /* bare &p[i]: one INDEX step on a pointer base -> the walker.
                     * Stride is the CONTAINER's element size (sizeof *p ==
                     * sizeof(T*)), exactly as build_lvalue_suffixes computes it
                     * -- elem_size_for(bt2), not of the element type ety. */
                    int es = elem_size_for(bt2, lc ? lc->struct_id
                                                    : gv->struct_id);
                    if (es == 0) es = 1;
                    int step = ast_new(N_LV_STEP_INDEX, op_line, op_col);
                    g_ast[step].b = idx; g_ast[step].val = (unsigned)es;
                    g_ast[step].flags = 1;          /* pointer base -> deref */
                    g_ast[step].type = ety; g_ast[step].a = -1;
                    int head = ast_new(N_LV_CHAIN, op_line, op_col);
                    g_ast[head].c = -1;
                    g_ast[head].sym_lc = lc; g_ast[head].sym_gv = gv;
                    g_ast[head].b = step;
                    g_ast[head].type = ety; g_ast[head].struct_id = esid;
                    int n = ast_new(N_ADDR_LV_E, op_line, op_col);
                    g_ast[n].a = head;
                    g_ast[n].type = bt2;            /* &p[i] : T** */
                    g_ast[n].struct_id = esid;
                    while (amp_paren-- > 0) expect(TOK_RPAREN, "')'");
                    return n;
                }
                expect(TOK_LBRACKET, "'['");         /* &p[i][j] path */
                int idx2 = build_comma_entry();
                expect(TOK_RBRACKET, "']'");
                if (g_n_ast_kids + 1 > MAX_AST_KIDS)
                    die(op_line, op_col, "index kid pool overflow");
                int kid0 = g_n_ast_kids;
                g_ast_kids[g_n_ast_kids++] = idx;
                int base = ast_new(N_ARR_READ, op_line, op_col);
                g_ast[base].sym_lc = lc; g_ast[base].sym_gv = gv;
                g_ast[base].kid0 = kid0; g_ast[base].n_kids = 1;
                g_ast[base].type = ety;
                g_ast[base].struct_id = lc
                    ? lc->struct_id
                    : ((BTYPE(ety) == BT_STRUCT) ? gv->struct_id : -1);
                g_ast[base].fn_sig = lc ? lc->fn_sig_id : gv->fn_sig_id;
                int pn = ast_new(N_ADD_PPLUSI, op_line, op_col);
                g_ast[pn].a = base; g_ast[pn].b = idx2;
                g_ast[pn].val =
                    (unsigned)elem_size_for(ety, g_ast[base].struct_id);
                g_ast[pn].type = ety;
                g_ast[pn].struct_id = g_ast[base].struct_id;
                g_ast[pn].is_unsigned = g_ast[idx2].is_unsigned;
                while (amp_paren-- > 0) expect(TOK_RPAREN, "')'");
                return pn;
            }
        }
        int n = ast_new(N_ADDR_VAR, op_line, op_col);
        g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
        {
            LocalType ty = lc ? lc->type : gv->type;
            g_ast[n].type = ISARY(ty) ? INCREF(DECREF(ty), DERIV_PTR)
                                      : INCREF(ty, DERIV_PTR);
            g_ast[n].struct_id = lc ? lc->struct_id : gv->struct_id;
        }
        while (amp_paren-- > 0) expect(TOK_RPAREN, "')'");
        return n;
    }
    if (g_cur.kind == TOK_STAR) {
        int op_line = g_cur.line, op_col = g_cur.col;
        next_tok();
        if (g_cur.kind == TOK_IDENT) {
            Local *lc = locals_lookup(g_cur.id_ptr, g_cur.id_len);
            /* A long long pointee takes the general path, whose deref loads
             * all eight bytes; the fast paths below load two or four. */
            if (lc != NULL && BT_IS_QUAD(BTYPE(lc->type)))
                lc = NULL;
            if (lc != NULL) {
                int postfix = 0;
                {
                    LexPeek pk_lp;
                    lex_peek_save(&pk_lp);
                    next_tok();
                    postfix = (g_cur.kind == TOK_ARROW ||
                               g_cur.kind == TOK_LBRACKET ||
                               g_cur.kind == TOK_DOT);
                    lex_peek_restore(&pk_lp);
                }
                if (postfix) {
                    int a = build_unary_operand();
                    int n = ast_new(N_DEREF_GENERAL, op_line, op_col);
                    g_ast[n].a = a;
                    if (g_ast[a].type == LT_FN_PTR) {
                        g_ast[n].type = LT_FN_PTR;      /* designator: no-op */
                        g_ast[n].fn_sig = g_ast[a].fn_sig;
                    } else {
                        g_ast[n].type = deref_result_expr_type(DECREF(g_ast[a].type));
                        g_ast[n].struct_id = g_ast[a].struct_id;
                        g_ast[n].is_unsigned = g_ast[a].is_unsigned;   /* A-1 */
                    }
                    return n;
                }
                next_tok();                    /* consume IDENT (fast path) */
                if (g_cur.kind == TOK_PLUSPLUS || g_cur.kind == TOK_MINUSMINUS) {
                    int is_inc = (g_cur.kind == TOK_PLUSPLUS);
                    next_tok();
                    int st = elem_size_for(lc->type, lc->struct_id);
                    if (st == 0) st = 1;
                    int n = ast_new(N_DEREF_POSTINC, op_line, op_col);
                    g_ast[n].sym_lc = lc; g_ast[n].val = (unsigned)is_inc;
                    g_ast[n].val_hi = (unsigned)st;
                    g_ast[n].type = deref_result_expr_type(DECREF(lc->type));
                    g_ast[n].is_unsigned = lc->is_unsigned;
                    g_ast[n].struct_id = lc->struct_id;
                    return n;
                }
                if (lc->type == LT_FN_PTR) {
                    int n = ast_new(N_FNPTR_DESIG, op_line, op_col);
                    g_ast[n].sym_lc = lc;
                    g_ast[n].type = LT_FN_PTR;
                    g_ast[n].fn_sig = lc->fn_sig_id;
                    g_ast[n].is_unsigned = lc->is_unsigned;   /* from the load */
                    g_ast[n].struct_id = lc->struct_id;
                    return n;
                }
                /* `*arr` on a local ARRAY === `arr[0]`.  An array's frame slot
                 * IS the data (bank 0), not a stored far pointer — so
                 * N_DEREF_FAST/IR_DEREF_LOCAL would load the array bytes AS a
                 * far pointer (wrong offset+bank; the bank aliases a stale
                 * stack slot / far-return PB in multibank → wrong-bank read,
                 * FGX1-invisible).  Route through the proven indexed-read path
                 * with a synthetic index 0.  Struct-arrays need the struct-elem
                 * path (a '[' token) — leave them on the general/deref path. */
                if (lc->type == LT_CHAR_ARRAY || lc->type == LT_INT_ARRAY ||
                    lc->type == LT_LONG_ARRAY || lc->type == LT_FLOAT_ARRAY ||
                    is_ptr_array(lc->type)) {
                    if (g_n_ast_kids + 1 > MAX_AST_KIDS)
                        die(op_line, op_col, "index kid pool overflow");
                    int z = ast_new(N_LIT_INT, op_line, op_col);  /* index 0 */
                    int kid0 = g_n_ast_kids;
                    g_ast_kids[g_n_ast_kids++] = z;
                    int n = ast_new(N_ARR_READ, op_line, op_col);
                    g_ast[n].sym_lc = lc; g_ast[n].sym_gv = NULL;
                    g_ast[n].kid0 = kid0; g_ast[n].n_kids = 1;
                    set_arr_read_type(n, lc, NULL, 1, lc->n_dims);
                    return n;
                }
                int n = ast_new(N_DEREF_FAST, op_line, op_col);
                g_ast[n].sym_lc = lc;
                g_ast[n].type = deref_result_expr_type(DECREF(lc->type));
                g_ast[n].is_unsigned = lc->is_unsigned;
                g_ast[n].struct_id = lc->struct_id;
                return n;
            }
        }
        /* General path. */
        int a = build_unary_operand();
        int n = ast_new(N_DEREF_GENERAL, op_line, op_col);
        g_ast[n].a = a;
        if (g_ast[a].type == LT_FN_PTR) {
            g_ast[n].type = LT_FN_PTR;
            g_ast[n].fn_sig = g_ast[a].fn_sig;
        } else {
            g_ast[n].type = deref_result_expr_type(DECREF(g_ast[a].type));
            g_ast[n].struct_id = g_ast[a].struct_id;
            g_ast[n].is_unsigned = g_ast[a].is_unsigned;   /* A-1 */
        }
        return n;
    }
    /* POSTFIX ++/-- ON A RUN A READER BUILT.  K&R A.7.3.4: "A postfix
     * expression followed by a ++ or -- operator is a postfix expression" --
     * the operand is the WHOLE run, however many `.', `->' and `[' it took.
     * The member readers each bump one fixed shape and otherwise return a
     * load, leaving the operator unread: `s.a[i]++', `s.u.n++' and
     * `arr[i].m++' in value position all died at a missing ';' or ')'.
     * Where that happens after a named base, rewind to the base and build
     * the run with the uniform walker, which reaches every shape a reader
     * does and carries postfix's old value (AF_RET_OLD).  Only reachable
     * where the parse used to fail, so no spelling that compiles moves. */
    {
        LexPeek pk_run, pk_end;
        int op_at = named_run_incdec_at();
        lex_peek_save(&pk_run);
        int pn = build_primary_ast();
        /* g_cur is g_toks[g_tok_idx - 1]: past op_at means a reader took the
         * operator itself.  A reader can also stop SHORT of it, on a suffix it
         * does not walk (`s.p[i]++' with p a pointer member), so this keys on
         * the operator's position, not on what g_cur happens to be. */
        if (op_at < 0 || g_tok_idx - 1 > op_at)
            return pn;
        lex_peek_save(&pk_end);
        lex_peek_restore(&pk_run);
        int bn = build_named_run_postincdec();
        if (bn >= 0)
            return bn;
        lex_peek_restore(&pk_end);
        return pn;
    }
}

/* Peek (token-vector scan, no consume) from the current '.'/'->'/'[' suffix
 * token: does the postfix run terminate in an assignment op (=/op=)?  Used to
 * tell a computed-base member STORE (`lookup(*com)->flg |= x`, xec attrib) from
 * a read: the read chain (N_ARROW_CHAIN) only reads, so a store routes through
 * the uniform K&R walker.  K&R A.7.3.3: `E1->m` is an lvalue, A.7.17: any
 * modifiable lvalue is an assignment LHS. */
/* The same scan, for a run terminating in a COMPOUND operator only.  A plain
 * `=' is deliberately excluded: it stores through N_IPV_STORE, which walks the
 * base ONCE and is correct as it stands (apple/fgx#155). */
static int
value_chain_ends_in_compound_store(void)
{
    int i = g_tok_idx - 1;
    for (;;) {
        TokKind k = g_toks[i].kind;
        if (k == TOK_DOT || k == TOK_ARROW) { i += 2; continue; }
        if (k == TOK_LBRACKET) {
            int d = 1; i++;
            while (d && g_toks[i].kind != TOK_EOF) {
                if (g_toks[i].kind == TOK_LBRACKET) d++;
                else if (g_toks[i].kind == TOK_RBRACKET) d--;
                i++;
            }
            continue;
        }
        break;
    }
    return is_compound_op(g_toks[i].kind);
}

/* Set while the operand of a prefix `*' is being parsed.  K&R A.7.4: a
 * unary-expression is `unary-operator cast-expression', and A.7.17 puts the
 * assignment operators below every unary one, so an `=' after the operand
 * belongs to the expression the `*' heads: `*(q)->p = c' stores through
 * (q)->p (A.7.4.3, "returns the object ... to which its operand points"),
 * and A.7.2 makes the parenthesized `(q)' the same primary as `q'.  A store
 * chain must not absorb that `=' into the operand.  build_assign clears the
 * flag for every full expression nested inside the operand -- a parenthesized
 * group, an argument, a subscript -- and puts it back. */
static int g_unop_operand;

static int
build_unary_operand(void)
{
    int saved = g_unop_operand, r;

    g_unop_operand = 1;
    r = build_unary();
    g_unop_operand = saved;
    return r;
}

static int
value_chain_ends_in_store(void)
{
    int i = g_tok_idx - 1;                    /* the current suffix token */
    for (;;) {
        TokKind k = g_toks[i].kind;
        if (k == TOK_DOT || k == TOK_ARROW) { i += 2; continue; }
        if (k == TOK_LBRACKET) {
            int d = 1; i++;
            while (d && g_toks[i].kind != TOK_EOF) {
                if (g_toks[i].kind == TOK_LBRACKET) d++;
                else if (g_toks[i].kind == TOK_RBRACKET) d--;
                i++;
            }
            continue;
        }
        break;
    }
    TokKind fin = g_toks[i].kind;
    if (g_unop_operand)
        return 0;
    return (fin == TOK_EQ || is_compound_op(fin));
}

/* The same scan, for a run that terminates in '++'/'--' (apple/fgx#86).
 * `op->ip->n++` in VALUE position: the single-hop arms below take one member,
 * and a run whose first member is itself a struct pointer fell through to the
 * chain READER, which cannot bump anything.  K&R A.7.4.1 takes ++/-- on any
 * modifiable lvalue and says nothing about how many hops reached it. */
static int
value_chain_ends_in_incdec(void)
{
    int i = g_tok_idx - 1;                    /* the current suffix token */
    for (;;) {
        TokKind k = g_toks[i].kind;
        if (k == TOK_DOT || k == TOK_ARROW) { i += 2; continue; }
        if (k == TOK_LBRACKET) {
            int d = 1; i++;
            while (d && g_toks[i].kind != TOK_EOF) {
                if (g_toks[i].kind == TOK_LBRACKET) d++;
                else if (g_toks[i].kind == TOK_RBRACKET) d--;
                i++;
            }
            continue;
        }
        break;
    }
    TokKind fin = g_toks[i].kind;
    return (fin == TOK_PLUSPLUS || fin == TOK_MINUSMINUS);
}

/* Bump width for a ++/-- on an lvalue-chain LEAF (K&R A.7.4.1: `++E' is
 * `E += 1', and A.7.7 scales that 1 by the pointee for a pointer).
 *
 * This exists as one function because it was seven copies of
 * `ISPTR(lf) ? ptr_stride(lf) : 1' with `if (st == 0) st = 1;' under it --
 * and ptr_stride returns 0 for a STRUCT pointer by design, deferring that
 * case to elem_size_for, which needs the struct id.  So all seven turned
 * "I don't know" into "one byte" and `p->next++' walked a `struct foo *'
 * one byte at a time.  elem_size_for stops loudly instead. */
static int
incdec_stride(LocalType lf, int sid)
{
    if (!ISPTR(lf)) return 1;
    return elem_size_for(lf, sid);
}

/* The same scan from a base NAME (g_cur): the token index of the '++'/'--'
 * that ends its suffix run, or -1 when there is no run or it ends otherwise. */
static int
named_run_incdec_at(void)
{
    int i = g_tok_idx;                        /* the token after the NAME */
    if (g_cur.kind != TOK_IDENT)
        return -1;
    TokKind k0 = g_toks[i].kind;
    if (k0 != TOK_DOT && k0 != TOK_ARROW && k0 != TOK_LBRACKET)
        return -1;
    for (;;) {
        TokKind k = g_toks[i].kind;
        if (k == TOK_DOT || k == TOK_ARROW) { i += 2; continue; }
        if (k == TOK_LBRACKET) {
            int d = 1; i++;
            while (d && g_toks[i].kind != TOK_EOF) {
                if (g_toks[i].kind == TOK_LBRACKET) d++;
                else if (g_toks[i].kind == TOK_RBRACKET) d--;
                i++;
            }
            continue;
        }
        break;
    }
    TokKind fin = g_toks[i].kind;
    return (fin == TOK_PLUSPLUS || fin == TOK_MINUSMINUS) ? i : -1;
}

/* `NAME<suffix run>++' / `--' through the uniform walker, for build_unary's
 * postfix fallback.  g_cur is the base NAME.  Returns -1, consuming nothing
 * the caller has not saved, when the base is not a variable with a suffix
 * run or the walker's run does not end at the operator. */
static int
build_named_run_postincdec(void)
{
    if (g_cur.kind != TOK_IDENT)
        return -1;
    Local  *lc = locals_lookup(g_cur.id_ptr, g_cur.id_len);
    Global *gv = lc ? NULL : globals_lookup(g_cur.id_ptr, g_cur.id_len);
    TokKind nk = peek_tok().kind;
    if ((lc == NULL && gv == NULL) ||
        (nk != TOK_DOT && nk != TOK_ARROW && nk != TOK_LBRACKET))
        return -1;
    int line = g_cur.line, col = g_cur.col;
    next_tok();                                    /* consume base NAME */
    int head = ast_new(N_LV_CHAIN, line, col);
    g_ast[head].c = -1;                            /* named base */
    g_ast[head].sym_lc = lc; g_ast[head].sym_gv = gv;
    build_lvalue_suffixes(head, lc ? lc->type : gv->type,
                          lc ? lc->struct_id : gv->struct_id);
    if (g_cur.kind != TOK_PLUSPLUS && g_cur.kind != TOK_MINUSMINUS)
        return -1;
    LocalType lf = g_ast[head].type;
    require_assignable(lf, g_cur.kind);
    int is_inc = (g_cur.kind == TOK_PLUSPLUS);
    next_tok();                                    /* consume '++' / '--' */
    int nn = ast_new(N_LV_INCDEC_E, line, col);
    g_ast[nn].a         = head;
    g_ast[nn].val       = (unsigned)incdec_stride(lf, g_ast[head].struct_id);
    g_ast[nn].flags     = (is_inc ? AF_IS_INC : 0) | AF_RET_OLD;
    g_ast[nn].type      = lf;
    g_ast[nn].struct_id = g_ast[head].struct_id;
    g_ast[nn].is_unsigned = g_ast[head].is_unsigned;
    return nn;
}

/* The VALUE of a walker run (an N_LV_CHAIN head): a struct is its address,
 * which is what a struct value is in this compiler; an array is converted to
 * a pointer to its first element (K&R A.7.1, p.161: "the value of the
 * expression is a pointer to the first object in the array, and the type of
 * the expression is altered to ``pointer to T''"); anything else is loaded. */
static int
lv_chain_value(int head, int line, int col)
{
    LocalType lt = g_ast[head].type;
    int addr = (lt == LT_STRUCT || ISARY(lt));
    int n = ast_new(addr ? N_ADDR_LV_E : N_LV_LOAD_E, line, col);
    g_ast[n].a = head;
    g_ast[n].type = ISARY(lt) ? INCREF(DECREF(lt), DERIV_PTR) : lt;
    g_ast[n].struct_id = g_ast[head].struct_id;
    g_ast[n].is_unsigned = addr ? 0 : g_ast[head].is_unsigned;
    return n;
}

/* Wrap a value node in postfix-chain nodes: (expr)[i]..., (expr)->f...,
 * mixtures — the build twin of parse_primary's emit_index_ptr_value /
 * emit_arrow_chain loop, including the expression-context '=' store (G29).
 * Non-static: the statement dispatcher (parse_stmt.c) hands it a call node
 * when a chain follows the ')' of an IDENT-led call statement. */
int
build_postfix_value_chain(int base)
{
    for (;;) {
        /* `p->fn(args)` / `p->q->fn(args)` -- call THROUGH a function-pointer
         * value the chain just produced.  build_arrow_access (and the subscript
         * arms) hand their fn-ptr leaf here with fn_sig set, but the loop had
         * no call arm, so the following '(' was left unread and the parse died
         * "expected ';'".  `(p->fn)(args)` and `fp = p->fn; fp(args)` already
         * worked -- this is the DIRECT spelling, which is how a struct-member
         * method is normally called (joe's `w->watom->disp(w->object, flg)`
         * command dispatch, and every BSD ops-vector `->' call).  Built exactly
         * as the `arr[i].fn(args)` arm in build_dot_access, so the two spellings
         * emit one shape; the sig rides on the chain node (N_ARROW_LOAD_CHAIN /
         * N_ARROW_CHAIN both set it for an fn-ptr leaf). */
        if (g_cur.kind == TOK_LPAREN && g_ast[base].type == LT_FN_PTR &&
            g_ast[base].fn_sig >= 0) {
            int sig = g_ast[base].fn_sig;
            int op_line = g_cur.line, op_col = g_cur.col;
            next_tok();                    /* consume '(' */
            int kid0, n_kids;
            build_call_args(&kid0, &n_kids);
            expect(TOK_RPAREN, "')'");
            int cn = ast_new(N_CALL_STASHED, op_line, op_col);
            g_ast[cn].a = base;
            g_ast[cn].kid0 = kid0; g_ast[cn].n_kids = n_kids;
            g_ast[cn].val = (unsigned)sig;
            g_ast[cn].type = g_fn_sigs[sig].return_type;
            g_ast[cn].is_unsigned = g_fn_sigs[sig].ret_unsigned;
            g_ast[cn].fn_sig = -1;
            base = cn;
            continue;
        }
        if (g_cur.kind == TOK_LBRACKET && ISPTR(g_ast[base].type)) {
            /* Computed-base index ++/--: `ivec()[i]++'.  Same A.7.3 production
             * as the arrow case below, and it goes through the uniform walker
             * for the same reason: the N_IPV_* nodes read or store, and a
             * postfix bump has to do both AND yield the OLD value.  The walker
             * is entered with the POINTER type (not DECREF'd, unlike the arrow
             * arm) because an index step derefs its own operand, and the whole
             * suffix run is parsed there, so this must peek BEFORE the '['. */
            /* `f()[i] OP= rhs' -- a COMPUTED base with a compound operator.
             * The old rewrite `base[i] = base[i] OP rhs' put the base node in
             * the tree TWICE, so it was WALKED twice: `ivec()[1] += 1' emitted
             * the call twice (K&R A.7.17: "E1 is evaluated only once"), and
             * with a pointer element the second walk freed the base's register
             * out of order and the compiler stopped with an internal
             * "non-LIFO register free".  The uniform walker computes the
             * address ONCE, which is the whole point of it (apple/fgx#155).
             * A plain `=' keeps N_IPV_STORE: it uses the base once already. */
            /* `&f()[i]...' -- '&' of a computed-base subscript.  K&R
             * A.7.4.2: "The operand must be an lvalue referring neither to a
             * bit-field nor to an object declared as register"; E1[E2] is
             * *((E1)+(E2)) (A.7.3.1), and A.7.4.3 makes `*' of a pointer to an
             * object an lvalue, whatever computed E1.  The walker's address is
             * the result, as for `&f()->m' in the arrow arm below, entered
             * with the array form of the base type for the reason the ++/--
             * arm gives.  The flag is cleared before the index is parsed, so a
             * chain inside it cannot see the flag. */
            if (g_addr_of_chain) {
                int ln = g_cur.line, cl = g_cur.col;
                g_addr_of_chain = 0;
                int head = ast_new(N_LV_CHAIN, ln, cl);
                g_ast[head].c = base;              /* computed pointer base */
                g_ast[head].sym_lc = NULL; g_ast[head].sym_gv = NULL;
                build_lvalue_suffixes(head,
                                      INCREF(DECREF(g_ast[base].type), DERIV_ARY),
                                      g_ast[base].struct_id);
                int an = ast_new(N_ADDR_LV_E, ln, cl);
                g_ast[an].a = head;
                g_ast[an].type = (g_ast[head].type == LT_STRUCT)
                               ? LT_STRUCT_PTR
                               : INCREF(g_ast[head].type, DERIV_PTR);
                g_ast[an].struct_id = g_ast[head].struct_id;
                return an;
            }
            if (value_chain_ends_in_compound_store()) {
                int ln = g_cur.line, cl = g_cur.col;
                int head = ast_new(N_LV_CHAIN, ln, cl);
                g_ast[head].c = base;              /* computed pointer base */
                g_ast[head].sym_lc = NULL; g_ast[head].sym_gv = NULL;
                build_lvalue_suffixes(head,
                                      INCREF(DECREF(g_ast[base].type), DERIV_ARY),
                                      g_ast[base].struct_id);
                require_assignable(g_ast[head].type, g_cur.kind);
                TokKind cop = g_cur.kind;          /* the `op=' token */
                next_tok();
                int crhs = build_assign();         /* right-assoc */
                int nn = ast_new(N_LV_STORE_E, ln, cl);
                g_ast[nn].a = head; g_ast[nn].op = cop; g_ast[nn].c = crhs;
                g_ast[nn].type = g_ast[head].type;
                g_ast[nn].struct_id = g_ast[head].struct_id;
                return nn;
            }
            if (value_chain_ends_in_incdec() || g_preincdec_chain) {
                int ln = g_cur.line, cl = g_cur.col;
                int pfx = g_preincdec_chain;      /* prefix: '++' is behind us */
                g_preincdec_chain = 0;            /* consume-once */
                int head = ast_new(N_LV_CHAIN, ln, cl);
                g_ast[head].c = base;              /* computed pointer base */
                g_ast[head].sym_lc = NULL; g_ast[head].sym_gv = NULL;
                /* Enter the walker with the ARRAY form of the base type, not
                 * the pointer form.  emit_lvalue_addr seeds a computed base
                 * with the pointer's VALUE, so an index step flagged
                 * "pointer base" would deref it a second time -- the very
                 * shape this issue is about.  A pointer value used as an index
                 * base behaves exactly like an array name (K&R A.7.3.1:
                 * E1[E2] is *((E1)+(E2))), so say that in the type and the
                 * walker's array path is already correct. */
                build_lvalue_suffixes(head,
                                      INCREF(DECREF(g_ast[base].type), DERIV_ARY),
                                      g_ast[base].struct_id);
                LocalType lf = g_ast[head].type;
                require_assignable(lf, TOK_PLUSPLUS);
                int is_inc;
                if (pfx) {
                    is_inc = (pfx > 0);
                } else {
                    is_inc = (g_cur.kind == TOK_PLUSPLUS);
                    next_tok();                    /* consume '++' / '--' */
                }
                int st2 = incdec_stride(lf, g_ast[head].struct_id);
                int nn = ast_new(N_LV_INCDEC_E, ln, cl);
                g_ast[nn].a         = head;
                g_ast[nn].val       = (unsigned)st2;
                g_ast[nn].flags     = (is_inc ? AF_IS_INC : 0) |
                                      (pfx ? 0 : AF_RET_OLD);
                g_ast[nn].type      = lf;
                g_ast[nn].struct_id = g_ast[head].struct_id;
                base = nn;
                continue;
            }
            /* A STRUCT-POINTER BASE (apple/fgx#201).  `((struct cblock *)cp)
             * [-1].c_next' -- 2.11BSD tty_subr.c's nextc.
             *
             * ipv_elem_size below CANNOT answer for this base: ptr_stride
             * returns 0 for a struct pointer by design, because the stride is
             * sizeof(the struct) and only elem_size_for has the struct_id to
             * ask.  Its die() is the #166 guard, and its own comment says the
             * arm is unreachable "and that is exactly why it is worth arming:
             * ... a parser relaxation would silently turn it into a wild
             * pointer."  This is that relaxation, so it goes the way the guard
             * asks rather than round it.
             *
             * The uniform lvalue walker has the struct_id and computes the
             * element address once -- the same route the ++/-- and compound
             * arms above already take for a computed base, entered with the
             * ARRAY form of the type for the reason spelled out there.  A
             * NAMED struct-pointer base (`bp[-1].c_next') has always worked;
             * what had no arm was a COMPUTED one, which a cast makes.
             *
             * K&R A.7.3.1: E1[E2] is *((E1)+(E2)), and A.7.7 gives the sum a
             * pointer's own scaling -- nothing there distinguishes a named
             * operand from a cast one. */
            if (g_ast[base].type == LT_STRUCT_PTR && g_ast[base].struct_id >= 0) {
                int ln = g_cur.line, cl = g_cur.col;
                int head = ast_new(N_LV_CHAIN, ln, cl);
                g_ast[head].c = base;              /* computed pointer base */
                g_ast[head].sym_lc = NULL; g_ast[head].sym_gv = NULL;
                build_lvalue_suffixes(head,
                                      INCREF(DECREF(g_ast[base].type), DERIV_ARY),
                                      g_ast[base].struct_id);
                /* `op=' and `++'/`--' were routed above, so `=' is the one
                 * assignment operator that can be sitting here. */
                if (g_cur.kind == TOK_EQ) {
                    require_assignable(g_ast[head].type, TOK_EQ);
                    next_tok();                    /* consume '=' */
                    int rhs = build_assign();      /* right-assoc */
                    int nn = ast_new(N_LV_STORE_E, ln, cl);
                    g_ast[nn].a = head; g_ast[nn].op = TOK_EQ; g_ast[nn].c = rhs;
                    g_ast[nn].type = g_ast[head].type;
                    g_ast[nn].struct_id = g_ast[head].struct_id;
                    return nn;
                }
                base = lv_chain_value(head, ln, cl);
                continue;
            }
            LocalType pt = g_ast[base].type;
            int es = ipv_elem_size(pt);
            int op_line = g_cur.line, op_col = g_cur.col;
            next_tok();                    /* consume '[' */
            int idx = build_comma_entry(); /* parse_expr level */
            expect(TOK_RBRACKET, "']'");
            if (g_cur.kind == TOK_EQ) {    /* G29 expression-context store */
                next_tok();                /* consume '=' */
                int rhs = build_comma_entry();
                int n = ast_new(N_IPV_STORE, op_line, op_col);
                g_ast[n].a = base; g_ast[n].b = idx; g_ast[n].c = rhs;
                g_ast[n].val = (unsigned)es;
                g_ast[n].val_hi = (unsigned)pt;
                g_ast[n].type = (pt == LT_LONG_PTR)  ? LT_LONG
                              : (pt == LT_FLOAT_PTR) ? LT_FLOAT
                              : (pt == LT_LLONG_PTR) ? LT_LLONG
                              : (pt == LT_DOUBLE_PTR) ? LT_DOUBLE
                              : (es == 1)            ? LT_CHAR : LT_INT;
                return n;                  /* store ends the chain */
            }
            if (is_compound_op(g_cur.kind)) {
                /* base[idx] OP= rhs  ->  base[idx] = base[idx] OP rhs (FD_SET's
                 * fds_bits[0]).  ponytail: an index with side effects would
                 * double-evaluate; fine for the constant/simple indices here. */
                LocalType elty = (pt == LT_LONG_PTR)  ? LT_LONG
                               : (pt == LT_FLOAT_PTR) ? LT_FLOAT
                               : (pt == LT_LLONG_PTR) ? LT_LLONG
                               : (pt == LT_DOUBLE_PTR) ? LT_DOUBLE
                               : (es == 1)            ? LT_CHAR : LT_INT;
                TokKind bop = compound_base_op(g_cur.kind);
                next_tok();                /* consume 'OP=' */
                int rhs = build_comma_entry();
                int rd = ast_new(N_IPV_READ, op_line, op_col);
                g_ast[rd].a = base; g_ast[rd].b = idx;
                g_ast[rd].val = (unsigned)es; g_ast[rd].val_hi = (unsigned)pt;
                g_ast[rd].type = elty;
                int bn = ast_new(N_BINOP, op_line, op_col);
                g_ast[bn].a = rd; g_ast[bn].b = rhs; g_ast[bn].op = bop;
                ast_type_scalar_binop(bn, 0, elty, 0,
                                      g_ast[rhs].type, g_ast[rhs].is_unsigned);
                int n = ast_new(N_IPV_STORE, op_line, op_col);
                g_ast[n].a = base; g_ast[n].b = idx; g_ast[n].c = bn;
                g_ast[n].val = (unsigned)es; g_ast[n].val_hi = (unsigned)pt;
                g_ast[n].type = elty;
                return n;
            }
            int n = ast_new(N_IPV_READ, op_line, op_col);
            g_ast[n].a = base; g_ast[n].b = idx;
            g_ast[n].val = (unsigned)es;
            g_ast[n].val_hi = (unsigned)pt;
            {
                tword elem = DECREF(pt);
                if (ISPTR(elem))                       g_ast[n].type = elem;
                else if (pt == LT_LONG_PTR)            g_ast[n].type = LT_LONG;
                else if (pt == LT_FLOAT_PTR)           g_ast[n].type = LT_FLOAT;
                else if (pt == LT_LLONG_PTR)           g_ast[n].type = LT_LLONG;
                else if (pt == LT_DOUBLE_PTR)          g_ast[n].type = LT_DOUBLE;
                else                                   g_ast[n].type = (es == 1) ? LT_CHAR : LT_INT;
            }
            g_ast[n].fn_sig = g_ast[base].fn_sig;      /* untouched by the read */
            base = n;
            continue;
        }
        if (g_cur.kind == TOK_ARROW && g_ast[base].type == LT_STRUCT_PTR &&
            (peek_chain_dot_bridges() ||
             peek_arrow_ptrarr_index(g_ast[base].struct_id))) {
            /* Mid-chain-dot read (`t->L.T_dcar->t_dflg`): the pure-arrow chain
             * reader below cannot bridge a `.` to a further `->`/`[`.  Route the
             * whole run through the uniform K&R walker with the COMPUTED pointer
             * base -- emit_lvalue_addr treats the first `->` on a pointer value
             * as an offset (no deref); lv_chain_value gives the leaf's value. */
            int op_line = g_cur.line, op_col = g_cur.col;
            int head = ast_new(N_LV_CHAIN, op_line, op_col);
            g_ast[head].c = base;                 /* computed pointer base */
            g_ast[head].sym_lc = NULL; g_ast[head].sym_gv = NULL;
            build_lvalue_suffixes(head, DECREF(g_ast[base].type),
                                  g_ast[base].struct_id);
            base = lv_chain_value(head, op_line, op_col);
            continue;
        }
        /* Computed-base '->' on a NON-struct pointer: the K&R 1st-ed global-
         * member pun (A.7.3) with a COMPUTED base.  2.11BSD sh service.c:
         * `(argp=endstak(argp))->argval` (argp a char*).  Resolve the member
         * in the global namespace and coerce the base VALUE's type to the
         * owning struct pointer -- the struct-ptr arrow logic below then drives
         * it (the byte address is unchanged; only the compile-time type is). */
        if (g_cur.kind == TOK_ARROW && ISPTR(g_ast[base].type) &&
            g_ast[base].type != LT_STRUCT_PTR) {
            LexPeek pk;
            lex_peek_save(&pk);
            next_tok();                        /* peek past '->' */
            int csid = -1;
            if (g_cur.kind == TOK_IDENT)
                field_lookup_global(g_cur.id_ptr, g_cur.id_len, &csid);
            lex_peek_restore(&pk);             /* back to '->' */
            if (csid >= 0) {
                g_ast[base].type = LT_STRUCT_PTR;
                g_ast[base].struct_id = csid;
            }
        }
        if (g_cur.kind == TOK_ARROW && g_ast[base].type == LT_STRUCT_PTR) {
            /* Computed-base arrow STORE (K&R A.7.3.3: the '->' result is an
             * lvalue): `lookup(*com)->flg |= exitval` (xec, attrib macro).  The
             * read chain below only reads; a store routes through the uniform
             * walker with the computed pointer base (head.c=base) + N_LV_STORE_E. */
            /* `&<computed base>-><chain>` -- the walker's address fpr IS the
             * result (K&R A.7.4.2), so the same head that serves a store also
             * serves '&'.  Consumed here so a nested chain inside the arguments
             * cannot see the flag. */
            if (g_addr_of_chain) {
                int op_line = g_cur.line, op_col = g_cur.col;
                g_addr_of_chain = 0;
                int head = ast_new(N_LV_CHAIN, op_line, op_col);
                g_ast[head].c = base;                 /* computed pointer base */
                g_ast[head].sym_lc = NULL; g_ast[head].sym_gv = NULL;
                build_lvalue_suffixes(head, DECREF(g_ast[base].type),
                                      g_ast[base].struct_id);
                int an = ast_new(N_ADDR_LV_E, op_line, op_col);
                g_ast[an].a = head;
                /* A struct-VALUE leaf is fine here, unlike the store case: '&'
                 * never derefs the leaf, it just stops at the address the
                 * walker already computed.  tcsh's Hlex IS an embedded
                 * `struct wordent`, so `&f(...)->Hlex` yields wordent *. */
                g_ast[an].type = (g_ast[head].type == LT_STRUCT)
                               ? LT_STRUCT_PTR
                               : INCREF(g_ast[head].type, DERIV_PTR);
                g_ast[an].struct_id = g_ast[head].struct_id;
                return an;
            }
            if (value_chain_ends_in_store()) {
                int op_line = g_cur.line, op_col = g_cur.col;
                int head = ast_new(N_LV_CHAIN, op_line, op_col);
                g_ast[head].c = base;                 /* computed pointer base */
                g_ast[head].sym_lc = NULL; g_ast[head].sym_gv = NULL;
                build_lvalue_suffixes(head, DECREF(g_ast[base].type),
                                      g_ast[base].struct_id);
                /* A struct leaf with `=' is a copy, which N_LV_STORE_E
                 * performs for a computed base exactly as for a named one. */
                require_assignable(g_ast[head].type, g_cur.kind);
                TokKind op = g_cur.kind;              /* TOK_EQ or op= */
                next_tok();                           /* consume =/op= */
                int rhs = build_assign();             /* right-assoc */
                int nn = ast_new(N_LV_STORE_E, op_line, op_col);
                g_ast[nn].a = head; g_ast[nn].op = op; g_ast[nn].c = rhs;
                g_ast[nn].type = g_ast[head].type;
                g_ast[nn].struct_id = g_ast[head].struct_id;
                return nn;
            }
            /* Prefix twin of the postfix arm below: the '++' is BEHIND us, so
             * it arrives as a one-shot flag rather than a forward peek. */
            if (g_preincdec_chain) {
                int op_line = g_cur.line, op_col = g_cur.col;
                int inc = (g_preincdec_chain > 0);
                g_preincdec_chain = 0;            /* consume-once */
                int head = ast_new(N_LV_CHAIN, op_line, op_col);
                g_ast[head].c = base;
                g_ast[head].sym_lc = NULL; g_ast[head].sym_gv = NULL;
                build_lvalue_suffixes(head, DECREF(g_ast[base].type),
                                      g_ast[base].struct_id);
                LocalType lf = g_ast[head].type;
                require_assignable(lf, TOK_PLUSPLUS);
                int st = incdec_stride(lf, g_ast[head].struct_id);
                int nn = ast_new(N_LV_INCDEC_E, op_line, op_col);
                g_ast[nn].a         = head;
                g_ast[nn].val       = (unsigned)st;
                g_ast[nn].flags     = inc ? AF_IS_INC : 0;   /* NEW value */
                g_ast[nn].type      = lf;
                g_ast[nn].struct_id = g_ast[head].struct_id;
                return nn;
            }
            /* Computed-base arrow ++/--: `lookup(n)->m++', `ivec()[i]->m--'.
             * K&R A.7.3 lists `postfix-expression ++' in the same left-to-right
             * production as `->' and the call itself, so a chain reached through
             * a computed base bumps exactly like one reached through a name --
             * the named-base twin is in build_dot_access.  Without this the run
             * fell to the chain READER below, which loads and cannot bump, and
             * the '++' was left unconsumed and reported as a missing ';'. */
            if (value_chain_ends_in_incdec()) {
                int op_line = g_cur.line, op_col = g_cur.col;
                int head = ast_new(N_LV_CHAIN, op_line, op_col);
                g_ast[head].c = base;                 /* computed pointer base */
                g_ast[head].sym_lc = NULL; g_ast[head].sym_gv = NULL;
                build_lvalue_suffixes(head, DECREF(g_ast[base].type),
                                      g_ast[base].struct_id);
                LocalType lf = g_ast[head].type;
                require_assignable(lf, TOK_PLUSPLUS);
                int is_inc = (g_cur.kind == TOK_PLUSPLUS);
                next_tok();                           /* consume '++' / '--' */
                int st = incdec_stride(lf, g_ast[head].struct_id);
                int nn = ast_new(N_LV_INCDEC_E, op_line, op_col);
                g_ast[nn].a         = head;
                g_ast[nn].val       = (unsigned)st;
                g_ast[nn].flags     = (is_inc ? AF_IS_INC : 0) | AF_RET_OLD;
                g_ast[nn].type      = lf;
                g_ast[nn].struct_id = g_ast[head].struct_id;
                base = nn;
                continue;
            }
            int op_line = g_cur.line, op_col = g_cur.col;
            int hop0 = g_n_ast_fields, n_hops = 0;
            int cur_sid = g_ast[base].struct_id;
            LocalType leaf_ty = LT_INT; int leaf_sid = -1;
            int to_walker = 0;
            LexPeek pk_run;
            lex_peek_save(&pk_run);                /* at the first '->' */
            for (;;) {
                next_tok();                /* consume '->' */
                if (g_cur.kind != TOK_IDENT)
                    die(g_cur.line, g_cur.col, "expected field name after '->'");
                Field *f = struct_field_lookup(cur_sid, g_cur.id_ptr, g_cur.id_len);
                if (f == NULL) die(g_cur.line, g_cur.col, "no such field");
                next_tok();
                if (g_n_ast_fields >= MAX_AST_KIDS)
                    die(g_cur.line, g_cur.col, "arrow-chain hop pool overflow");
                g_ast_fields[g_n_ast_fields++] = f; n_hops++;
                if (f->type == LT_CHAR_ARRAY || f->type == LT_INT_ARRAY ||
                    f->type == LT_LONG_ARRAY) {
                    leaf_ty = (f->type == LT_CHAR_ARRAY) ? LT_CHAR_PTR
                            : (f->type == LT_INT_ARRAY)  ? LT_INT_PTR
                                                         : LT_LONG_PTR;
                    leaf_sid = -1;
                    break;
                }
                if (f->type == LT_STRUCT_ARRAY || f->type == LT_FLOAT_ARRAY) {
                    to_walker = 1;
                    break;
                }
                leaf_ty = f->type; leaf_sid = f->struct_id;
                if (f->type == LT_STRUCT_PTR && g_cur.kind == TOK_ARROW) {
                    cur_sid = f->struct_id;
                    continue;
                }
                /* ...AND THROUGH AN EMBEDDED STRUCT VIA '.', which is the same
                 * production and was the missing one (apple/fgx#189).  K&R
                 * A.7.3.3: "A postfix expression followed by a dot followed by
                 * an identifier is a postfix expression.  The first operand
                 * expression must be a structure or a union" -- and the arrow
                 * paragraph above it makes E1->MOS a postfix expression too.
                 * So `E->m.n' is the dot production applied to the arrow
                 * production's RESULT, with no condition on how that result
                 * was spelled.  Ending the run here left `.n' unconsumed and
                 * the caller reported "expected ')'".
                 *
                 * The loop's next_tok() consumes whichever operator is
                 * current, so the '.' needs no separate arm -- only this
                 * continuation and the walker's matching offset step.
                 *
                 * WHY ONLY THE COMPUTED BASE WAS AFFECTED: an IDENT base
                 * reaches build_arrow_access, whose result carries sym_lc/
                 * sym_gv, and the TOK_DOT arm at the foot of this loop
                 * re-enters build_dot_access on it.  A computed base has no
                 * symbol, so it fell past that arm to the break.  `p->in.hi'
                 * worked and `(p)->in.hi' did not, though A.7.3.3's note
                 * "the expression E1->MOS is the same as (*E1).MOS" says they
                 * are the same expression. */
                if (f->type == LT_STRUCT && g_cur.kind == TOK_DOT) {
                    cur_sid = f->struct_id;
                    continue;
                }
                break;
            }
            /* N_ARROW_CHAIN LOADS its leaf.  A struct leaf's value is its
             * address and a struct or float array member has no reader arm,
             * so either run goes to the walker from the first '->'. */
            if (to_walker || leaf_ty == LT_STRUCT) {
                lex_peek_restore(&pk_run);
                g_n_ast_fields = hop0;
                int head = ast_new(N_LV_CHAIN, op_line, op_col);
                g_ast[head].c = base;              /* computed pointer base */
                g_ast[head].sym_lc = NULL; g_ast[head].sym_gv = NULL;
                build_lvalue_suffixes(head, DECREF(g_ast[base].type),
                                      g_ast[base].struct_id);
                base = lv_chain_value(head, op_line, op_col);
                continue;
            }
            int n = ast_new(N_ARROW_CHAIN, op_line, op_col);
            g_ast[n].a = base;
            g_ast[n].kid0 = hop0; g_ast[n].n_kids = n_hops;
            g_ast[n].type = leaf_ty;
            g_ast[n].struct_id = leaf_sid;
            g_ast[n].is_unsigned = 0;      /* leaf load resets via helpers */
            /* A chain ENDING IN A FUNCTION POINTER carries that field's
             * signature, which is what makes the value callable.  Inheriting
             * the base's fn_sig instead (as this did) left it at -1, and the
             * only symptom was that `(*(vp)->v_op->vn_x)(...)` -- a
             * PARENTHESIZED base, which is how every BSD VOP_/VFS_ macro is
             * spelled -- fell out of the fn-ptr call arm and died "expected
             * ';'".  The unparenthesized `(*vp->v_op->vn_x)(...)` worked
             * because an IDENT base takes a different path that already read
             * the field.  The base's own fn_sig is meaningless here: a chain
             * whose leaf is not a fn-ptr has no signature to carry. */
            g_ast[n].fn_sig = (leaf_ty == LT_FN_PTR)
                            ? g_ast_fields[hop0 + n_hops - 1]->fn_sig_id
                            : g_ast[base].fn_sig;
            base = n;
            continue;
        }
        /* `.m' ON A COMPUTED STRUCT VALUE -- `(s = t).m', `(c ? s : t).m'.
         * K&R A.7.3.3 (p.163) asks only that "the first operand expression
         * must be a structure or a union": a value, not an lvalue.  A struct
         * value in this compiler is its address, so the walker reads the
         * member through it as it would through a pointer.  That includes a
         * parenthesized MEMBER, `(s.m).f' or `(p->m).f': the value carries the
         * member's own address, which is not its base symbol's.  The result is
         * not an lvalue when the first operand is not one, so a run ending in
         * an assignment operator is left unclaimed for the caller to refuse. */
        if (g_cur.kind == TOK_DOT && g_ast[base].type == LT_STRUCT &&
            g_ast[base].struct_id >= 0 && g_ast[base].kind != N_VAR_LOAD &&
            !value_chain_ends_in_store() && !value_chain_ends_in_incdec()) {
            int op_line = g_cur.line, op_col = g_cur.col;
            int head = ast_new(N_LV_CHAIN, op_line, op_col);
            g_ast[head].c = base;                 /* the value IS the address */
            build_lvalue_suffixes(head, LT_STRUCT, g_ast[base].struct_id);
            base = lv_chain_value(head, op_line, op_col);
            continue;
        }
        /* (lvalue).field — member access on a PARENTHESIZED struct lvalue.
         * The bare-lvalue path handles `s.f` in parse_primary, but a
         * redundant paren (`(s).f`, common in BSD macros like
         * ISDIR(st)==((st).st_mode&...)) routes s through build_comma into a
         * value node that stops short of the '.'.  When that value is a
         * whole struct VARIABLE, re-enter build_dot_access on it -- it
         * produces the same N_DOT_SCALAR chain (incl. nested '.'/'['/'->'), so
         * control need not return here.  Only a variable: a member value
         * carries its base symbol too, but its address is not the symbol's. */
        if (g_cur.kind == TOK_DOT && g_ast[base].type == LT_STRUCT &&
            g_ast[base].kind == N_VAR_LOAD) {
            return build_dot_access(g_ast[base].sym_lc, g_ast[base].sym_gv,
                                    g_ast[base].struct_id,
                                    g_cur.line, g_cur.col);
        }
        break;
    }
    return base;
}

/* Build the argument list of a call into the kid pool.  The build twin of
 * emit_call_marshal_args' PARSE side; the walker twin below replays the
 * weight/push decisions from the arg nodes' types. */
static void
build_call_args(int *kid0, int *n_kids)
{
    int tmp[MAX_LOCALS * 2];
    int cnt = 0;
    if (g_cur.kind != TOK_RPAREN) {
        for (;;) {
            if (cnt >= MAX_LOCALS * 2)
                die(g_cur.line, g_cur.col, "too many call arguments");
            tmp[cnt++] = build_assign();
            if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
            break;
        }
    }
    if (g_n_ast_kids + cnt > MAX_AST_KIDS)
        die(g_cur.line, g_cur.col, "call-arg kid pool overflow");
    /* Capture the span AFTER building: a nested call inside an argument
     * appends its own kid span during the collect loop above. */
    *kid0 = g_n_ast_kids;
    for (int i = 0; i < cnt; i++) g_ast_kids[g_n_ast_kids++] = tmp[i];
    *n_kids = cnt;
}

/* Walk twin of emit_call_marshal_args: replay each argument subtree and its
 * push glue, with the weight decisions from the arg NODES' types (the same
 * values runtime g_expr_type held after each parse_expr).  Returns
 * total_arg_bytes. */
static int
walk_call_args(int kid0, int n_kids, const LocalType *ptypes,
               const int *pstruct_ids, int n_declared, int n_fixed,
               RtlArgs *rtl, int *out_argc)
{
    int actual_argc = 0, total_arg_bytes = 0;
    for (int i = 0; i < n_kids; i++) {
        /* RTL callee: walk args in REVERSE source order (arg[n-1] first,
         * arg0 last/shallowest) — offsets bake at their true depth, no
         * post-hoc reversal (T5-C C5).  idx = the arg's SOURCE position
         * (drives the declared-param type coercion either way). */
        int idx = rtl->active ? (n_kids - 1 - i) : i;
        int arg = g_ast_kids[kid0 + idx];
        walk_expr(arg);
        int ks = g_fpr_res;               /* FPR result (new walker), or -1 */
        g_fpr_res = -1;
        LocalType at = g_ast[arg].type;   /* walker purity: decisions from the
                                           * node, not runtime g_expr_* (proven
                                           * equal by the FCC_AST_CHECK sweep) */
        /* Whether this argument goes out as its parameter's type.  Past the
         * fixed parameters of a lint VARARGSn definition it does not when
         * that would NARROW it: K&R A.7.3.2, "trailing arguments beyond the
         * explicitly typed parameters suffer default argument promotion", so
         * a long, a long long or a pointer is pushed at its own width.  Such
         * a function forwards its slots to printf -- fsck's pwarn(s, a1, ...,
         * a8) -- and a narrowed `%ld' or `%s' printed garbage (apple/fgx#549).
         * Widening still happens there, so an int passed for a pointer slot
         * cannot shift the frame. */
        int decl = idx < n_declared &&
                   !(n_fixed >= 0 && idx >= n_fixed &&
                     (ptypes[idx] == LT_INT || ptypes[idx] == LT_CHAR) &&
                     (at == LT_LONG || at == LT_LLONG ||
                      is_ptr_type(at) || ISARY(at)));
        /* A floating argument with no parameter to receive it -- past `...'
         * or through an old-style declaration -- is how a float reaches
         * printf, so this program needs libc's float printer (main.c). */
        if (!decl && (at == LT_FLOAT || at == LT_DOUBLE))
            g_fltused = 1;
        if (decl && pstruct_ids != NULL &&
            ptypes[idx] == LT_STRUCT) {
            int psid = pstruct_ids[idx];
            int nb = (g_structs[psid].total_size + 1) & ~1;
            /* By-value copy on FPRs (P3-2.4, retires the arg copy's
             * _fcc_ptr2 staging): src = the walked &struct (struct
             * values stay carrier-carried until 2.5), dest = a
             * reserved HW-stack window (bank 0). */
            int kd;
            if (ks < 0) { ks = fpr_alloc(); emit_fpr_from_carrier(ks); }
            kd = fpr_alloc();
            emit_fpr_arg_window(kd, nb);
            emit_fpr_struct_copy(kd, ks, nb);
            fpr_drop(kd);
            fpr_drop(ks);
            ks = -1;
            g_s_delta += nb;
            total_arg_bytes += nb;
            rtl_note_struct(rtl);
        } else if ((decl &&
                    is_ptr_type(ptypes[idx])) ||
                   (!decl && is_ptr_type(at))) {
            /* 4-byte pointer arg: PEI pair from the FPR.  An int-valued arg
             * for a pointer param is the same ITP conversion as a store (ccom
             * c01.c makes no distinction between argument passing, assignment
             * and cast), so it takes the same bank: NULL and other constants
             * stay bank 0, a runtime integer becomes DBR.  Getting this wrong
             * launders bank 0 THROUGH an otherwise-correct callee store. */
            if (ks < 0) {
                ks = fpr_alloc();
                fpr_from_walked(ks, arg);
            }
            emit_fpr_push(ks);
            fpr_drop(ks);
            ks = -1;
            total_arg_bytes += 4;
        } else if (decl && at == LT_DOUBLE &&
                   ptypes[idx] != LT_DOUBLE) {
            /* A.7.3.2: converted "as if by assignment" to the parameter. */
            emit_from_double(ptypes[idx]);
            if (ptypes[idx] == LT_LONG || ptypes[idx] == LT_FLOAT) {
                emit_push_long();
                total_arg_bytes += 4;
            } else {
                emit_push_a();
                total_arg_bytes += 2;
            }
        } else if (decl && IS_QUAD(ptypes[idx])) {
            if (ks >= 0) { emit_fpr_to_a(ks); fpr_drop(ks); ks = -1; }
            g_expr_type = at;
            emit_to_quad(ptypes[idx]);
            emit_push_llong();
            total_arg_bytes += 8;
        } else if (!decl && IS_QUAD(at)) {
            emit_push_llong();
            total_arg_bytes += 8;
        } else if (decl &&
                   ptypes[idx] == LT_LONG) {
            /* A pointer argument converts as a cast does (A.6.6: "A pointer
             * may be converted to an integral type large enough to hold it";
             * the mapping is implementation-defined, and fcc's is the N_CAST
             * one): offset low, BANK high.  Through the int route the bank
             * was lost -- elvis's msg(fmt, long...) %s read bank 0. */
            int ptr_long = ks >= 0 && (is_ptr_type(at) || ISARY(at));
            if (ptr_long) {
                fpr_sym_flush(ks);
                ir_emitf("                LDA     %s+2\n", fpr_name(ks));
                ir_emitf("                STA     _fcc_long_hi\n");
            }
            if (ks >= 0) { emit_fpr_to_a(ks); fpr_drop(ks); ks = -1; }
            /* K&R A.7.3.2: "the arguments are converted, as if by
             * assignment, to the types of the corresponding parameters".
             * A long long narrows for free: w0 and w1 are already a long. */
            if (ptr_long)           ;
            else if (at == LT_FLOAT) emit_float_to_long();
            else if (at != LT_LONG && at != LT_LLONG) emit_promote_a_to_long();
            emit_push_long();
            total_arg_bytes += 4;
        } else if (decl &&
                   ptypes[idx] == LT_FLOAT) {
            if (ks >= 0) { emit_fpr_to_a(ks); fpr_drop(ks); ks = -1; }
            if (at == LT_LONG)       emit_long_to_float();
            else if (at != LT_FLOAT) emit_int_to_float();
            emit_push_long();
            total_arg_bytes += 4;
        } else if (!decl && at == LT_FLOAT && IS_QUAD(LT_DBL)) {
            /* No parameter declared for it -- an old-style declaration, none,
             * or past a `...': K&R A.7.3.2, "each float argument is converted
             * to double". */
            g_expr_type = at;
            emit_to_quad(LT_DBL);
            emit_push_llong();
            total_arg_bytes += 8;
        } else if (!decl &&
                   (at == LT_LONG || at == LT_FLOAT)) {
            emit_push_long();
            total_arg_bytes += 4;
        } else {
            if (ks >= 0) { emit_fpr_to_a(ks); fpr_drop(ks); ks = -1; }
            if (decl && at == LT_FLOAT)
                emit_float_to_int();           /* an int/char parameter */
            emit_push_a();
            total_arg_bytes += 2;
        }
        actual_argc++;
    }
    *out_argc = actual_argc;
    return total_arg_bytes;
}

/* T5-C C1: the __syscall builtin family, recognized at call position in BOTH
 * call parsers (the expr arm below and parse_stmt's stmt arm).  Returns the
 * AST node, or -1 if the name is not one of ours (caller falls through).
 *
 *   __syscall(num, a, x, y)          marshal to A/X/Y, JSL SYS_TRAMP/DFB num
 *   __syscall_db(num, bank, a, x, y) same, run with DBR=bank (buffer-bank ABI)
 *   __syscall_c()                    carry from the last __syscall (0/1)
 *   __syscall_y()                    Y from the last __syscall (return-hi)
 *
 * num must be an int literal — it assembles to the inline DFB.  Carry sense
 * is the kernel's own (BOTH senses exist in the wild); the builtin latches
 * raw C into __sys_c and leaves interpretation to the C wrapper. */
int
build_syscall_builtin(const char *name_ptr, int name_len, int line, int col)
{
    int is_db = 0, cell = -1;
    if      (name_len ==  9 && memcmp(name_ptr, "__syscall",     9) == 0) ;
    else if (name_len == 12 && memcmp(name_ptr, "__syscall_db", 12) == 0) is_db = 1;
    else if (name_len == 11 && memcmp(name_ptr, "__syscall_c",  11) == 0) cell = 0;
    else if (name_len == 11 && memcmp(name_ptr, "__syscall_y",  11) == 0) cell = 1;
    else return -1;
    next_tok();                            /* consume '(' */
    if (cell >= 0) {
        expect(TOK_RPAREN, "')'");
        int n = ast_new(N_SYSCALL_CELL, line, col);
        g_ast[n].val  = (unsigned)cell;
        g_ast[n].type = LT_INT;
        g_ast[n].is_unsigned = 1;
        return n;
    }
    int num_n = build_comma_entry();
    if (g_ast[num_n].kind != N_LIT_INT)
        die(line, col, "__syscall: the syscall number must be an integer "
            "constant (it assembles to an inline DFB)");
    if (g_ast[num_n].val > 255)
        die(line, col, "__syscall: number out of DFB range (0..255)");
    int tmp[4], cnt = 0, bank_n = -1;
    if (is_db) {                           /* bank is 2nd in the signature but
                                            * WALKED LAST: args must evaluate
                                            * before DBR moves */
        expect(TOK_COMMA, "','");
        bank_n = build_comma_entry();
    }
    for (int i = 0; i < 3; i++) {
        expect(TOK_COMMA, "','");
        tmp[cnt++] = build_comma_entry();
    }
    if (is_db) tmp[cnt++] = bank_n;
    expect(TOK_RPAREN, "')'");
    if (g_n_ast_kids + cnt > MAX_AST_KIDS)
        die(line, col, "call-arg kid pool overflow");
    int kid0 = g_n_ast_kids;
    for (int i = 0; i < cnt; i++) g_ast_kids[g_n_ast_kids++] = tmp[i];
    int n = ast_new(N_SYSCALL, line, col);
    g_ast[n].val   = g_ast[num_n].val;
    g_ast[n].kid0  = kid0; g_ast[n].n_kids = cnt;
    g_ast[n].flags = is_db ? AF_SYSCALL_DB : 0;
    g_ast[n].type  = LT_INT;
    g_ast[n].is_unsigned = 1;
    return n;
}

/* --libso: every access to a block static goes through the lvalue walker.
 * A block static has no fixed address -- it is at block_offset(g) in its
 * member's block, which _<lib>_blk_<member> points at -- so its address comes
 * from emit_fpr_addr_global (the walker's named base), never from its label.
 * Entered with the IDENT consumed; handles its suffixes ([i], .f, ->f), then
 * (only when `store' -- build_assign has seen that one follows) `=' / `op='
 * (K&R A.7.17), else postfix ++/-- (A.7.3.4) or a plain value, which decays
 * to a pointer for an array (A.7.1).  A primary never takes the `=': in
 * `*p = c' it belongs to the unary expression, not to p. */
static int
build_block_static(Global *gv, int line, int col, int store)
{
    int head = ast_new(N_LV_CHAIN, line, col);
    g_ast[head].c = -1;                           /* named base: its address */
    g_ast[head].sym_lc = NULL; g_ast[head].sym_gv = gv;
    build_lvalue_suffixes(head, gv->type, gv->struct_id);
    if (store && (g_cur.kind == TOK_EQ || is_compound_op(g_cur.kind))) {
        require_assignable(g_ast[head].type, g_cur.kind);
        TokKind op = g_cur.kind;
        next_tok();
        int rhs = build_assign();                 /* right-assoc */
        int nn = ast_new(N_LV_STORE_E, line, col);
        g_ast[nn].a = head; g_ast[nn].op = op; g_ast[nn].c = rhs;
        g_ast[nn].type = g_ast[head].type;
        g_ast[nn].struct_id = g_ast[head].struct_id;
        return nn;
    }
    if (g_cur.kind == TOK_PLUSPLUS || g_cur.kind == TOK_MINUSMINUS) {
        LocalType lf = g_ast[head].type;
        require_assignable(lf, g_cur.kind);
        int is_inc = (g_cur.kind == TOK_PLUSPLUS);
        next_tok();
        int nn = ast_new(N_LV_INCDEC_E, line, col);
        g_ast[nn].a     = head;
        g_ast[nn].val   = (unsigned)incdec_stride(lf, g_ast[head].struct_id);
        g_ast[nn].flags = (is_inc ? AF_IS_INC : 0) | AF_RET_OLD;
        g_ast[nn].type  = lf;
        g_ast[nn].struct_id = g_ast[head].struct_id;
        g_ast[nn].is_unsigned = g_ast[head].is_unsigned;
        return nn;
    }
    {
        int v = lv_chain_value(head, line, col);
        /* A function pointer (or an element of an array of them) carries its
         * signature, so a call through the value can be built (K&R A.7.3.2). */
        if (g_ast[v].type == LT_FN_PTR && g_ast[v].fn_sig < 0)
            g_ast[v].fn_sig = gv->fn_sig_id;
        return build_postfix_value_chain(v);
    }
}

/* build_assign: does the block static at g_cur (an IDENT) head an
 * assignment -- IDENT, then its suffixes ([...], .f, ->f), then `=' or
 * `op='?  A token scan with no consume. */
static int
block_static_store_ahead(void)
{
    int i = g_tok_idx;                     /* g_toks[i] follows g_cur */
    for (;;) {
        TokKind k = g_toks[i].kind;
        if (k == TOK_LBRACKET) {
            int d = 0;
            for (; g_toks[i].kind != TOK_EOF; i++) {
                if (g_toks[i].kind == TOK_LBRACKET) d++;
                else if (g_toks[i].kind == TOK_RBRACKET && --d == 0) break;
            }
            if (g_toks[i].kind == TOK_EOF) return 0;
            i++;
        } else if ((k == TOK_DOT || k == TOK_ARROW) &&
                   g_toks[i + 1].kind == TOK_IDENT) {
            i += 2;
        } else {
            return k == TOK_EQ || is_compound_op(k);
        }
    }
}

/* The block static an IDENT names, or NULL (a local shadows it). */
Global *
block_static_named(const char *p, int n)
{
    Global *g;
    if (!g_libso || locals_lookup(p, n)) return NULL;
    g = globals_lookup(p, n);
    return (g && is_block_static(g)) ? g : NULL;
}

/* Primary builder — pre-IDENT arms converted; the IDENT arm (variable loads,
 * named/libc calls, member/array access) is the remaining 3a-E work and
 * fails closed. */
static int
build_primary_ast(void)
{
    if (g_cur.kind == TOK_LPAREN) {
        int op_line = g_cur.line, op_col = g_cur.col;
        next_tok();
        int saw_mod = 0;
        int saw_unsigned = 0;
        while (g_cur.kind == TOK_IDENT &&
               is_type_modifier_ident(g_cur.id_ptr, g_cur.id_len)) {
            if (g_cur.id_len == 8 &&
                memcmp(g_cur.id_ptr, "unsigned", 8) == 0)
                saw_unsigned = 1;
            saw_mod = 1;
            next_tok();
        }
        int bare_mod_cast = (saw_mod &&
                             (g_cur.kind == TOK_RPAREN || g_cur.kind == TOK_STAR));
        int is_cast = (bare_mod_cast ||
                       g_cur.kind == TOK_INT_KW || g_cur.kind == TOK_CHAR_KW ||
                       g_cur.kind == TOK_VOID_KW || g_cur.kind == TOK_LONG_KW ||
                       g_cur.kind == TOK_FLOAT_KW ||
                       g_cur.kind == TOK_STRUCT_KW || g_cur.kind == TOK_UNION_KW ||
                       g_cur.kind == TOK_ENUM_KW ||
                       (g_cur.kind == TOK_IDENT &&
                        typedefs_lookup(g_cur.id_ptr, g_cur.id_len) >= 0));
        if (is_cast) {
            LocalType bt;
            int from_typedef = 0;
            int cast_sid     = -1;
            if (bare_mod_cast) {
                bt = LT_INT;
            } else if (g_cur.kind == TOK_STRUCT_KW || g_cur.kind == TOK_UNION_KW) {
                next_tok();
                const char *tag_ptr = NULL; int tag_len = 0;
                if (g_cur.kind == TOK_IDENT) {
                    tag_ptr = g_cur.id_ptr; tag_len = g_cur.id_len; next_tok();
                }
                if (tag_ptr == NULL)
                    die(g_cur.line, g_cur.col, "expected struct/union tag in cast");
                cast_sid = structs_lookup(tag_ptr, tag_len);
                if (cast_sid < 0) {
                    if (g_n_structs >= MAX_STRUCTS)
                        die(g_cur.line, g_cur.col, "too many structs (max " FCC_STR(MAX_STRUCTS) ")");
                    Struct *st = &g_structs[g_n_structs];
                    int nl = tag_len < MAX_IDENT - 1 ? tag_len : MAX_IDENT - 1;
                    st->name = lex_intern_ident(tag_ptr, nl);
                    st->n_fields = 0; st->total_size = 0;
                    st->is_forward = 1; st->is_union = 0;
                    st->scope_hidden = 0;
                    st->scope_depth  = g_tag_scope_depth;
                    cast_sid = g_n_structs++;
                }
                bt = LT_STRUCT;
            } else if (g_cur.kind == TOK_IDENT) {
                int tdi = typedefs_lookup(g_cur.id_ptr, g_cur.id_len);
                bt = g_typedefs[tdi].base_type;
                /* Carry the typedef's struct id: a cast to a typedef'd struct
                 * pointer (BLKPTR == struct blk *) must keep struct_id so
                 * arithmetic on the cast result knows the stride (K&R A.7.5
                 * cast -> A.7.7 pointer + int).  2.11BSD sh blok.c:
                 * `BLK(stakbas)-1` == `(BLKPTR)stakbas - 1`. */
                cast_sid = g_typedefs[tdi].struct_id;
                /* `(u_int)x' is as unsigned as `(unsigned int)x'.  The
                 * explicit modifiers above already set saw_unsigned; a
                 * typedef has to say so through its own record. */
                if (g_typedefs[tdi].is_unsigned)
                    saw_unsigned = 1;
                from_typedef = 1;
                next_tok();
            } else {
                bt = (g_cur.kind == TOK_INT_KW)   ? LT_INT
                   : (g_cur.kind == TOK_CHAR_KW)  ? LT_CHAR
                   : (g_cur.kind == TOK_LONG_KW)  ? LT_LONG
                   : (g_cur.kind == TOK_FLOAT_KW)
                     ? ((g_cur.value == 1) ? LT_DBL : LT_FLOAT)
                                                  : LT_VOID;
                next_tok();
            }
            if (!from_typedef && bt == LT_LONG && g_cur.kind == TOK_FLOAT_KW) {
                long_double_or_die();
                bt = LT_DOUBLE;
            }
            if (!from_typedef && bt == LT_LONG && g_cur.kind == TOK_LONG_KW) {
                bt = LT_LLONG;                  /* `long long' (extension) */
                next_tok();
            }
            if (!from_typedef && (bt == LT_INT || bt == LT_CHAR ||
                                  bt == LT_LONG || bt == LT_LLONG))
                consume_trailing_specifiers(&bt, &saw_unsigned);
            if (g_cur.kind == TOK_LPAREN) {
                /* Inline abstract fn-ptr declarator cast, `T (*)(params)`.
                 *
                 * The `!from_typedef` guard that used to be here served no
                 * purpose: with it, a cast whose base was a TYPEDEF fell
                 * through to parse_declarator and died on the Increment-4
                 * grouping-declarator placeholder, so nothing working depended
                 * on it.  tcsh sh.c:418 is exactly that shape --
                 * `(sigret_t(*)()) osv.sv_handler` -- and sigret_t is a typedef.
                 *
                 * Widening is safe because this path FAILS CLOSED: after a type
                 * name in a cast the only legal thing a `(` can begin is an
                 * abstract declarator, and the sequence below dies unless it
                 * sees `*`, `)`, `(` in that order -- so e.g. a
                 * pointer-to-array `(T (*)[10])` still dies here rather than
                 * being mis-typed, exactly as it did before.
                 *
                 * This is a BRIDGE, not the answer.  K&R A.8.6 says grouping
                 * parens are type-transparent and only rebind, so the honest
                 * fix is the chartered Increment 5 recursive declarator; this
                 * path stays crude in the meantime (it DISCARDS the parameter
                 * list below and passes the operand's fn_sig through
                 * untouched), which a cast tolerates because the assignment
                 * check keys on the destination's declared signature. */
                next_tok();
                if (g_cur.kind != TOK_STAR)
                    die(g_cur.line, g_cur.col, "expected '*' in fn-ptr cast");
                next_tok();
                expect(TOK_RPAREN, "')' after '(*' in fn-ptr cast");
                expect(TOK_LPAREN, "'(' for fn-ptr cast parameter list");
                int pdepth = 1;
                while (pdepth > 0 && g_cur.kind != TOK_EOF) {
                    if (g_cur.kind == TOK_LPAREN)      pdepth++;
                    else if (g_cur.kind == TOK_RPAREN) pdepth--;
                    next_tok();
                }
                expect(TOK_RPAREN, "')' closing fn-ptr cast");
                int a = build_unary();
                int n = ast_new(N_CAST_FNPTR, op_line, op_col);
                g_ast[n].a = a;
                g_ast[n].type = LT_FN_PTR;
                g_ast[n].fn_sig = g_ast[a].fn_sig;   /* untouched by the cast */
                return n;
            }
            /* declarator-refactor Increment 1: the abstract POINTER declarator
             * now flows through the ONE parse_declarator instead of a private
             * base+INCREF chain.  Its tword is byte-identical to the old chain
             * (type_for_decl: depth-1 == LT_*_PTR by construction, and every
             * level is kept — the T5-C C2 fix `(char **)` stays char**), so the
             * cast's goldens are unchanged.  The base spec (bt/cast_sid/
             * saw_unsigned) still comes from build_primary_ast's cast base
             * parsing above; the fn-ptr cast keeps its own path (Increment 4). */
            TypeSpec cspec;
            cspec.base       = bt;
            cspec.struct_id  = cast_sid;
            cspec.is_static  = 0;
            cspec.is_extern  = 0;
            cspec.is_unsigned = saw_unsigned;
            Declarator cd = parse_declarator(cspec, /*allow_abstract=*/1);
            expect(TOK_RPAREN, "')'");
            LocalType target = cd.type;
            int is_ptr = tw_ptr_depth(target);
            /* `(void)voidfn()` — the idiomatic discard of a void call's
             * (non-)value.  Casting TO void makes the void-returning-call
             * check moot, so allow a void operand here (tcsh tc.bind
             * `(void) ClearXkey(map, in);`). */
            int saved_void_ok = g_void_ctx_ok;
            if (target == LT_VOID) g_void_ctx_ok = 1;
            int a = build_unary();
            g_void_ctx_ok = saved_void_ok;
            int n = ast_new(N_CAST, op_line, op_col);
            g_ast[n].a = a;
            g_ast[n].val = (unsigned)target;
            g_ast[n].val_hi = (unsigned)is_ptr;
            g_ast[n].type = target;
            if (target == LT_STRUCT_PTR) g_ast[n].struct_id = cast_sid;
            /* A-1: scalar unsigned casts mark the value; a POINTER cast
             * with an unsigned base type marks the POINTEE, so a deref of
             * the cast (`*(unsigned *)p` — stdarg's va_arg) reads unsigned
             * (printf %u/%x sign-extended 16-bit args >= 0x8000 without
             * this — H2 vmstat find). */
            g_ast[n].is_unsigned = (saw_unsigned &&
                                    (is_ptr ||
                                     target == LT_INT || target == LT_CHAR ||
                                     target == LT_LONG));
            return n;
        }
        /* `( E ) ++' / `( E ) --' with E ONE postfix expression IS `E++'.
         * K&R A.7.2 (p.162): "A parenthesized expression is a primary
         * expression whose type and value are identical to those of the
         * unadorned expression.  The precedence of parentheses does not affect
         * whether the expression is an lvalue."  So the operator is moved
         * inside the group -- `( E ++ )', the same value by A.7.3.4 -- for as
         * long as the group is being parsed, and put back after its ')' is
         * consumed: a caller that parsed this speculatively and rewinds (the
         * `*(s)++ = rhs' store classifier, M22 pdref_store) must find its
         * tokens as written, and no lookahead helper ever meets a hole.  The
         * value-position twin of parse_stmt.c's G41 splice (apple/fgx#448).
         * The cast arms above have already run, so a typedef cast of a PREFIX
         * increment, `(T)++x', never reaches here; lex_is_postfix_run keeps
         * `(a + b)++' out; and a '*'-led E is not a postfix run, so `(*p)++'
         * (which bumps *p, where `*p++' bumps p) keeps the deref arm below. */
        int rot_close = -1, rot_after = -1;
        {
            int first = g_tok_idx - 1;             /* g_cur: first inner token */
            int close = first, d = 1;
            for (; g_toks[close].kind != TOK_EOF; close++) {
                if (g_toks[close].kind == TOK_LPAREN) d++;
                else if (g_toks[close].kind == TOK_RPAREN && --d == 0) break;
            }
            int after = close + 1;
            while (g_toks[after].kind == TOK_SKIP) after++;
            if (d == 0 &&
                (g_toks[after].kind == TOK_PLUSPLUS ||
                 g_toks[after].kind == TOK_MINUSMINUS) &&
                lex_is_postfix_run(first, close)) {
                Tok t = g_toks[close];
                g_toks[close] = g_toks[after];
                g_toks[after] = t;
                rot_close = close; rot_after = after;
            }
        }
        /* parenthesized (comma-level) expression + postfix chain */
        int inner = build_comma();
        expect(TOK_RPAREN, "')'");
        if (rot_close >= 0) {                      /* both now behind us */
            Tok t = g_toks[rot_close];
            g_toks[rot_close] = g_toks[rot_after];
            g_toks[rot_after] = t;
        }
        int chained = build_postfix_value_chain(inner);
        /* (*p)++ / (*p)-- : postfix incdec of a parenthesized deref LVALUE --
         * the pointee is bumped IN PLACE at the deref's operand address (tcsh
         * sh.exp `(*vp)++`, vp a `Char **` so `*vp` is a Char* leaf).  Distinct
         * from `*p++` (== N_DEREF_POSTINC, which bumps p itself).  Any scalar
         * or object-pointer leaf: N_LV_INCDEC_E does a char as an 8-bit RMW
         * (apple/fgx#216) and a long or float as a 32-bit +-1.  K&R A.7.3.4. */
        if ((g_cur.kind == TOK_PLUSPLUS || g_cur.kind == TOK_MINUSMINUS) &&
            (g_ast[chained].kind == N_DEREF_FAST ||
             g_ast[chained].kind == N_DEREF_GENERAL) &&
            (ISPTR(g_ast[chained].type) || g_ast[chained].type == LT_INT ||
             g_ast[chained].type == LT_CHAR || g_ast[chained].type == LT_LONG ||
             g_ast[chained].type == LT_FLOAT || IS_QUAD(g_ast[chained].type))) {
            int is_inc = (g_cur.kind == TOK_PLUSPLUS);
            next_tok();                            /* consume '++'/'--' */
            LocalType lt = g_ast[chained].type;
            int st = incdec_stride(lt, g_ast[chained].struct_id);
            int nn = ast_new(N_LV_INCDEC_E, op_line, op_col);
            g_ast[nn].a          = chained;        /* deref node: addr = its operand */
            g_ast[nn].val        = (unsigned)st;
            g_ast[nn].flags      = (is_inc ? AF_IS_INC : 0) | AF_RET_OLD; /* postfix */
            g_ast[nn].type       = lt;
            g_ast[nn].struct_id  = g_ast[chained].struct_id;
            g_ast[nn].is_unsigned = g_ast[chained].is_unsigned;
            return nn;
        }
        /* Gap-3b: call through a parenthesized fn-ptr value. */
        if (g_ast[chained].type == LT_FN_PTR && g_cur.kind == TOK_LPAREN &&
            g_ast[chained].fn_sig >= 0) {
            int sig = g_ast[chained].fn_sig;
            int op_line2 = g_cur.line, op_col2 = g_cur.col;
            next_tok();                    /* consume '(' */
            int kid0, n_kids;
            build_call_args(&kid0, &n_kids);
            expect(TOK_RPAREN, "')'");
            int n = ast_new(N_CALL_STASHED, op_line2, op_col2);
            g_ast[n].a = chained;
            g_ast[n].kid0 = kid0; g_ast[n].n_kids = n_kids;
            g_ast[n].val = (unsigned)sig;
            g_ast[n].type = g_fn_sigs[sig].return_type;
            g_ast[n].is_unsigned = g_fn_sigs[sig].ret_unsigned;   /* A-1 */
            g_ast[n].fn_sig = -1;
            return n;
        }
        /* Every lvalue a group can hold was taken above (the rotation, the
         * deref arm), so a '++'/'--' still here follows a non-lvalue such as
         * `(a + b)' or `(n)++'.  K&R A.7.3.4: "The operand must be an lvalue",
         * and the result of postfix ++ "is not an lvalue". */
        if (g_cur.kind == TOK_PLUSPLUS || g_cur.kind == TOK_MINUSMINUS)
            die(g_cur.line, g_cur.col, "'++'/'--' needs a modifiable lvalue");
        return chained;
    }
    if (g_cur.kind == TOK_INT_LIT && g_cur.is_llong) {
        int n = ast_new(N_LIT_LLONG, g_cur.line, g_cur.col);
        g_ast[n].val = g_cur.value; g_ast[n].val_hi = g_cur.value_hi;
        g_ast[n].val2 = g_cur.value2; g_ast[n].val3 = g_cur.value3;
        g_ast[n].type = LT_LLONG;
        g_ast[n].is_unsigned = g_cur.is_unsigned;
        next_tok();
        return n;
    }
    if (g_cur.kind == TOK_INT_LIT) {
        int n = ast_new(g_cur.is_long ? N_LIT_LONG : N_LIT_INT,
                        g_cur.line, g_cur.col);
        g_ast[n].val = g_cur.value; g_ast[n].val_hi = g_cur.value_hi;
        g_ast[n].type = g_cur.is_long ? LT_LONG : LT_INT;
        g_ast[n].is_unsigned = g_cur.is_unsigned;   /* A-1: U suffix */
        next_tok();
        return n;
    }
    if (g_cur.kind == TOK_FLOAT_LIT) {
        int n = ast_new(N_LIT_FLOAT, g_cur.line, g_cur.col);
        g_ast[n].val = g_cur.value; g_ast[n].val_hi = g_cur.value_hi;
        g_ast[n].type = LT_FLOAT;
        if (g_cur.is_dbl) {
            /* A double or long double constant: its IEEE double bits, four
             * words from the lowest. */
            unsigned long b;
            memcpy(&b, &g_cur.dval, 8);
            g_ast[n].val    = (unsigned)(b & 0xFFFFu);
            g_ast[n].val_hi = (unsigned)((b >> 16) & 0xFFFFu);
            g_ast[n].val2   = (unsigned)((b >> 32) & 0xFFFFu);
            g_ast[n].val3   = (unsigned)((b >> 48) & 0xFFFFu);
            g_ast[n].type   = LT_DOUBLE;
        }
        next_tok();
        return n;
    }
    if (g_cur.kind == TOK_CHAR_LIT) {
        /* K&R 2.3: "A character constant is an integer" -- an int. */
        int n = ast_new(N_LIT_CHAR, g_cur.line, g_cur.col);
        g_ast[n].val = g_cur.value;
        g_ast[n].type = LT_INT;
        next_tok();
        return n;
    }
    if (g_cur.kind == TOK_STR_LIT) {
        int lbl = strlit_intern(g_cur.str_ptr, g_cur.str_len);
        int n = ast_new(N_LIT_STR, g_cur.line, g_cur.col);
        g_ast[n].val = (unsigned)lbl;
        g_ast[n].type = LT_CHAR_PTR;
        next_tok();
        /* postfix subscript on a string-literal value: "..."[i] */
        return build_postfix_value_chain(n);
    }
    if (g_cur.kind == TOK_IDENT) {
        const char *name_ptr = g_cur.id_ptr;   /* interned: stable */
        int         name_len = g_cur.id_len;
        int         line     = g_cur.line, col = g_cur.col;
        next_tok();
        if (g_cur.kind != TOK_LPAREN) {
            Global *bgv = block_static_named(name_ptr, name_len);
            if (bgv) return build_block_static(bgv, line, col, 0);
        }

        if (g_cur.kind == TOK_LPAREN) {
            int is_setjmp  = (name_len == 6 && memcmp(name_ptr, "setjmp",  6) == 0);
            int is_longjmp = (name_len == 7 && memcmp(name_ptr, "longjmp", 7) == 0);
            if (is_setjmp || is_longjmp) {
                next_tok();                       /* consume '(' */
                if (g_cur.kind == TOK_IDENT) {
                    Local *jb = locals_lookup(g_cur.id_ptr, g_cur.id_len);
                    if (jb != NULL &&
                        ((jb->kind == LK_LOCAL &&
                          (jb->type == LT_STRUCT || ISARY(jb->type))) ||
                         (jb->kind == LK_PARAM && jb->type == LT_STRUCT))) {
                        die(line, col,
                            "setjmp/longjmp: jmp_buf must be a global or static "
                            "(a stack-local, or a jmp_buf passed BY VALUE as a "
                            "struct parameter, lives in the frame — freed on "
                            "return, so longjmp would restore into a dead "
                            "frame); see userland-abi.md section 3.6");
                    }
                }
                int env = build_comma_entry();
                if (is_setjmp) {
                    expect(TOK_RPAREN, "')' after setjmp(env)");
                    int n = ast_new(N_SETJMP, line, col);
                    g_ast[n].a = env;
                    g_ast[n].type = LT_INT;
                    return n;
                }
                expect(TOK_COMMA, "',' in longjmp(env, val)");
                int val = build_comma_entry();
                expect(TOK_RPAREN, "')' after longjmp(env, val)");
                int n = ast_new(N_LONGJMP, line, col);
                g_ast[n].a = env; g_ast[n].b = val;
                g_ast[n].type = LT_INT;
                return n;
            }
            {   /* T5-C C1: __syscall builtin family. */
                int n = build_syscall_builtin(name_ptr, name_len, line, col);
                if (n >= 0) return n;
            }
            /* M18: indirect call via fn-ptr local/global. */
            {
                Local  *fp_lc = locals_lookup(name_ptr, name_len);
                Global *fp_gv = (fp_lc == NULL) ? globals_lookup(name_ptr, name_len) : NULL;
                int     fp_sig = -1;
                if (fp_lc != NULL && fp_lc->type == LT_FN_PTR) {
                    fp_sig = fp_lc->fn_sig_id;
                } else if (fp_gv != NULL && fp_gv->type == LT_FN_PTR) {
                    fp_sig = fp_gv->fn_sig_id;
                } else {
                    fp_lc = NULL; fp_gv = NULL;
                }
                if (fp_sig >= 0) {
                    next_tok();                   /* consume '(' */
                    int kid0, n_kids;
                    build_call_args(&kid0, &n_kids);
                    expect(TOK_RPAREN, "')'");
                    int n = ast_new(N_CALL_FPVAR, line, col);
                    g_ast[n].sym_lc = fp_lc; g_ast[n].sym_gv = fp_gv;
                    g_ast[n].val = (unsigned)fp_sig;
                    g_ast[n].kid0 = kid0; g_ast[n].n_kids = n_kids;
                    g_ast[n].type = g_fn_sigs[fp_sig].return_type;
                    g_ast[n].is_unsigned = g_fn_sigs[fp_sig].ret_unsigned;   /* A-1 */
                    return n;
                }
            }
            /* Named function call. */
            int fn_idx = funcs_lookup(name_ptr, name_len);
            if (fn_idx < 0) {
                warn_implicit_decl(name_ptr, name_len, line, col);
                fn_idx = funcs_declare(name_ptr, name_len, 0, line, col);
                g_funcs[fn_idx].return_type = LT_INT;
                g_funcs[fn_idx].is_variadic = 1;
                g_funcs[fn_idx].is_extern   = 1;
            }
            int expected_argc = g_funcs[fn_idx].n_params;
            next_tok();                           /* consume '(' */
            /* T5-C C5: the printf family is an ordinary variadic call — the
             * pile exports plain names and fcc emits the plain source name;
             * fgx_ld resolves a user definition over the pile (Stage A archive
             * model), so no compile-time libc binding is needed. */
            int kid0, n_kids;
            build_call_args(&kid0, &n_kids);
            expect(TOK_RPAREN, "')'");
            if (g_funcs[fn_idx].is_variadic) {
                if (n_kids < expected_argc) {
                    char buf[96];
                    snprintf(buf, sizeof buf,
                             "'%.*s' needs >= %d arg%s, got %d (variadic)",
                             name_len, name_ptr, expected_argc,
                             expected_argc == 1 ? "" : "s", n_kids);
                    die(line, col, buf);
                }
            } else if (n_kids > expected_argc && g_funcs[fn_idx].is_from_sigs) {
                /* No declaration is in scope -- the sidecar is not one -- so the
                 * call is old-style, and K&R A.7.3.2 makes a count mismatch
                 * undefined, not an error ("The number of arguments must be the
                 * same" is said only of a new-style declaration).  2.11BSD
                 * telnetd's `dooption(TELOPT_TTYPE, 0)'.  Every argument is
                 * pushed; the extras lie deeper than the callee's parameters. */
                fprintf(stderr, "%s:%d:%d: warning: '%.*s' called with %d arg%s, "
                        "defined with %d\n",
                        g_input_path, line, col, name_len, name_ptr, n_kids,
                        n_kids == 1 ? "" : "s", expected_argc);
            } else if (n_kids > expected_argc) {
                char buf[96];
                snprintf(buf, sizeof buf,
                         "'%.*s' expects %d argument%s, got %d",
                         name_len, name_ptr, expected_argc,
                         expected_argc == 1 ? "" : "s", n_kids);
                die(line, col, buf);
            } else if (n_kids < expected_argc) {
                /* K&R under-supplied call: pad the missing trailing params with
                 * 0 (deterministic vs reading stack garbage).  2.11BSD telnet
                 * calls printoption(dir,fmt,opt) against (dir,fmt,opt,what). */
                fprintf(stderr, "%s:%d:%d: warning: '%.*s' called with %d arg%s, "
                        "expects %d — K&R-padding the rest with 0\n",
                        g_input_path, line, col, name_len, name_ptr, n_kids,
                        n_kids == 1 ? "" : "s", expected_argc);
                while (n_kids < expected_argc) {
                    if (g_n_ast_kids >= MAX_AST_KIDS)
                        die(line, col, "call-arg kid pool overflow (K&R pad)");
                    int z = ast_new(N_LIT_INT, line, col);
                    g_ast[z].val = 0;
                    g_ast[z].type = LT_INT;
                    g_ast_kids[g_n_ast_kids++] = z;
                    n_kids++;
                }
            }
            if (g_funcs[fn_idx].return_type == LT_VOID && !g_void_ctx_ok)
                die(line, col,
                    "void-returning function cannot be used in expression");
            int n = ast_new(N_CALL_NAMED, line, col);
            g_ast[n].val = (unsigned)fn_idx;
            g_ast[n].name = name_ptr; g_ast[n].name_len = name_len;
            g_ast[n].kid0 = kid0; g_ast[n].n_kids = n_kids;
            g_ast[n].type = g_funcs[fn_idx].return_type;
            g_ast[n].struct_id = g_funcs[fn_idx].return_struct_id;
            g_ast[n].is_unsigned = g_funcs[fn_idx].ret_unsigned;
            /* postfix chain on the call RESULT: f()->field / f()[i] */
            return build_postfix_value_chain(n);
        }

        if (g_cur.kind == TOK_LBRACKET) {
            Local  *llc = locals_lookup(name_ptr, name_len);
            Global *lgv = llc ? NULL : globals_lookup(name_ptr, name_len);
            LocalType lat = llc ? llc->type : (lgv ? lgv->type : LT_INT);
            if ((llc || lgv) && BT_IS_QUAD(BTYPE(lat)) && !ISPTR(DECREF(lat))) {
                /* A long long element goes through the uniform walker, whose
                 * loads and ++/-- cover all eight bytes. */
                int head = ast_new(N_LV_CHAIN, line, col);
                g_ast[head].c = -1;                   /* named base */
                g_ast[head].sym_lc = llc; g_ast[head].sym_gv = lgv;
                build_lvalue_suffixes(head, lat, -1);
                if (g_cur.kind == TOK_PLUSPLUS || g_cur.kind == TOK_MINUSMINUS) {
                    LocalType lf = g_ast[head].type;
                    require_assignable(lf, g_cur.kind);
                    int is_inc = (g_cur.kind == TOK_PLUSPLUS);
                    next_tok();
                    int nn = ast_new(N_LV_INCDEC_E, line, col);
                    g_ast[nn].a     = head;
                    g_ast[nn].val   = (unsigned)incdec_stride(lf, -1);
                    g_ast[nn].flags = (is_inc ? AF_IS_INC : 0) | AF_RET_OLD;
                    g_ast[nn].type  = lf;
                    g_ast[nn].struct_id = -1;
                    g_ast[nn].is_unsigned = g_ast[head].is_unsigned;
                    return nn;
                }
                return build_postfix_value_chain(lv_chain_value(head, line, col));
            }
            next_tok();                           /* consume '[' */
            Local  *lc = locals_lookup(name_ptr, name_len);
            Global *gv = (lc == NULL) ? globals_lookup(name_ptr, name_len) : NULL;
            if (lc == NULL && gv == NULL) {
                char buf[64];
                snprintf(buf, sizeof buf, "'%.*s' undeclared",
                         name_len, name_ptr);
                die(line, col, buf);
            }
            LocalType atype = lc ? lc->type      : gv->type;
            int       asid  = lc ? lc->struct_id : gv->struct_id;
            if (atype == LT_STRUCT_ARRAY || atype == LT_STRUCT_PTR) {
                return build_struct_elem_access(lc, gv, atype, asid, line, col);
            }
            /* arr[i]++ / arr[i]-- on an int/char array element -- of a
             * one-dimensional array; a row of `m[2][3]' is not an element. */
            if ((atype == LT_INT_ARRAY || atype == LT_CHAR_ARRAY) &&
                (lc ? lc->n_dims : gv->n_dims) <= 1) {
                LexPeek pk;
                lex_peek_save(&pk);
                int d = 1;
                while (g_cur.kind != TOK_EOF) {
                    if (g_cur.kind == TOK_LBRACKET) d++;
                    else if (g_cur.kind == TOK_RBRACKET) {
                        d--;
                        if (d == 0) { next_tok(); break; }
                    }
                    next_tok();
                }
                int is_post = 0, is_inc = 0;
                if (d == 0) {
                    if (g_cur.kind == TOK_PLUSPLUS)        { is_post = 1; is_inc = 1; }
                    else if (g_cur.kind == TOK_MINUSMINUS)   is_post = 1;
                }
                lex_peek_restore(&pk);
                if (is_post) {
                    int idx = build_comma_entry();
                    expect(TOK_RBRACKET, "']'");
                    next_tok();                   /* consume '++'/'--' */
                    int n = ast_new(N_ARR_POSTINC, line, col);
                    g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                    g_ast[n].a = idx;
                    g_ast[n].flags = ((atype == LT_CHAR_ARRAY) ? AF_IS_BYTE : 0) |
                                     (is_inc ? AF_IS_INC : 0);
                    g_ast[n].type = (atype == LT_CHAR_ARRAY) ? LT_CHAR : LT_INT;
                    return n;
                }
            }
            /* arr[i]++ / arr[i]-- on a POINTER-array element (`Char *[]` etc.):
             * the element is a pointer lvalue -- bump it in place via the walker
             * (tcsh ed.inputl `*KeyMacro[MacroLvl]++`).  The address is a chain
             * &arr[i] (array base, one INDEX step); the leaf is the element
             * pointer, so N_LV_INCDEC_E (chain mode) yields the OLD far pointer.
             * K&R A.7.3.4 (postfix), A.7.3.1 (E1[E2]). */
            if (is_ptr_array(atype) && DECREF(atype) != LT_FN_PTR) {
                LexPeek pk;
                lex_peek_save(&pk);
                int d = 1;
                while (g_cur.kind != TOK_EOF) {
                    if (g_cur.kind == TOK_LBRACKET) d++;
                    else if (g_cur.kind == TOK_RBRACKET) {
                        d--;
                        if (d == 0) { next_tok(); break; }
                    }
                    next_tok();
                }
                int is_post = 0, is_inc = 0;
                if (d == 0) {
                    if (g_cur.kind == TOK_PLUSPLUS)        { is_post = 1; is_inc = 1; }
                    else if (g_cur.kind == TOK_MINUSMINUS)   is_post = 1;
                }
                lex_peek_restore(&pk);
                if (is_post) {
                    int idx = build_comma_entry();
                    expect(TOK_RBRACKET, "']'");
                    next_tok();                   /* consume '++'/'--' */
                    LocalType ety = DECREF(atype);            /* element: a T* */
                    int esid = (BTYPE(ety) == BT_STRUCT) ? asid : -1;
                    int es = elem_size_for(atype, asid);      /* container stride */
                    if (es == 0) es = 1;
                    int step = ast_new(N_LV_STEP_INDEX, line, col);
                    g_ast[step].b = idx; g_ast[step].val = (unsigned)es;
                    g_ast[step].flags = 0;                    /* array base: no deref */
                    g_ast[step].type = ety; g_ast[step].a = -1;
                    int head = ast_new(N_LV_CHAIN, line, col);
                    g_ast[head].c = -1;                       /* named base */
                    g_ast[head].sym_lc = lc; g_ast[head].sym_gv = gv;
                    g_ast[head].b = step;
                    g_ast[head].type = ety; g_ast[head].struct_id = esid;
                    int st = elem_size_for(ety, esid);        /* incr = sizeof(*elem) */
                    if (st == 0) st = 1;
                    int nn = ast_new(N_LV_INCDEC_E, line, col);
                    g_ast[nn].a          = head;              /* N_LV_CHAIN -> chain mode */
                    g_ast[nn].val        = (unsigned)st;
                    g_ast[nn].flags      = (is_inc ? AF_IS_INC : 0) | AF_RET_OLD;
                    g_ast[nn].type       = ety;               /* leaf: the element pointer */
                    g_ast[nn].struct_id  = esid;
                    return nn;
                }
            }
            /* General indexed read: first index already '['-consumed; the
             * chain consumes up to n_dims subscripts (the wrapper's rule). */
            {
                int n_dims = lc ? lc->n_dims : gv->n_dims;
                int tmp[MAX_DIMS];
                int cnt = 0;
                tmp[cnt++] = build_comma_entry();
                expect(TOK_RBRACKET, "']'");
                while (g_cur.kind == TOK_LBRACKET && cnt < n_dims) {
                    next_tok();
                    if (cnt >= MAX_DIMS)
                        die(g_cur.line, g_cur.col, "too many subscripts");
                    tmp[cnt++] = build_comma_entry();
                    expect(TOK_RBRACKET, "']'");
                }
                if (g_n_ast_kids + cnt > MAX_AST_KIDS)
                    die(line, col, "index kid pool overflow");
                int kid0 = g_n_ast_kids;
                for (int i = 0; i < cnt; i++) g_ast_kids[g_n_ast_kids++] = tmp[i];
                int n = ast_new(N_ARR_READ, line, col);
                g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                g_ast[n].kid0 = kid0; g_ast[n].n_kids = cnt;
                set_arr_read_type(n, lc, gv, cnt, n_dims);
                /* G46/G52 postfix chain on a pointer-valued element */
                int chained = build_postfix_value_chain(n);
                /* B-7: direct call through an indexed fn-ptr element */
                if (g_ast[chained].type == LT_FN_PTR && g_cur.kind == TOK_LPAREN) {
                    int sig = lc ? lc->fn_sig_id : gv->fn_sig_id;
                    int op_line2 = g_cur.line, op_col2 = g_cur.col;
                    next_tok();
                    int akid0, an_kids;
                    build_call_args(&akid0, &an_kids);
                    expect(TOK_RPAREN, "')'");
                    int cn = ast_new(N_CALL_STASHED, op_line2, op_col2);
                    g_ast[cn].a = chained;
                    g_ast[cn].kid0 = akid0; g_ast[cn].n_kids = an_kids;
                    g_ast[cn].val = (unsigned)sig;
                    g_ast[cn].type = g_fn_sigs[sig].return_type;
                    g_ast[cn].is_unsigned = g_fn_sigs[sig].ret_unsigned;   /* A-1 */
                    g_ast[cn].fn_sig = -1;
                    return cn;
                }
                return chained;
            }
        }

        if (g_cur.kind == TOK_PLUSPLUS || g_cur.kind == TOK_MINUSMINUS) {
            int is_inc = (g_cur.kind == TOK_PLUSPLUS);
            next_tok();
            Local  *lc = locals_lookup(name_ptr, name_len);
            Global *gv = (lc == NULL) ? globals_lookup(name_ptr, name_len)
                                      : NULL;
            if (lc == NULL && gv == NULL) {
                char buf[64];
                snprintf(buf, sizeof buf, "'%.*s' undeclared",
                         name_len, name_ptr);
                die(line, col, buf);
            }
            require_assignable(lc ? lc->type : gv->type, TOK_PLUSPLUS);
            if (lc != NULL) {
                int st = elem_size_for(lc->type, lc->struct_id);
                if (st == 0) st = 1;
                int n = ast_new(N_POSTINC_LOCAL, line, col);
                g_ast[n].sym_lc = lc;
                g_ast[n].val = (unsigned)st;
                g_ast[n].flags = is_inc ? AF_IS_INC : 0;
                g_ast[n].type = lc->type;
                g_ast[n].struct_id = lc->struct_id;      /* from the load */
                g_ast[n].is_unsigned = lc->is_unsigned;  /* from the load */
                g_ast[n].fn_sig = (lc->type == LT_FN_PTR) ? lc->fn_sig_id : -1;
                return n;
            }
            if (gv->type != LT_INT && gv->type != LT_CHAR &&
                gv->type != LT_LONG && gv->type != LT_FLOAT &&
                !IS_QUAD(gv->type) && !ISPTR(gv->type))
                die(line, col,
                    "global ++/-- expr: int/char/long/long long/double/float/pointer only");
            int st = elem_size_for(gv->type, gv->struct_id);
            if (st == 0) st = 1;
            int n = ast_new(N_POSTINC_GLOBAL, line, col);
            g_ast[n].sym_gv = gv;
            g_ast[n].val = (unsigned)st;
            g_ast[n].flags = is_inc ? AF_IS_INC : 0;
            g_ast[n].type = gv->type;
            g_ast[n].struct_id = gv->struct_id;
            g_ast[n].is_unsigned = gv->is_unsigned;
            g_ast[n].fn_sig = (gv->type == LT_FN_PTR) ? gv->fn_sig_id : -1;
            return n;
        }

        /* enum constants take precedence as fixed compile-time values. */
        int eidx = enum_consts_lookup(name_ptr, name_len);
        if (eidx >= 0) {
            int n = ast_new(N_ENUM_CONST, line, col);
            g_ast[n].val = g_enum_consts[eidx].value;
            g_ast[n].type = LT_INT;
            return n;
        }

        Local  *lc = locals_lookup(name_ptr, name_len);
        Global *gv = (lc == NULL) ? globals_lookup(name_ptr, name_len) : NULL;
        if (lc == NULL && gv == NULL) {
            int fn_idx_rv = funcs_lookup(name_ptr, name_len);
            if (fn_idx_rv >= 0) {
                int n = ast_new(N_ADDR_FUNC, line, col);
                g_ast[n].val = (unsigned)fn_idx_rv;
                g_ast[n].type = LT_FN_PTR;
                return n;
            }
            char buf[64];
            snprintf(buf, sizeof buf, "'%.*s' undeclared",
                     name_len, name_ptr);
            die(line, col, buf);
        }
        LocalType cur_type = lc ? lc->type      : gv->type;
        int       cur_sid  = lc ? lc->struct_id : gv->struct_id;

        /* Mid-chain-dot READ (`t->L.T_dcar->t_dflg`, tcsh sh.sem): a `.field`
         * that bridges to a further `->`/`[` -- build_dot/arrow_access's chain
         * stops there.  Route the whole run through the uniform K&R walker
         * (named base, emit_lvalue_addr + deref-load leaf; K&R A.7.3 one postfix
         * production).  Peek-gated so only the bridging shape is intercepted;
         * plain `t->f`, `t->a->b`, `t->a.b` (dot last) keep their paths. */
        if ((g_cur.kind == TOK_ARROW || g_cur.kind == TOK_DOT) &&
            (cur_type == LT_STRUCT_PTR || cur_type == LT_STRUCT) &&
            peek_chain_dot_bridges()) {
            int head = ast_new(N_LV_CHAIN, line, col);
            g_ast[head].c = -1;
            g_ast[head].sym_lc = lc; g_ast[head].sym_gv = gv;
            build_lvalue_suffixes(head, cur_type, cur_sid);
            /* A STRUCT LEAF IS ADDRESSED, NOT LOADED.  N_LV_LOAD_E
             * dereferences its leaf, and a struct does not fit a register, so
             * the leaf was refused outright.  A struct VALUE in this compiler
             * is carrier-carried -- it IS its address -- so the walker's own
             * result is already the right answer and only the node kind was
             * wrong.  This is the array leaf's arm below with the decay taken
             * out: K&R A.7.1 converts an array lvalue to a pointer, and says
             * nothing of the sort about a struct, so the type stays LT_STRUCT.
             * apple/fgx#259. */
            if (g_ast[head].type == LT_STRUCT) {
                int an = ast_new(N_ADDR_LV_E, line, col);
                g_ast[an].a = head;
                g_ast[an].type = LT_STRUCT;
                g_ast[an].struct_id = g_ast[head].struct_id;
                return an;
            }
            /* AN ARRAY LEAF DECAYS; IT MUST NOT BE LOADED (apple/fgx#200).
             *
             * `wr.w_blk->b_next->b_info' reaches here, and N_LV_LOAD_E
             * dereferences its leaf -- so the walker computed the array's
             * address correctly and then read the FIRST BYTE of it and used
             * that as the pointer's offset.  Silently: the result is a
             * well-formed pointer to somewhere the data chose.
             *
             * K&R A.7.1 converts an lvalue of array type to a pointer to its
             * first element, with no condition on how the lvalue was reached.
             * This is the third of the arrow run's three emitters to want the
             * same arm, and the only one where the absence was silent rather
             * than a parse error. */
            if (ISARY(g_ast[head].type)) {
                int an = ast_new(N_ADDR_LV_E, line, col);
                g_ast[an].a = head;
                switch (g_ast[head].type) {
                    case LT_CHAR_ARRAY:   g_ast[an].type = LT_CHAR_PTR;   break;
                    case LT_INT_ARRAY:    g_ast[an].type = LT_INT_PTR;    break;
                    case LT_STRUCT_ARRAY: g_ast[an].type = LT_STRUCT_PTR; break;
                    default:              g_ast[an].type = LT_LONG_PTR;   break;
                }
                g_ast[an].struct_id = g_ast[head].struct_id;
                return an;
            }
            int nn = ast_new(N_LV_LOAD_E, line, col);
            g_ast[nn].a = head;
            g_ast[nn].type = g_ast[head].type;
            g_ast[nn].struct_id = g_ast[head].struct_id;
            g_ast[nn].is_unsigned = g_ast[head].is_unsigned;
            return nn;
        }
        if (g_cur.kind == TOK_DOT && cur_type == LT_STRUCT)
            return build_dot_access(lc, gv, cur_sid, line, col);
        if (g_cur.kind == TOK_ARROW && cur_type == LT_STRUCT_PTR)
            return build_arrow_access(lc, gv, cur_sid, line, col);
        if (g_cur.kind == TOK_ARROW && ISPTR(cur_type)) {
            /* K&R global-member pun (A.7.3, 1st ed): `->` READ on a NON-struct
             * pointer -- the base value is a byte address, the member resolves
             * in the global namespace.  2.11BSD /bin/sh: `np->dolarg` (np a
             * STRING* == char**, dolarg a dolnod field).  Peek the member,
             * resolve its defining struct, and reuse the normal arrow-read path
             * with the base coerced to (member's-struct *). */
            LexPeek pk;
            lex_peek_save(&pk);
            next_tok();                        /* peek past '->' */
            int csid = -1;
            if (g_cur.kind == TOK_IDENT)
                field_lookup_global(g_cur.id_ptr, g_cur.id_len, &csid);
            lex_peek_restore(&pk);             /* back to '->' */
            if (csid >= 0)
                return build_arrow_access(lc, gv, csid, line, col);
        }

        /* Plain variable read / array decay / struct value. */
        int n = ast_new(N_VAR_LOAD, line, col);
        g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
        if (lc != NULL) {
            if (lc->type == LT_INT_ARRAY || lc->type == LT_CHAR_ARRAY ||
                ISARY(lc->type) || lc->type == LT_STRUCT) {
                g_ast[n].type = (lc->type == LT_STRUCT)
                              ? LT_STRUCT
                              : INCREF(DECREF(lc->type), DERIV_PTR);
                g_ast[n].struct_id = lc->struct_id;
            } else {
                g_ast[n].type = lc->type;
                g_ast[n].struct_id = lc->struct_id;
                g_ast[n].is_unsigned = lc->is_unsigned;
                g_ast[n].fn_sig = (lc->type == LT_FN_PTR) ? lc->fn_sig_id : -1;
            }
        } else {
            if (ISARY(gv->type) || gv->type == LT_STRUCT) {
                g_ast[n].type = (gv->type == LT_STRUCT)
                              ? LT_STRUCT
                              : INCREF(DECREF(gv->type), DERIV_PTR);
                g_ast[n].struct_id = gv->struct_id;
            } else {
                g_ast[n].type = gv->type;
                g_ast[n].struct_id = gv->struct_id;
                g_ast[n].is_unsigned = gv->is_unsigned;
                g_ast[n].fn_sig = (gv->type == LT_FN_PTR) ? gv->fn_sig_id : -1;
            }
        }
        return n;
    }
    die(g_cur.line, g_cur.col, "expected expression");
}

/* Member-access builders (3a-E part 3). */

/* pts[i].field — the '[' is already consumed. */
static int
build_struct_elem_access(Local *lc, Global *gv, LocalType atype, int asid,
                         int line, int col)
{
    int es = elem_size_for(atype, asid);
    int idx = build_comma_entry();
    expect(TOK_RBRACKET, "']'");
    int base = ast_new(N_ELEM_ADDR, line, col);
    g_ast[base].sym_lc = lc; g_ast[base].sym_gv = gv;
    g_ast[base].a = idx; g_ast[base].val = 0;
    g_ast[base].val_hi = (unsigned)es;
    g_ast[base].flags = (atype == LT_STRUCT_PTR) ? AF_BASE_LOAD : 0;
    g_ast[base].type = LT_STRUCT_PTR;
    g_ast[base].struct_id = asid;
    if (g_cur.kind != TOK_DOT)
        die(g_cur.line, g_cur.col,
            "struct-array indexed access requires '.field'");
    next_tok();
    if (g_cur.kind != TOK_IDENT)
        die(g_cur.line, g_cur.col, "field name");
    Field *f = field_lookup_dot(asid, g_cur.id_ptr, g_cur.id_len);
    if (f == NULL) die(g_cur.line, g_cur.col, "no such field");
    next_tok();
    /* A RUN OF DOTS PAST THE ELEMENT -- `vs[0].u.n', apple/fgx#314.
     *
     * K&R A.7.3.3 (p.163) makes the production RECURSIVE: "A postfix
     * expression followed by a dot followed by an identifier IS a postfix
     * expression", and "the expression is an lvalue if the first expression is
     * an lvalue, and if the type of the second expression is not an array
     * type".  `vs[0]' is an lvalue by A.7.3.1, and `u' is a structure or union
     * rather than an array, so `vs[0].u' is an lvalue postfix expression and
     * may precede another dot.  Refusing the second dot was an artificial
     * reject, not a limit of the type model.
     *
     * THE ARROW ARM ALREADY DID THIS and this is its twin -- `->arr[i].a.b'
     * folds its run of dots into one cumulative-offset leaf, which is why
     * `p->u.n' compiled while `vs[0].u.n' did not.  Same shape here, so the
     * two spellings emit one node rather than two that agree today: every arm
     * below reads the leaf's `byte_offset' and nothing else from it, so a
     * chain of any depth reaches them looking like a single member at the
     * accumulated offset.  For a single dot the offset equals the real
     * field's and the emitted code is byte-identical. */
    if (f->type == LT_STRUCT && g_cur.kind == TOK_DOT) {
        int cum = f->byte_offset, sid = f->struct_id;
        Field *f2 = f;
        for (;;) {
            next_tok();                        /* consume '.' */
            if (g_cur.kind != TOK_IDENT)
                die(g_cur.line, g_cur.col, "field name");
            f2 = field_lookup_dot(sid, g_cur.id_ptr, g_cur.id_len);
            if (f2 == NULL) die(g_cur.line, g_cur.col, "no such field");
            next_tok();
            cum += f2->byte_offset;
            sid = f2->struct_id;
            if (f2->type == LT_STRUCT && g_cur.kind == TOK_DOT) continue;
            break;
        }
        f = elem_synth_leaf(f2->type, cum, f2->struct_id, f2->is_unsigned);
        f->n_dims = f2->n_dims;            /* the rank rides the fold too */
        f->row_stride = f2->row_stride;
    }
    /* arr[i].field[j] rvalue when field is a char/int array */
    if (g_cur.kind == TOK_LBRACKET &&
        (f->type == LT_CHAR_ARRAY || f->type == LT_INT_ARRAY)) {
        int op_line = g_cur.line, op_col = g_cur.col;
        int row = 0;
        next_tok();                    /* consume '[' */
        int j = build_comma_entry();
        expect(TOK_RBRACKET, "']'");
        /* A RANK-2 field, as the arrow chain folds it: the row index scales by
         * the inner dimension (K&R A.8.6.2, "arrays are stored by rows").  A
         * second subscript adds the column and the element is loaded; without
         * one the result is the ROW, an array whose value (A.7.1) is the
         * address of its first element -- not the element at byte j. */
        if (f->n_dims == 2 && f->row_stride > 0) {
            int es1   = (f->type == LT_CHAR_ARRAY) ? 1 : 2;
            int lit = ast_new(N_LIT_INT, op_line, op_col);
            g_ast[lit].val  = (unsigned)(f->row_stride / es1);
            g_ast[lit].type = LT_INT;
            int mul = ast_new(N_BINOP, op_line, op_col);
            g_ast[mul].a = j; g_ast[mul].b = lit; g_ast[mul].op = TOK_STAR;
            ast_type_scalar_binop(mul, 0, LT_INT, 0, LT_INT, 0);
            j = mul;
            if (g_cur.kind == TOK_LBRACKET) {
                next_tok();            /* consume the second '[' */
                int j2 = build_comma_entry();
                expect(TOK_RBRACKET, "']'");
                int add = ast_new(N_BINOP, op_line, op_col);
                g_ast[add].a = j; g_ast[add].b = j2; g_ast[add].op = TOK_PLUS;
                ast_type_scalar_binop(add, 0, LT_INT, 0, LT_INT, 0);
                j = add;
            } else
                row = 1;
        }
        int n = ast_new(N_SAF_IDX, op_line, op_col);
        g_ast[n].a = base; g_ast[n].b = j; g_ast[n].sym_f = f;
        g_ast[n].flags = (f->type == LT_CHAR_ARRAY) ? AF_IS_BYTE : 0;
        g_ast[n].type = (f->type == LT_CHAR_ARRAY) ? LT_CHAR : LT_INT;
        if (row) {
            g_ast[n].flags |= AF_ROW;
            g_ast[n].type = (f->type == LT_CHAR_ARRAY) ? LT_CHAR_PTR
                                                       : LT_INT_PTR;
        }
        g_ast[n].is_unsigned = f->is_unsigned;
        return n;
    }
    /* apple/fgx#170: arr[i].field[j] rvalue when the element is WIDE -- a long,
     * a float, or a pointer.  The two lines above were the whole list, so a
     * pointer-array member reached through an array-of-structs subscript left
     * the '[' unread and the parse died on "expected ';'".
     *
     * K&R A.7.3.1 (p.162) makes this one production, not a family: "The
     * expression E1[E2] is identical (by definition) to *((E1)+(E2))", and
     * A.7.7 (p.166) fixes the scale -- the index "is converted to an address
     * offset by multiplying it by the size of the object to which the pointer
     * points".  Neither sentence has an element-type condition in it.
     *
     * The STORE arms for these shapes were fixed already (parse_stmt.c's
     * M14-LHS and its sibling); this is the read.  fcc has twin arms for most
     * lvalue shapes and they have to be fixed in pairs. */
    if (g_cur.kind == TOK_LBRACKET &&
        (f->type == LT_LONG_ARRAY || f->type == LT_FLOAT_ARRAY ||
         is_ptr_array(f->type))) {
        int op_line = g_cur.line, op_col = g_cur.col;
        next_tok();                    /* consume '[' */
        int j = build_comma_entry();
        expect(TOK_RBRACKET, "']'");
        int n = ast_new(N_SAF_IDXW, op_line, op_col);
        g_ast[n].a = base; g_ast[n].b = j; g_ast[n].sym_f = f;
        g_ast[n].val_hi = 4;           /* long, float and pointer are all 4 */
        if (f->type == LT_LONG_ARRAY)       g_ast[n].type = LT_LONG;
        else if (f->type == LT_FLOAT_ARRAY) g_ast[n].type = LT_FLOAT;
        else                                g_ast[n].type = DECREF(f->type);
        g_ast[n].struct_id = f->struct_id;
        g_ast[n].is_unsigned = f->is_unsigned;
        /* `arr[i].s[j]->field` -- the subscript yields a STRUCT POINTER, and a
         * postfix chain may continue off it.  The dotted reader does exactly
         * this at its own tail ("G34: '.field->...' -- arrow chain on the
         * loaded pointer value"); without it the '->' is left unread and the
         * parse dies one token later, which is what apple/fgx#170 reported. */
        if (g_ast[n].type == LT_STRUCT_PTR && g_cur.kind == TOK_ARROW) {
            int g34 = ast_new(N_G34_BANK, line, col);
            g_ast[g34].a = n;
            g_ast[g34].type = LT_STRUCT_PTR;
            g_ast[g34].struct_id = f->struct_id;
            return build_postfix_value_chain(g34);
        }
        return n;
    }
    /* array field decay: arr[i].field is &arr[i].field[0].
     *
     * THE SAME LIST, AND THE SAME REASON (apple/fgx#170).  N_FIELD_DECAY is
     * type-agnostic in the emitter -- it adds the field's offset to the element
     * address and stops -- so extending it is a matter of naming the pointer
     * type the result has.  A.7.1 (p.161): an expression of type "array of T"
     * has as its value "a pointer to the first object in the array", with no
     * condition on T. */
    if (f->type == LT_CHAR_ARRAY  || f->type == LT_INT_ARRAY ||
        f->type == LT_LONG_ARRAY  || f->type == LT_FLOAT_ARRAY ||
        f->type == LT_STRUCT_ARRAY || is_ptr_array(f->type)) {
        int n = ast_new(N_FIELD_DECAY, line, col);
        g_ast[n].a = base; g_ast[n].sym_f = f;
        if (f->type == LT_CHAR_ARRAY)        g_ast[n].type = LT_CHAR_PTR;
        else if (f->type == LT_INT_ARRAY)    g_ast[n].type = LT_INT_PTR;
        else if (f->type == LT_LONG_ARRAY)   g_ast[n].type = LT_LONG_PTR;
        else if (f->type == LT_FLOAT_ARRAY)  g_ast[n].type = LT_FLOAT_PTR;
        else if (f->type == LT_STRUCT_ARRAY) g_ast[n].type = LT_STRUCT_PTR;
        else                                 g_ast[n].type = DECREF(f->type);
        g_ast[n].struct_id = f->struct_id;
        /* `arr[i].sa[j]': the decayed pointer subscripted (A.7.3.1) */
        return build_postfix_value_chain(n);
    }
    /* A STRUCT member used as a value is its address: the element address
     * plus the member's offset, which N_ELEM_ADDR carries in `val' (the
     * statement side's `arr[i].m = <struct>' builds the same node).  The load
     * below would hand back the member's first word instead. */
    if (f->type == LT_STRUCT && f->struct_id >= 0) {
        g_ast[base].val = (unsigned)f->byte_offset;
        g_ast[base].type = LT_STRUCT;
        g_ast[base].struct_id = f->struct_id;
        return build_postfix_value_chain(base);
    }
    int n = ast_new(N_FIELD_DEREF, line, col);
    g_ast[n].a = base; g_ast[n].sym_f = f;
    g_ast[n].type = f->type;
    g_ast[n].struct_id = f->struct_id;
    g_ast[n].struct_id = f->struct_id;
    g_ast[n].is_unsigned = f->is_unsigned;
    g_ast[n].fn_sig = (f->type == LT_FN_PTR) ? f->fn_sig_id : -1;
    /* arr[i].fn(args) — dispatch through the fn-ptr field value */
    if (f->type == LT_FN_PTR && g_cur.kind == TOK_LPAREN) {
        int sig = f->fn_sig_id;
        int op_line = g_cur.line, op_col = g_cur.col;
        next_tok();                    /* consume '(' */
        int kid0, n_kids;
        build_call_args(&kid0, &n_kids);
        expect(TOK_RPAREN, "')'");
        int cn = ast_new(N_CALL_STASHED, op_line, op_col);
        g_ast[cn].a = n;
        g_ast[cn].kid0 = kid0; g_ast[cn].n_kids = n_kids;
        g_ast[cn].val = (unsigned)sig;
        g_ast[cn].type = g_fn_sigs[sig].return_type;
        g_ast[cn].is_unsigned = g_fn_sigs[sig].ret_unsigned;   /* A-1 */
        g_ast[cn].fn_sig = -1;
        return cn;
    }
    /* G49: chained subscript on a pointer-valued field */
    return build_postfix_value_chain(n);
}

/* structvar.field... — g_cur is the first '.'. */
static int
build_dot_access(Local *lc, Global *gv, int cur_sid, int line, int col)
{
    int    cum_off = 0;
    Field *leaf    = NULL;
    while (g_cur.kind == TOK_DOT) {
        next_tok();
        if (g_cur.kind != TOK_IDENT)
            die(g_cur.line, g_cur.col, "expected field name after '.'");
        Field *f = field_lookup_dot(cur_sid, g_cur.id_ptr, g_cur.id_len);
        if (f == NULL) die(g_cur.line, g_cur.col, "no such field");
        cum_off += f->byte_offset;
        cur_sid  = f->struct_id;
        leaf     = f;
        next_tok();
    }
    if (leaf->type == LT_STRUCT) {
        /* struct-valued member used as a VALUE — a by-value struct argument
         * (telnet's inet_ntoa(sin.sin_addr)).  Yield the member's ADDRESS typed
         * LT_STRUCT (N_ADDR_DOT_BARE): walk_call_args copies it by value exactly
         * like a whole struct var.  val_hi carries the parent-chain offset so
         * the walker's f->byte_offset + val_hi is the full cum_off. */
        int sn = ast_new(N_ADDR_DOT_BARE, line, col);
        g_ast[sn].sym_lc = lc; g_ast[sn].sym_gv = gv;
        g_ast[sn].sym_f = leaf;
        g_ast[sn].val_hi = (unsigned)(cum_off - leaf->byte_offset);
        g_ast[sn].type = LT_STRUCT;
        g_ast[sn].struct_id = leaf->struct_id;
        return sn;
    }
    if ((leaf->type == LT_CHAR_ARRAY  || leaf->type == LT_INT_ARRAY ||
         leaf->type == LT_LONG_ARRAY  || leaf->type == LT_FLOAT_ARRAY ||
         leaf->type == LT_STRUCT_ARRAY) &&
        g_cur.kind == TOK_LBRACKET) {
        next_tok();                    /* consume '[' */
        int idx = build_comma_entry();
        expect(TOK_RBRACKET, "']'");
        int es = elem_size_for(leaf->type, leaf->struct_id);
        int base = ast_new(N_ELEM_ADDR, line, col);
        g_ast[base].sym_lc = lc; g_ast[base].sym_gv = gv;
        g_ast[base].a = idx;
        g_ast[base].val = (unsigned)cum_off;
        g_ast[base].val_hi = (unsigned)es;
        g_ast[base].type = LT_INT;     /* address value; typed by the load wrap */
        if (leaf->type == LT_CHAR_ARRAY || leaf->type == LT_INT_ARRAY) {
            int n = ast_new((leaf->type == LT_CHAR_ARRAY) ? N_ELEM_CHAR
                                                          : N_ELEM_INT,
                            line, col);
            g_ast[n].a = base; g_ast[n].sym_f = leaf;
            g_ast[n].type = (leaf->type == LT_CHAR_ARRAY) ? LT_CHAR : LT_INT;
            g_ast[n].is_unsigned = leaf->is_unsigned;
            return n;
        }
        if (leaf->type == LT_LONG_ARRAY || leaf->type == LT_FLOAT_ARRAY) {
            int n = ast_new(N_ELEM_LONG, line, col);
            g_ast[n].a = base; g_ast[n].sym_f = leaf;
            g_ast[n].type = (leaf->type == LT_FLOAT_ARRAY) ? LT_FLOAT : LT_LONG;
            g_ast[n].is_unsigned = leaf->is_unsigned;
            return n;
        }
        /* LT_STRUCT_ARRAY: chain into '.subfield' */
        if (g_cur.kind != TOK_DOT)
            die(g_cur.line, g_cur.col,
                "struct-array element via '.' requires '.field'");
        next_tok();
        if (g_cur.kind != TOK_IDENT)
            die(g_cur.line, g_cur.col, "field name");
        Field *f2 = field_lookup_dot(leaf->struct_id,
                                     g_cur.id_ptr, g_cur.id_len);
        if (f2 == NULL) die(g_cur.line, g_cur.col, "no such field");
        next_tok();
        int n = ast_new(N_ELEM_FIELD, line, col);
        g_ast[n].a = base; g_ast[n].sym_f2 = f2;
        g_ast[n].type = f2->type;
        g_ast[n].struct_id = f2->struct_id;
        g_ast[n].is_unsigned = f2->is_unsigned;
        return n;
    }
    /* obj.field(args) — fn-pointer field call */
    if (leaf->type == LT_FN_PTR && g_cur.kind == TOK_LPAREN) {
        int sig = leaf->fn_sig_id;
        int op_line = g_cur.line, op_col = g_cur.col;
        next_tok();                    /* consume '(' */
        int kid0, n_kids;
        build_call_args(&kid0, &n_kids);
        expect(TOK_RPAREN, "')'");
        int n = ast_new(N_CALL_FPFIELD, op_line, op_col);
        g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
        g_ast[n].sym_f = leaf;
        g_ast[n].val = (unsigned)sig;
        g_ast[n].val_hi = (unsigned)cum_off;
        g_ast[n].kid0 = kid0; g_ast[n].n_kids = n_kids;
        g_ast[n].type = g_fn_sigs[sig].return_type;
        g_ast[n].is_unsigned = g_fn_sigs[sig].ret_unsigned;   /* A-1 */
        return n;
    }
    /* Bare array-member decay, for EVERY element type.  K&R A.7.1, p.161:
     * "the value of the expression is a pointer to the first object in the
     * array, and the type of the expression is altered to ``pointer to T''" --
     * with no exemption for what T is.
     *
     * IT USED TO NAME TWO TYPES, LT_CHAR_ARRAY and LT_INT_ARRAY, so a member
     * array of anything 4 bytes wide -- long, unsigned long, float, a pointer,
     * a struct -- fell past this into the N_DOT_SCALAR load below and the
     * expression became element [0]'s VALUE.  Not a width error: a different
     * object.  `bcmp(x, zino.di_addr, 52)' passed the contents of di_addr[0],
     * which for a zeroed inode is 0, so bcmp compared 52 bytes at address 0 --
     * the direct page, whose contents depend on which driver is live.  fsck
     * then called an intact filesystem corrupt on one disk controller and
     * clean on another, and /etc/rc's `fsck -p' repaired it.  apple/fgx#409.
     *
     * ISARY plus INCREF(DECREF(t), DERIV_PTR) is the general spelling the rest
     * of this file already uses (lv_chain_value, N_ADDR_ARROW_ARRFIELD), and
     * it is byte-identical for the two types that were named: DECREF peels the
     * ARY group, INCREF pushes PTR.  The emitter needs nothing -- it computes
     * `&sym + offset' into an FPR and takes the type from this node. */
    if (ISARY(leaf->type)) {
        int n = ast_new(N_DOT_ARRAY_DECAY, line, col);
        g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
        g_ast[n].val = (unsigned)cum_off;
        g_ast[n].sym_f = leaf;
        g_ast[n].type = INCREF(DECREF(leaf->type), DERIV_PTR);
        g_ast[n].struct_id = leaf->struct_id;
        return n;
    }
    /* postfix '++'/'--' on a single-hop scalar/pointer member (rvalue) — the
     * dot twin of build_arrow_access's member incdec (telnet's settimer:
     * `clocks.x = clocks.system++`).  Gated to cum_off == leaf offset so
     * emit_member_incdec's f->byte_offset is the full offset (single hop). */
    if ((g_cur.kind == TOK_PLUSPLUS || g_cur.kind == TOK_MINUSMINUS) &&
        cum_off == leaf->byte_offset &&
        (leaf->type == LT_INT || leaf->type == LT_LONG ||
         leaf->type == LT_CHAR ||                     /* apple/fgx#215 */
         (ISPTR(leaf->type) && leaf->type != LT_FN_PTR &&
          BTYPE(DECREF(leaf->type)) != BT_STRUCT))) {
        int is_inc = (g_cur.kind == TOK_PLUSPLUS);
        next_tok();
        int mn = ast_new(N_POSTINC_MEMBER, line, col);
        g_ast[mn].sym_lc = lc; g_ast[mn].sym_gv = gv; g_ast[mn].sym_f = leaf;
        g_ast[mn].flags = is_inc ? AF_IS_INC : 0;
        g_ast[mn].type = leaf->type;
        g_ast[mn].struct_id = leaf->struct_id;
        return mn;
    }

    /* scalar leaf load via a synthetic field at the cumulative offset */
    int n = ast_new(N_DOT_SCALAR, line, col);
    g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
    g_ast[n].sym_f = leaf;
    g_ast[n].val = (unsigned)cum_off;
    g_ast[n].type = leaf->type;
    g_ast[n].struct_id = leaf->struct_id;
    g_ast[n].struct_id = leaf->struct_id;
    g_ast[n].is_unsigned = leaf->is_unsigned;
    /* G34: '.field->...' — arrow chain on the loaded pointer value */
    if (leaf->type == LT_STRUCT_PTR && g_cur.kind == TOK_ARROW) {
        int g34 = ast_new(N_G34_BANK, line, col);
        g_ast[g34].a = n;
        g_ast[g34].type = LT_STRUCT_PTR;
        g_ast[g34].struct_id = leaf->struct_id;
        return build_postfix_value_chain(g34);
    }
    return n;
}

/* Per-node synthetic leaf field for a dot-chain past an indexed struct-array
 * element (`p->arr[i].a.b.c`): N_ELEM_FIELD derefs base+byte_offset at the
 * leaf's type, so folding the whole `.a.b.c` run into ONE field with the
 * cumulative offset lets the existing node serve any depth.  For a single dot
 * the offset equals the real field's, so the emitted code is byte-identical.
 * A small persistent pool: each such chain node keeps its own Field. */
static Field g_elem_synth[256];
static int   g_n_elem_synth = 0;
Field *
elem_synth_leaf(LocalType type, int off, int sid, int uns)
{
    if (g_n_elem_synth >= 256)
        die(g_cur.line, g_cur.col,
            "too many indexed-member '.' chains in one function");
    Field *f = &g_elem_synth[g_n_elem_synth++];
    f->name = "(elem)"; f->type = type; f->struct_id = sid;
    f->fn_sig_id = -1; f->n_elems = 1; f->byte_offset = off;
    f->byte_size = 0; f->is_bit_field = 0; f->bit_offset = 0;
    f->bit_width = 0; f->is_unsigned = uns;
    f->n_dims = 1; f->row_stride = 0;      /* callers carry a rank-2 leaf's */
    return f;
}

/* Peek (token-vector scan, no consume), g_cur at a '[': is this the ONLY
 * subscript -- does the matching ']' NOT open a second one?  On a rank-2 member
 * that makes the result a ROW.  K&R A.8.6.2 (p.177): "x3d[i][j] is an array of
 * 7 integers, and x3d[i] is an array of 5 arrays of 7 integers" -- so one
 * subscript on `m[R][C]' is an array of C, whose value (A.7.1) is a pointer to
 * its first element, i*C elements into the member.  The fixed arms below index
 * a member as rank 1 and LOAD the element, which is right for `m[i][j]' folded
 * to one index and wrong for a row. */
static int
single_subscript_ahead(void)
{
    int i = g_tok_idx - 1, d = 0;             /* at the '[' */
    do {
        if (g_toks[i].kind == TOK_LBRACKET)       d++;
        else if (g_toks[i].kind == TOK_RBRACKET)  d--;
        else if (g_toks[i].kind == TOK_EOF)       return 0;
        i++;
    } while (d);
    return g_toks[i].kind != TOK_LBRACKET;
}

/* The whole `NAME->...' run, re-read from its first '->' by the walker, as a
 * value (lv_chain_value).  For the shapes build_arrow_access's fixed nodes do
 * not express. */
static int
arrow_run_value(LexPeek *pk_base, Local *lc, Global *gv, int cur_sid,
                int line, int col)
{
    lex_peek_restore(pk_base);
    int lvh = ast_new(N_LV_CHAIN, line, col);
    g_ast[lvh].c = -1;
    g_ast[lvh].sym_lc = lc; g_ast[lvh].sym_gv = gv;
    build_lvalue_suffixes(lvh, lc ? lc->type : gv->type, cur_sid);
    return lv_chain_value(lvh, line, col);
}

/* ptr->field... — g_cur is the '->'. */
static int
build_arrow_access(Local *lc, Global *gv, int cur_sid, int line, int col)
{
    LexPeek pk_base;
    lex_peek_save(&pk_base);           /* at the first '->', for the #86 arm */
    next_tok();                        /* consume '->' */
    if (g_cur.kind != TOK_IDENT)
        die(g_cur.line, g_cur.col, "expected field name after '->'");
    Field *f = struct_field_lookup(cur_sid, g_cur.id_ptr, g_cur.id_len);
    if (f == NULL) die(g_cur.line, g_cur.col, "no such field");
    next_tok();

    /* '->structfield.sub...' — inline struct/union VALUE + '.' chain */
    if (f->type == LT_STRUCT && g_cur.kind == TOK_DOT) {
        int    cum  = f->byte_offset;
        int    sid2 = f->struct_id;
        Field *leaf = f;
        for (;;) {
            next_tok();                /* consume '.' */
            if (g_cur.kind != TOK_IDENT)
                die(g_cur.line, g_cur.col, "field name after '.'");
            Field *sf = field_lookup_dot(sid2, g_cur.id_ptr, g_cur.id_len);
            if (sf == NULL) die(g_cur.line, g_cur.col, "no such field");
            next_tok();
            cum += sf->byte_offset;
            leaf = sf; sid2 = sf->struct_id;
            if (sf->type == LT_STRUCT && g_cur.kind == TOK_DOT) continue;
            break;
        }
        int lt = leaf->type;
        /* A ROW of a rank-2 member (`f->f_un.f_uname[i]', syslogd): the walker
         * re-seeds the rank on a member step and yields &m[i][0].  The pair
         * `m[i][j]' stays on the fold below. */
        if (leaf->n_dims == 2 && g_cur.kind == TOK_LBRACKET &&
            single_subscript_ahead())
            return arrow_run_value(&pk_base, lc, gv, cur_sid, line, col);
        if ((lt == LT_CHAR_ARRAY || lt == LT_INT_ARRAY) &&
            g_cur.kind == TOK_LBRACKET) {
            next_tok();                /* consume '[' */
            int j = build_comma_entry();
            expect(TOK_RBRACKET, "']'");
            /* M19b: a RANK-2 field takes a SECOND subscript, and K&R A.8.6.2
             * (p.177) says exactly how to fold them: "arrays are stored by rows
             * (last subscript varies fastest)" and the declaration's first
             * subscript "plays no other part in subscript calculations".  So
             * the row index scales by the INNER dimension and the pair becomes
             * the one index this node already carries -- `*(base + i*inner + j)',
             * which is the identity A.8.6.2 gives for x3d[i][j].  Without this
             * the '[' was left unread and the parse died "expected ')'", which
             * is apple/fgx#477's first half on the READ side. */
            if (leaf->n_dims == 2 && leaf->row_stride > 0 &&
                g_cur.kind == TOK_LBRACKET) {
                int es1   = (lt == LT_CHAR_ARRAY) ? 1 : 2;
                int inner = leaf->row_stride / es1;
                next_tok();                /* consume the second '[' */
                int j2 = build_comma_entry();
                expect(TOK_RBRACKET, "']'");
                int lit = ast_new(N_LIT_INT, line, col);
                g_ast[lit].val  = (unsigned)inner;
                g_ast[lit].type = LT_INT;
                int mul = ast_new(N_BINOP, line, col);
                g_ast[mul].a = j; g_ast[mul].b = lit; g_ast[mul].op = TOK_STAR;
                ast_type_scalar_binop(mul, 0, LT_INT, 0, LT_INT, 0);
                int add = ast_new(N_BINOP, line, col);
                g_ast[add].a = mul; g_ast[add].b = j2; g_ast[add].op = TOK_PLUS;
                ast_type_scalar_binop(add, 0, LT_INT, 0, LT_INT, 0);
                j = add;
            }
            int n = ast_new(N_AV_ELEM_ADDR, line, col);
            g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
            g_ast[n].val = (unsigned)cum;
            g_ast[n].a = j;
            g_ast[n].flags = (lt == LT_CHAR_ARRAY) ? AF_IS_BYTE : 0;
            g_ast[n].type = (lt == LT_CHAR_ARRAY) ? LT_CHAR : LT_INT;
            return n;
        }
        /* apple/fgx#180's LOUD TWIN, and it is the same partial list one line
         * up: subscripting a LONG, FLOAT, STRUCT or POINTER array member in a
         * dotted chain past an arrow matched neither arm, so the '[' was left
         * unread and the parse died on "expected ')'".  `ip->i_din.di_addr[i]`
         * is the natural spelling of a 2.11BSD block address and 1.11c reaches
         * for it.
         *
         * It is built exactly as the one-hop `->arr[i]` arm below builds its
         * own -- N_ELEM_ADDR with the cumulative offset in place of the single
         * member's, then the same four wraps -- so the two spellings emit the
         * same shape rather than two shapes that agree today. */
        /* ...and its 8-byte elements, for the one-hop arm's reason below. */
        if ((lt == LT_DOUBLE_ARRAY || lt == LT_LLONG_ARRAY) &&
            g_cur.kind == TOK_LBRACKET)
            return arrow_run_value(&pk_base, lc, gv, cur_sid, line, col);
        if ((lt == LT_LONG_ARRAY || lt == LT_FLOAT_ARRAY ||
             lt == LT_STRUCT_ARRAY || is_ptr_array(lt)) &&
            g_cur.kind == TOK_LBRACKET) {
            next_tok();                /* consume '[' */
            int idx = build_comma_entry();
            expect(TOK_RBRACKET, "']'");
            int es = elem_size_for(lt, leaf->struct_id);
            int base = ast_new(N_ELEM_ADDR, line, col);
            g_ast[base].sym_lc = lc; g_ast[base].sym_gv = gv;
            g_ast[base].a = idx;
            g_ast[base].val = (unsigned)cum;
            g_ast[base].val_hi = (unsigned)es;
            g_ast[base].flags = AF_BASE_LOAD | AF_ADC_ALWAYS;
            g_ast[base].type = LT_INT;   /* address value; typed by the wrap */
            if (lt == LT_LONG_ARRAY || lt == LT_FLOAT_ARRAY) {
                int n = ast_new(N_ELEM_LONG, line, col);
                g_ast[n].a = base; g_ast[n].sym_f = leaf;
                g_ast[n].type = (lt == LT_FLOAT_ARRAY) ? LT_FLOAT : LT_LONG;
                g_ast[n].is_unsigned = leaf->is_unsigned;
                return n;
            }
            if (is_ptr_array(lt)) {
                int n = ast_new(N_ELEM_PTRELEM, line, col);
                g_ast[n].a = base;
                g_ast[n].val = (unsigned)DECREF(lt);
                g_ast[n].type = DECREF(lt);
                g_ast[n].struct_id = leaf->struct_id;
                return n;
            }
            /* LT_STRUCT_ARRAY: continue with '.subfield', as the arrow arm
             * does.  The element itself is a struct value: the walker's. */
            if (g_cur.kind != TOK_DOT)
                return arrow_run_value(&pk_base, lc, gv, cur_sid, line, col);
            next_tok();
            if (g_cur.kind != TOK_IDENT)
                die(g_cur.line, g_cur.col, "field name");
            Field *f3 = field_lookup_dot(leaf->struct_id,
                                         g_cur.id_ptr, g_cur.id_len);
            if (f3 == NULL) die(g_cur.line, g_cur.col, "no such field");
            next_tok();
            int n = ast_new(N_ELEM_FIELD, line, col);
            g_ast[n].a = base; g_ast[n].sym_f2 = f3;
            g_ast[n].type = f3->type;
            g_ast[n].struct_id = f3->struct_id;
            g_ast[n].is_unsigned = f3->is_unsigned;
            return n;
        }
        if (lt == LT_CHAR_ARRAY || lt == LT_INT_ARRAY) {
            int n = ast_new(N_AV_DECAY, line, col);
            g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
            g_ast[n].val = (unsigned)cum;
            g_ast[n].sym_f = leaf;
            g_ast[n].flags = 0;        /* AVS decay: sid := -1, uns := 0 */
            g_ast[n].type = (lt == LT_CHAR_ARRAY) ? LT_CHAR_PTR : LT_INT_PTR;
            return n;
        }
        /* apple/fgx#180: THE OTHER FOUR ARRAY TYPES DECAY TOO.  The two lines
         * above were the whole list, so `p->s.longarr` -- an array member one
         * `.` hop past an arrow -- fell through to N_AV_SCALAR below and was
         * LOADED: fcc read the first element as a scalar and pushed it where
         * the callee expected a pointer.  Two bytes instead of four, so every
         * argument after it shifted, and `ufs_bmap(ip->i_devvp, ip->i_addr,
         * lbn, &bn)` got the lbn its caller had put two bytes further up.
         *
         * K&R A.7.1 (p.161): "If the type of an expression or subexpression is
         * ``array of T,'' for some type T, then the value of the expression is
         * a pointer to the first object in the array, and the type of the
         * expression is altered to ``pointer to T.''"  The exception list --
         * "the operand of the unary & operator, or of ++, --, sizeof, or as the
         * left operand of an assignment operator or the . operator" -- does not
         * reach this: the array here is the RIGHT operand of `.`, so nothing
         * suspends the conversion, and the ELEMENT TYPE is not among the
         * conditions.  A decay list with four types missing is not a narrower
         * reading of that sentence; it is the sentence applied to some types.
         *
         * The one-hop `->arr` arm below already carries CHAR/INT/STRUCT/LONG
         * with AF_BASE_LOAD, so this is also the two arms agreeing.  CHAR and
         * INT keep their existing `flags = 0` spelling above rather than being
         * folded in, because that changes the struct-id and unsignedness the
         * node reports and every golden covering them was taken against it. */
        if (lt == LT_LONG_ARRAY || lt == LT_FLOAT_ARRAY ||
            lt == LT_STRUCT_ARRAY || is_ptr_array(lt)) {
            int n = ast_new(N_AV_DECAY, line, col);
            g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
            g_ast[n].val = (unsigned)cum;
            g_ast[n].sym_f = leaf;
            /* AF_BASE_LOAD keeps the leaf's struct identity on the result, which
             * a struct-array decay needs and a pointer-array decay needs for the
             * same reason N_ELEM_PTRELEM does: without it the value is a pointer
             * to NOTHING and any member resolved on it has no struct to look in. */
            g_ast[n].flags = AF_BASE_LOAD;
            g_ast[n].struct_id = leaf->struct_id;
            if (lt == LT_LONG_ARRAY)        g_ast[n].type = LT_LONG_PTR;
            else if (lt == LT_FLOAT_ARRAY)  g_ast[n].type = LT_FLOAT_PTR;
            else if (lt == LT_STRUCT_ARRAY) g_ast[n].type = LT_STRUCT_PTR;
            else                            g_ast[n].type = DECREF(lt);
            return n;
        }
        /* A plain POINTER leaf one or more '.' hops past an arrow, then
         * INDEXED: `bw->o.rmsg[i]` (joe tw.c, rmsg a char*).  The array cases
         * above DECAY; a pointer leaf's VALUE must be LOADED and then indexed
         * (deref+scale), which the uniform walker does.  Route the whole run
         * there; without this the '[' was left unread and the parse died.  A
         * non-indexed pointer leaf keeps N_AV_SCALAR below. */
        if (ISPTR(lt) && lt != LT_FN_PTR && g_cur.kind == TOK_LBRACKET)
            return arrow_run_value(&pk_base, lc, gv, cur_sid, line, col);
        /* A STRUCT leaf used as a VALUE is its ADDRESS, as it is one '->' hop
         * in (below) and after a '.' (N_ADDR_DOT_BARE): a by-value argument
         * copies through it.  N_AV_SCALAR loads its first bytes instead, so
         * 2.11BSD ntp's ntoa(peer->src.sin_addr) formatted garbage. */
        if (lt == LT_STRUCT)
            return arrow_run_value(&pk_base, lc, gv, cur_sid, line, col);
        int n = ast_new(N_AV_SCALAR, line, col);
        g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
        g_ast[n].val = (unsigned)cum;
        g_ast[n].sym_f = leaf;
        g_ast[n].type = lt;
        g_ast[n].struct_id = leaf->struct_id;
        return n;
    }

    /* A RANK-2 member one '->' hop in, subscripted: the walker, which knows
     * the rank.  This arm indexes as rank 1, so it read `p->m[i]' as the
     * element at byte i and left the second '[' of `p->m[i][j]' unread. */
    if (f->n_dims == 2 && g_cur.kind == TOK_LBRACKET)
        return arrow_run_value(&pk_base, lc, gv, cur_sid, line, col);

    /* An 8-byte element -- a DOUBLE or LONG LONG array member -- one '->' hop
     * in, subscripted: the walker, which reads the element through its
     * pointer type (LT_DOUBLE_PTR -> LT_DOUBLE).  The arm below loads at most
     * four bytes, and its list stopped at the 4-byte types, so the '[' was
     * left unread and the parse died on "expected ';'" (2.11BSD ntp's
     * `peer->filter.offset[i - 1]').  K&R A.7.3.1: "The expression E1[E2] is
     * identical (by definition) to *((E1)+(E2))" -- no element-type
     * condition. */
    if ((f->type == LT_DOUBLE_ARRAY || f->type == LT_LLONG_ARRAY) &&
        g_cur.kind == TOK_LBRACKET)
        return arrow_run_value(&pk_base, lc, gv, cur_sid, line, col);

    /* '->arr_field[i]' — inline array member indexed */
    if ((f->type == LT_CHAR_ARRAY  || f->type == LT_INT_ARRAY ||
         f->type == LT_LONG_ARRAY  || f->type == LT_FLOAT_ARRAY ||
         f->type == LT_STRUCT_ARRAY ||
         is_ptr_array(f->type)) &&
        g_cur.kind == TOK_LBRACKET) {
        next_tok();                    /* consume '[' */
        int idx = build_comma_entry();
        expect(TOK_RBRACKET, "']'");
        int es = elem_size_for(f->type, f->struct_id);
        int base = ast_new(N_ELEM_ADDR, line, col);
        g_ast[base].sym_lc = lc; g_ast[base].sym_gv = gv;
        g_ast[base].a = idx;
        g_ast[base].val = (unsigned)f->byte_offset;
        g_ast[base].val_hi = (unsigned)es;
        g_ast[base].flags = AF_BASE_LOAD | AF_ADC_ALWAYS;
        g_ast[base].type = LT_INT;     /* address value; typed by the wrap */
        if (f->type == LT_CHAR_ARRAY || f->type == LT_INT_ARRAY) {
            int n = ast_new((f->type == LT_CHAR_ARRAY) ? N_ELEM_CHAR
                                                       : N_ELEM_INT,
                            line, col);
            g_ast[n].a = base; g_ast[n].sym_f = f;
            g_ast[n].type = (f->type == LT_CHAR_ARRAY) ? LT_CHAR : LT_INT;
            g_ast[n].is_unsigned = f->is_unsigned;
            return n;
        }
        if (f->type == LT_LONG_ARRAY || f->type == LT_FLOAT_ARRAY) {
            int n = ast_new(N_ELEM_LONG, line, col);
            g_ast[n].a = base; g_ast[n].sym_f = f;
            g_ast[n].type = (f->type == LT_FLOAT_ARRAY) ? LT_FLOAT : LT_LONG;
            g_ast[n].is_unsigned = f->is_unsigned;
            return n;
        }
        if (is_ptr_array(f->type)) {
            int n = ast_new(N_ELEM_PTRELEM, line, col);
            g_ast[n].a = base;
            g_ast[n].val = (unsigned)DECREF(f->type);
            g_ast[n].type = DECREF(f->type);
            /* Carry the element's STRUCT IDENTITY.  Without it the node kept
             * ast_new's -1, so `p->v_link[i]` was typed struct-pointer-to-
             * NOTHING: any consumer that needs to resolve a member on the
             * result had no struct to look in.  That is why
             * `(p->v_link[1])->v_link[0]` failed to parse while the
             * paren-less spelling worked (tcsh sh.set's rotate macros applied
             * to `p->v_right`). */
            g_ast[n].struct_id = f->struct_id;
            return n;
        }
        /* LT_STRUCT_ARRAY: continue with '.subfield' [ '.subfield' ... ].
         * A run of dots past the indexed element -- `kmap->keys[x].value.scal'
         * (joe kbd.c) -- accumulates into one cumulative-offset leaf; a single
         * dot keeps the leaf's own offset, so its emit is byte-identical. */
        if (g_cur.kind != TOK_DOT)             /* the element: a struct value */
            return arrow_run_value(&pk_base, lc, gv, cur_sid, line, col);
        int cum2 = 0, sid2 = f->struct_id;
        Field *f2 = NULL;
        for (;;) {
            next_tok();                        /* consume '.' */
            if (g_cur.kind != TOK_IDENT)
                die(g_cur.line, g_cur.col, "field name");
            f2 = field_lookup_dot(sid2, g_cur.id_ptr, g_cur.id_len);
            if (f2 == NULL) die(g_cur.line, g_cur.col, "no such field");
            next_tok();
            cum2 += f2->byte_offset;
            sid2 = f2->struct_id;
            if (f2->type == LT_STRUCT && g_cur.kind == TOK_DOT) continue;
            break;
        }
        int n = ast_new(N_ELEM_FIELD, line, col);
        g_ast[n].a = base;
        g_ast[n].sym_f2 = elem_synth_leaf(f2->type, cum2, f2->struct_id,
                                          f2->is_unsigned);
        g_ast[n].type = f2->type;
        g_ast[n].struct_id = f2->struct_id;
        g_ast[n].is_unsigned = f2->is_unsigned;
        return n;
    }

    /* array member, no '[': array-to-pointer decay */
    if (f->type == LT_CHAR_ARRAY  || f->type == LT_INT_ARRAY ||
        f->type == LT_STRUCT_ARRAY || f->type == LT_LONG_ARRAY) {
        int n = ast_new(N_AV_DECAY, line, col);
        g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
        g_ast[n].val = (unsigned)f->byte_offset;
        g_ast[n].sym_f = f;
        g_ast[n].flags = AF_BASE_LOAD;   /* full-decay variant: sid := f->struct_id */
        switch (f->type) {
            case LT_CHAR_ARRAY:   g_ast[n].type = LT_CHAR_PTR;   break;
            case LT_INT_ARRAY:    g_ast[n].type = LT_INT_PTR;    break;
            case LT_STRUCT_ARRAY: g_ast[n].type = LT_STRUCT_PTR; break;
            default:              g_ast[n].type = LT_LONG_PTR;   break;
        }
        g_ast[n].struct_id = f->struct_id;
        return n;
    }

    /* postfix '++'/'--' on a single-hop scalar/pointer member (rvalue).  Any
     * non-struct, non-fn pointer member is admitted -- emit_member_incdec is
     * depth-agnostic (ptr_stride drives the bump: 4 for a ptr-to-ptr like
     * tcsh's `Char **w_fe`) and RMWs the member word in place preserving its
     * stored bank, so a depth-2+ pointer member is correct by construction.
     * struct* (wrong ptr_stride) and fn-ptr (nonsensical) stay out. */
    if ((g_cur.kind == TOK_PLUSPLUS || g_cur.kind == TOK_MINUSMINUS) &&
        (f->type == LT_INT || f->type == LT_LONG ||
         f->type == LT_CHAR ||                        /* apple/fgx#215 */
         (ISPTR(f->type) && f->type != LT_FN_PTR &&
          BTYPE(DECREF(f->type)) != BT_STRUCT))) {
        int is_inc = (g_cur.kind == TOK_PLUSPLUS);
        next_tok();
        int n = ast_new(N_POSTINC_MEMBER, line, col);
        g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv; g_ast[n].sym_f = f;
        g_ast[n].flags = is_inc ? AF_IS_INC : 0;
        g_ast[n].type = f->type;
        g_ast[n].struct_id = f->struct_id;
        g_ast[n].struct_id = f->struct_id;
        return n;
    }

    /* postfix '++'/'--' on a member chain that CONTINUES, in VALUE position
     * (`v = op->ip->n++` -- apple/fgx#86).  The single-hop arm above takes one
     * member; a first member that is itself a struct pointer fell through to
     * the G22 chain READER below, which loads and cannot bump, so the '++' was
     * left unconsumed and reported as a missing ';'.
     *
     * K&R A.7.4.1 takes ++/-- on any modifiable lvalue and says nothing about
     * how many hops reached it, so this is the same operation the one-hop arm
     * performs.  The PREFIX twin already routes the continuing chain through
     * the uniform walker (build_unary's '++' arm); this is that arm with
     * AF_RET_OLD, which N_LV_INCDEC_E has carried since the `(*p)++` case --
     * so the read-modify-write that keeps the old value already existed and
     * only the parse was missing.
     *
     * Gated on the chain really continuing AND on the run terminating in
     * ++/--, so anything else still fails closed in the reader below rather
     * than quietly taking a different path. */
    /* The run continues past this member, or ends on a leaf the fixed-shape
     * node cannot bump.  THREE WAYS IN, and all three were measured to reject
     * before this widened -- `q->S.a++' in value position is as unsupported as
     * the char one, so routing the dot case here diverts nothing that worked:
     *   - a struct POINTER member and another '->'  (apple/fgx#86)
     *   - a struct VALUE member and a '.'           (apple/fgx#215)
     *
     * A CHAR LEAF USED TO BE A THIRD REASON and is not one any more:
     * emit_incdec_at_fcc_ptr grew an 8-bit arm (apple/fgx#215, #216), so the
     * fixed-shape node bumps a byte correctly and the walker detour is dead
     * weight. */
    if (((f->type == LT_STRUCT_PTR && g_cur.kind == TOK_ARROW) ||
         (f->type == LT_STRUCT && g_cur.kind == TOK_DOT)) &&
        value_chain_ends_in_incdec()) {
        lex_peek_restore(&pk_base);       /* back to the first '->' */
        int head = ast_new(N_LV_CHAIN, line, col);
        g_ast[head].c = -1;
        g_ast[head].sym_lc = lc; g_ast[head].sym_gv = gv;
        build_lvalue_suffixes(head, lc ? lc->type : gv->type, cur_sid);
        LocalType lf = g_ast[head].type;
        require_assignable(lf, TOK_PLUSPLUS);
        int is_inc = (g_cur.kind == TOK_PLUSPLUS);
        next_tok();                       /* consume '++' / '--' */
        int st = incdec_stride(lf, g_ast[head].struct_id);
        int nn = ast_new(N_LV_INCDEC_E, line, col);
        g_ast[nn].a         = head;
        g_ast[nn].val       = (unsigned)st;
        g_ast[nn].flags     = (is_inc ? AF_IS_INC : 0) | AF_RET_OLD;
        g_ast[nn].type      = lf;
        g_ast[nn].struct_id = g_ast[head].struct_id;
        return nn;
    }

    /* scalar field / '->' chain (G22) */
    int hop0 = g_n_ast_fields, n_hops = 0;
    while (f->type == LT_STRUCT_PTR && g_cur.kind == TOK_ARROW) {
        int next_sid = f->struct_id;
        if (g_n_ast_fields >= MAX_AST_KIDS)
            die(g_cur.line, g_cur.col, "arrow-chain hop pool overflow");
        g_ast_fields[g_n_ast_fields++] = f; n_hops++;
        next_tok();                    /* consume '->' */
        if (g_cur.kind != TOK_IDENT)
            die(g_cur.line, g_cur.col, "expected field name after '->'");
        f = struct_field_lookup(next_sid, g_cur.id_ptr, g_cur.id_len);
        if (f == NULL) die(g_cur.line, g_cur.col, "no such field");
        next_tok();
        if (f->type == LT_CHAR_ARRAY || f->type == LT_INT_ARRAY ||
            f->type == LT_STRUCT_ARRAY || f->type == LT_LONG_ARRAY ||
            f->type == LT_FLOAT_ARRAY || is_ptr_array(f->type)) {
            /* AN ARRAY FIELD AT THE END OF A MULTI-HOP RUN (apple/fgx#200).
             * Includes an array-of-pointers member (`P *marks[10]`, joe b.h) --
             * `bw->b->marks[c]` indexes it to a P*; the walker's index step
             * yields the element and N_LV_LOAD_E loads it.
             *
             * N_ARROW_LOAD_CHAIN below LOADS its leaf, which is meaningless
             * for an array -- what a read of `p->q->arr' yields is the array's
             * ADDRESS (A.7.1: "an lvalue of type array of T is converted to a
             * pointer to the first object in the array").  The one-hop
             * spelling has said so since N_AV_DECAY, and that node carries a
             * single byte_offset off a NAMED base, so it cannot express a run.
             *
             * Route the whole run through the uniform lvalue walker instead --
             * the same machinery the ADDRESS-OF and STORE spellings of this
             * exact shape already use, which is why `&p->q->arr[0]' and
             * `p->q->arr[1] = c' have always compiled while the plain read did
             * not.  Three copies of the arrow run, three emitters, and this
             * was the one with the hole (the shape of apple/fgx#189).
             *
             * The walker consumes any further `[i]' / `.f' / `->f' itself, so
             * the LEAF TYPE decides the wrapper (lv_chain_value). */
            return arrow_run_value(&pk_base, lc, gv, cur_sid, line, col);
        }
        /* A struct-VALUE member reached PAST the first hop, then '.field'
         * (one or more): `undo->ptr->link.prev` (joe undo.c, uundo -- an
         * intrusive-list LINK() struct one arrow past a pointer member).  The
         * G22 loop stops here because a struct leaf is not a STRUCT_PTR, and
         * N_ARROW_LOAD_CHAIN cannot carry the trailing '.', so the dot was left
         * for build_postfix_value_chain -- which folded the member offset onto
         * the BASE LOCAL's frame slot and DROPPED every '->' hop, reading a
         * word from the local frame (garbage, and in the return-address band
         * when the offset is large enough for stack_check to catch it; silently
         * wrong data otherwise).  The single-arrow spelling `p->emb.field' is
         * handled by the struct-value arm at the top of this function; this is
         * that arm for a LATER hop.  Route the whole run through the uniform
         * lvalue walker -- the same machinery the STORE (`...=x') and
         * address-of (`&...') spellings of this exact shape already use. */
        if (f->type == LT_STRUCT && g_cur.kind == TOK_DOT)
            return arrow_run_value(&pk_base, lc, gv, cur_sid, line, col);
    }
    /* A STRUCT member used as a VALUE is its ADDRESS, as build_dot_access's
     * N_ADDR_DOT_BARE is: every struct-value consumer -- a by-value argument,
     * a struct copy's source, a `.' applied to it -- copies or reads THROUGH
     * it.  N_ARROW_LOAD_CHAIN loads the member's first word, which is not
     * one. */
    if (f->type == LT_STRUCT)
        return arrow_run_value(&pk_base, lc, gv, cur_sid, line, col);
    int n = ast_new(N_ARROW_LOAD_CHAIN, line, col);
    g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
    g_ast[n].kid0 = hop0; g_ast[n].n_kids = n_hops;
    g_ast[n].sym_f = f;
    g_ast[n].type = f->type;
    g_ast[n].struct_id = f->struct_id;
    g_ast[n].struct_id = f->struct_id;
    g_ast[n].is_unsigned = f->is_unsigned;
    g_ast[n].fn_sig = (f->type == LT_FN_PTR) ? f->fn_sig_id : -1;
    /* G22: index the chain's pointer result */
    return build_postfix_value_chain(n);
}

/* Entry used by nested index expressions inside build_unary (their parse
 * counterparts call parse_expr, i.e. the assignment level). */
static int
build_comma_entry(void)
{
    return build_assign();
}

/* A CONSTANT ON EITHER SIDE OF `*' (apple/fgx#453).  The bare-literal arm of
 * build_mul_expr sees only `x * 4' with the 4 as the next token.  `4 * x',
 * `x * (4)', `x * (int)4' and a macro that expands to a parenthesised constant
 * all arrive here with both operands built, and each was a 16-pass _fcc_mul16
 * call -- `SB_FREE + 4 * i' in ufs_sb.c is one per field decoded.
 *
 * Taking the constant from either side is K&R's own freedom, A.7 p.161: "the
 * implementation is free to evaluate operands in any order ... However, each
 * operator combines the values produced by its operands in a way compatible
 * with the parsing of the expression in which it appears."  One `*' is
 * rewritten, never a chain: `4 * i * j' stays (4*i)*j, which is the regrouping
 * the same paragraph revokes.  The constant has no side effect to keep --
 * ast_const_int accepts nothing that has one -- so evaluating only the other
 * operand loses nothing.
 *
 * Returns the new node, or -1 to leave the product to N_BINOP. */
static int
build_mul_const(int lhs, int rhs, int line, int col)
{
    LocalType lt = g_ast[lhs].type, rt = g_ast[rhs].type;
    int u = arith_unsigned(g_ast[lhs].type, g_ast[lhs].is_unsigned,
                           g_ast[rhs].type, g_ast[rhs].is_unsigned);
    long ka, kb, kc;
    int lc = ast_const_int(lhs, &ka), rc = ast_const_int(rhs, &kb);
    int var, n;

    if (!lc && !rc)
        return -1;
    if (IS_QUAD(lt) || IS_QUAD(rt))              /* 64-bit: no const path yet */
        return -1;
    if (lt == LT_FLOAT || rt == LT_FLOAT)
        return -1;
    var = rc ? lhs : rhs;
    kc = rc ? kb : ka;
    if (lt != LT_LONG && rt != LT_LONG) {
        /* A.7.6 p.166: "The usual arithmetic conversions are performed on the
         * operands, and predict the type of the result" -- int, unsigned if
         * either operand is.  The low 16 bits are the same either way. */
        unsigned k = (unsigned)kc & 0xFFFFu;
        if (lc && rc) {                 /* both constant: the product is one */
            n = ast_new(N_LIT_INT, line, col);
            g_ast[n].val = (unsigned)(((unsigned long)ka * (unsigned long)kb)
                                      & 0xFFFFuL);
            g_ast[n].type = LT_INT;
            g_ast[n].is_unsigned = u;
            return n;
        }
        n = ast_new(mul_const_inlineable(k) ? N_MUL_INLINE_CONST
                                            : N_MUL_CONST_LIBCALL, line, col);
        g_ast[n].a = var; g_ast[n].op = TOK_STAR; g_ast[n].val = k;
        g_ast[n].type = LT_INT;
        g_ast[n].is_unsigned = u;
        return n;
    }
    /* A long by a power of two is A.7.8's shift, as the long arms above
     * treat it.  Only a LONG variable operand: an int one would need widening
     * first, which the shift node does not do. */
    if (g_ast[var].type == LT_LONG && kc >= 1 && kc <= 0x7FFFFFFFL
        && (kc & (kc - 1)) == 0) {
        unsigned sh = 0;
        long t = kc;
        while (t > 1) { t >>= 1; sh++; }
        if (sh == 0 || long_shift_inlineable(1, u, sh)) {
            n = ast_new(sh ? N_SHIFT_INLINE : N_SHIFT_NOP, line, col);
            g_ast[n].a = var;
            if (sh) {
                g_ast[n].op = TOK_LSHIFT;
                g_ast[n].val = sh;
            }
            g_ast[n].type = LT_LONG;
            g_ast[n].is_unsigned = u;
            return n;
        }
    }
    return -1;
}

static int
build_mul_expr(void)
{
    int lhs = build_unary();
    while (g_cur.kind == TOK_STAR  || g_cur.kind == TOK_SLASH ||
           g_cur.kind == TOK_PERCENT) {
        TokKind op = g_cur.kind;
        int op_line = g_cur.line, op_col = g_cur.col;
        LocalType lhs_type = g_ast[lhs].type;
        int lhs_u = g_ast[lhs].is_unsigned;
        require_mulshift_operand(lhs, op, op_line, op_col);
        /* `*`, `/` and `%` for either signedness: the signed pow2 cases
         * have emitters (emit_inline_divs_pow2, emit_inline_mods_pow2). */
        int can_inline = (op == TOK_STAR) || (op == TOK_SLASH) ||
                         (op == TOK_PERCENT);
        /* A long `*' by a power of two is A.7.8's left shift written the other
         * way: "in the absence of overflow, this is equivalent to
         * multiplication by 2**E2".  Nothing else about a long reaches the
         * constant path -- `/' and `%' would each need their own 32-bit
         * sequence, and neither has a measured caller. */
        int long_star = (op == TOK_STAR && lhs_type == LT_LONG);
        if (can_inline && lhs_type != LT_FLOAT && !IS_QUAD(lhs_type) &&
            (lhs_type != LT_LONG || long_star)) {
            next_tok();                            /* consume * / % */
            if (g_cur.kind == TOK_INT_LIT) {
                unsigned k = g_cur.value & 0xFFFF;
                Tok after = peek_tok();
                int bare = !(after.kind == TOK_STAR || after.kind == TOK_SLASH ||
                             after.kind == TOK_PERCENT);
                if (bare && long_star) {
                    unsigned sh = 0, t = k;
                    if (k >= 1 && (k & (k - 1)) == 0) {
                        while (t > 1) { t >>= 1; sh++; }
                        if (sh == 0 || long_shift_inlineable(1, lhs_u, sh)) {
                            next_tok();            /* consume the literal */
                            int n = ast_new(sh ? N_SHIFT_INLINE : N_SHIFT_NOP,
                                            op_line, op_col);
                            g_ast[n].a = lhs;
                            if (sh) {
                                g_ast[n].op = TOK_LSHIFT;
                                g_ast[n].val = sh;
                            }
                            g_ast[n].type = LT_LONG;
                            g_ast[n].is_unsigned = lhs_u;
                            lhs = n;
                            continue;
                        }
                    }
                    /* not a power of two, or past the budget: general path,
                     * with the literal STILL UNCONSUMED so build_unary sees
                     * it. */
                }
                if (bare && !long_star) {
                    next_tok();                    /* consume the literal */
                    int inl = (op == TOK_STAR)  ? mul_const_inlineable(k)
                            : (op == TOK_SLASH && !lhs_u)
                                                ? divs_pow2_inlineable(k)
                            : divmod_pow2_inlineable(k);
                    int n = ast_new(inl ? N_MUL_INLINE_CONST
                                        : N_MUL_CONST_LIBCALL, op_line, op_col);
                    g_ast[n].a = lhs; g_ast[n].op = op; g_ast[n].val = k;
                    g_ast[n].type = LT_INT;
                    g_ast[n].is_unsigned = lhs_u;  /* preserve signedness */
                    lhs = n;
                    continue;
                }
            }
            /* Not a bare literal — general path (falls through below with the
             * operator already consumed). */
            {
                int rhs = build_unary();
                require_mulshift_operand(rhs, op, op_line, op_col);
                /* The operand is built now, so a constant behind casts and
                 * parentheses is finally visible -- `* (daddr_t)DEVB_PER_FSB'
                 * is one 32x32 multiply per block I/O for what is a shift by
                 * one.  Same power-of-two rule as the bare-literal arm above;
                 * the rhs node is simply left unused, as that arm never builds
                 * one at all. */
                long kc;
                if (long_star && ast_const_int(rhs, &kc)
                    && kc >= 1 && kc <= 0x7FFFFFFFL
                    && (kc & (kc - 1)) == 0) {
                    unsigned sh = 0;
                    long t = kc;
                    while (t > 1) { t >>= 1; sh++; }
                    if (sh == 0 || long_shift_inlineable(1, lhs_u, sh)) {
                        int cn = ast_new(sh ? N_SHIFT_INLINE : N_SHIFT_NOP,
                                         op_line, op_col);
                        g_ast[cn].a = lhs;
                        if (sh) {
                            g_ast[cn].op = TOK_LSHIFT;
                            g_ast[cn].val = sh;
                        }
                        g_ast[cn].type = LT_LONG;
                        g_ast[cn].is_unsigned = lhs_u;
                        lhs = cn;
                        continue;
                    }
                }
                if (op == TOK_STAR) {
                    int mc = build_mul_const(lhs, rhs, op_line, op_col);
                    if (mc >= 0) {
                        lhs = mc;
                        continue;
                    }
                }
                int n = ast_new(N_BINOP, op_line, op_col);
                g_ast[n].a = lhs; g_ast[n].b = rhs; g_ast[n].op = op;
                /* emit_scalar_binop result rules: float wins, then long long,
                 * then long, else int; unsigned per arith_unsigned (A.6.5). */
                LocalType rt = g_ast[rhs].type;
                g_ast[n].type = (lhs_type == LT_DOUBLE || rt == LT_DOUBLE) ? LT_DOUBLE
                              : (lhs_type == LT_FLOAT || rt == LT_FLOAT) ? LT_FLOAT
                              : (lhs_type == LT_LLONG || rt == LT_LLONG) ? LT_LLONG
                              : (lhs_type == LT_LONG  || rt == LT_LONG)  ? LT_LONG
                              : LT_INT;
                g_ast[n].is_unsigned = arith_unsigned(lhs_type, lhs_u, rt,
                                                      g_ast[rhs].is_unsigned);
                lhs = n;
                continue;
            }
        }
        /* long/float, or signed / and %: general path. */
        next_tok();
        {
            int rhs = build_unary();
            require_mulshift_operand(rhs, op, op_line, op_col);
            int n = ast_new(N_BINOP, op_line, op_col);
            g_ast[n].a = lhs; g_ast[n].b = rhs; g_ast[n].op = op;
            LocalType rt = g_ast[rhs].type;
            g_ast[n].type = (lhs_type == LT_DOUBLE || rt == LT_DOUBLE) ? LT_DOUBLE
                          : (lhs_type == LT_FLOAT || rt == LT_FLOAT) ? LT_FLOAT
                          : (lhs_type == LT_LLONG || rt == LT_LLONG) ? LT_LLONG
                          : (lhs_type == LT_LONG  || rt == LT_LONG)  ? LT_LONG
                          : LT_INT;
            g_ast[n].is_unsigned = arith_unsigned(lhs_type, lhs_u, rt,
                                                  g_ast[rhs].is_unsigned);
            lhs = n;
        }
    }
    return lhs;
}

/* Result-typing mirror of emit_scalar_binop (+ the compare emitters, which
 * force the result to int): float wins, then long, else int; unsigned per
 * arith_unsigned (A.6.5). */
static void
ast_type_scalar_binop(int n, int is_cmp, LocalType lt, int lu,
                      LocalType rt, int ru)
{
    /* A.6.5: "First, if either operand is long double, the other is
     * converted to long double.  Otherwise, if either operand is double, the
     * other is converted to double.  Otherwise, if either operand is float,
     * the other is converted to float." */
    if (lt == LT_DOUBLE || rt == LT_DOUBLE) {
        g_ast[n].type = is_cmp ? LT_INT : LT_DOUBLE;
        g_ast[n].is_unsigned = 0;
        return;
    }
    if (lt == LT_FLOAT || rt == LT_FLOAT) {
        g_ast[n].type = is_cmp ? LT_INT : LT_FLOAT;
        g_ast[n].is_unsigned = 0;
        return;
    }
    LocalType common = (lt == LT_LLONG || rt == LT_LLONG) ? LT_LLONG
                     : (lt == LT_LONG || rt == LT_LONG)   ? LT_LONG : LT_INT;
    g_ast[n].type = is_cmp ? LT_INT : common;
    g_ast[n].is_unsigned = arith_unsigned(lt, lu, rt, ru);
}

static int
build_add_expr(void)
{
    int lhs = build_mul_expr();
    while (g_cur.kind == TOK_PLUS || g_cur.kind == TOK_MINUS) {
        TokKind op = g_cur.kind;
        int op_line = g_cur.line, op_col = g_cur.col;
        LocalType lhs_type = g_ast[lhs].type;
        int lhs_u   = g_ast[lhs].is_unsigned;
        int lhs_sid = g_ast[lhs].struct_id;
        next_tok();
        int rhs = build_mul_expr();
        LocalType rhs_type = g_ast[rhs].type;
        int rhs_sid = g_ast[rhs].struct_id;
        int lhs_stride = (lhs_type == LT_LONG || lhs_type == LT_FLOAT)
                       ? 0 : elem_size_for(lhs_type, lhs_sid);
        int rhs_stride = (rhs_type == LT_LONG || rhs_type == LT_FLOAT)
                       ? 0 : elem_size_for(rhs_type, rhs_sid);
        if (op == TOK_PLUS && lhs_stride > 0 && rhs_stride > 0)
            die(op_line, op_col, "cannot add two pointers");
        if (op == TOK_PLUS && lhs_stride == 0 && rhs_stride > 0) {
            int n = ast_new(N_ADD_IPLUSP, op_line, op_col);
            g_ast[n].a = lhs; g_ast[n].b = rhs;
            g_ast[n].val = (unsigned)rhs_stride;
            g_ast[n].type = rhs_type; g_ast[n].struct_id = rhs_sid;
            g_ast[n].is_unsigned = g_ast[rhs].is_unsigned;  /* untouched by the arm */
            lhs = n;
            continue;
        }
        if (op == TOK_PLUS && lhs_stride > 0 && rhs_stride == 0) {
            int n = ast_new(N_ADD_PPLUSI, op_line, op_col);
            g_ast[n].a = lhs; g_ast[n].b = rhs;
            g_ast[n].val = (unsigned)lhs_stride;
            g_ast[n].type = lhs_type; g_ast[n].struct_id = lhs_sid;
            g_ast[n].is_unsigned = g_ast[rhs].is_unsigned;
            lhs = n;
            continue;
        }
        if (op == TOK_MINUS && lhs_stride > 0 && rhs_stride > 0) {
            if (lhs_stride != rhs_stride)
                die(op_line, op_col,
                    "subtracting pointers of mismatched pointee size");
            int n = ast_new(N_SUB_PTR_PTR, op_line, op_col);
            g_ast[n].a = lhs; g_ast[n].b = rhs;
            g_ast[n].val = (unsigned)lhs_stride;
            g_ast[n].type = LT_INT;
            g_ast[n].is_unsigned = g_ast[rhs].is_unsigned;
            lhs = n;
            continue;
        }
        if (op == TOK_MINUS && lhs_stride > 0 && rhs_stride == 0) {
            int n = ast_new(N_SUB_PTR_INT, op_line, op_col);
            g_ast[n].a = lhs; g_ast[n].b = rhs;
            g_ast[n].val = (unsigned)lhs_stride;
            g_ast[n].type = lhs_type; g_ast[n].struct_id = lhs_sid;
            g_ast[n].is_unsigned = g_ast[rhs].is_unsigned;
            lhs = n;
            continue;
        }
        int n = ast_new(N_BINOP, op_line, op_col);
        g_ast[n].a = lhs; g_ast[n].b = rhs; g_ast[n].op = op;
        ast_type_scalar_binop(n, 0, lhs_type, lhs_u,
                              rhs_type, g_ast[rhs].is_unsigned);
        lhs = n;
    }
    return lhs;
}

static int
build_shift_expr(void)
{
    int lhs = build_add_expr();
    while (g_cur.kind == TOK_LSHIFT || g_cur.kind == TOK_RSHIFT) {
        TokKind op = g_cur.kind;
        int op_line = g_cur.line, op_col = g_cur.col;
        LocalType lhs_type = g_ast[lhs].type;
        int lhs_u = g_ast[lhs].is_unsigned;
        require_mulshift_operand(lhs, op, op_line, op_col);
        next_tok();
        if (lhs_type != LT_FLOAT && g_cur.kind == TOK_INT_LIT) {
            unsigned k = g_cur.value & 0xFFFF;
            Tok after = peek_tok();
            int bare = !(after.kind == TOK_PLUS  || after.kind == TOK_MINUS ||
                         after.kind == TOK_STAR  || after.kind == TOK_SLASH ||
                         after.kind == TOK_PERCENT);
            if (bare && k == 0) {                 /* x << 0 / x >> 0 = x */
                next_tok();
                int n = ast_new(N_SHIFT_NOP, op_line, op_col);
                g_ast[n].a = lhs;
                /* A.7.8: "The type of the result is that of the promoted left
                 * operand" -- so a long stays a long through the identity. */
                g_ast[n].type = (lhs_type == LT_LONG || lhs_type == LT_LLONG)
                              ? lhs_type : LT_INT;
                g_ast[n].is_unsigned = lhs_u;
                lhs = n;
                continue;
            }
            if (bare && lhs_type == LT_LONG &&
                long_shift_inlineable(op == TOK_LSHIFT, lhs_u, k)) {
                next_tok();
                int n = ast_new(N_SHIFT_INLINE, op_line, op_col);
                g_ast[n].a = lhs; g_ast[n].op = op; g_ast[n].val = k;
                g_ast[n].type = LT_LONG; g_ast[n].is_unsigned = lhs_u;
                lhs = n;
                continue;
            }
            if (bare && lhs_type != LT_LONG && lhs_type != LT_LLONG &&
                k >= 1 && k <= 15 && (op == TOK_LSHIFT || lhs_u)) {
                next_tok();
                int n = ast_new(N_SHIFT_INLINE, op_line, op_col);
                g_ast[n].a = lhs; g_ast[n].op = op; g_ast[n].val = k;
                g_ast[n].type = LT_INT; g_ast[n].is_unsigned = lhs_u;
                lhs = n;
                continue;
            }
        }
        int rhs = build_add_expr();
        require_mulshift_operand(rhs, op, op_line, op_col);
        int n = ast_new(N_BINOP, op_line, op_col);
        g_ast[n].a = lhs; g_ast[n].b = rhs; g_ast[n].op = op;
        ast_type_scalar_binop(n, 0, lhs_type, lhs_u,
                              g_ast[rhs].type, g_ast[rhs].is_unsigned);
        /* A.7.8: "each operand must be integral, and is subject to integral
         * the promotions.  The type of the result is that of the promoted
         * left operand."  The usual arithmetic conversions do not apply: the
         * count neither widens the result nor lends it its signedness. */
        g_ast[n].type = (lhs_type == LT_LLONG || lhs_type == LT_LONG)
                      ? lhs_type : LT_INT;
        g_ast[n].is_unsigned = promoted_unsigned(lhs_type, lhs_u);
        lhs = n;
    }
    return lhs;
}

/* relat/eq/bit — uniform N_BINOP shapes.  The relat unsigned-ptr rule and the
 * eq multi-bank ptr-as-long conversion are applied by the WALKER from the
 * child node types (same predicates the parser used); the builder only needs
 * the result typing, where a compare forces int and eq's converted operands
 * count as long for the common-type rule. */
static int
build_relat_expr(void)
{
    int lhs = build_shift_expr();
    while (g_cur.kind == TOK_LT || g_cur.kind == TOK_GT ||
           g_cur.kind == TOK_LE || g_cur.kind == TOK_GE) {
        TokKind op = g_cur.kind;
        int op_line = g_cur.line, op_col = g_cur.col;
        LocalType lhs_type = g_ast[lhs].type;
        int lhs_u = g_ast[lhs].is_unsigned || ISPTR(lhs_type);
        next_tok();
        int rhs = build_shift_expr();
        int n = ast_new(N_BINOP, op_line, op_col);
        g_ast[n].a = lhs; g_ast[n].b = rhs; g_ast[n].op = op;
        ast_type_scalar_binop(n, 1, lhs_type, lhs_u, g_ast[rhs].type,
                              g_ast[rhs].is_unsigned || ISPTR(g_ast[rhs].type));
        lhs = n;
    }
    return lhs;
}

static int
build_eq_expr(void)
{
    int lhs = build_relat_expr();
    while (g_cur.kind == TOK_EQEQ || g_cur.kind == TOK_NE) {
        TokKind op = g_cur.kind;
        int op_line = g_cur.line, op_col = g_cur.col;
        LocalType lt = g_ast[lhs].type;
        int lhs_u = g_ast[lhs].is_unsigned;
        if (ISPTR(lt)) lt = LT_LONG;   /* ptr-as-long compare */
        next_tok();
        int rhs = build_relat_expr();
        LocalType rt = g_ast[rhs].type;
        if (ISPTR(rt)) rt = LT_LONG;
        int n = ast_new(N_BINOP, op_line, op_col);
        g_ast[n].a = lhs; g_ast[n].b = rhs; g_ast[n].op = op;
        ast_type_scalar_binop(n, 1, lt, lhs_u, rt, g_ast[rhs].is_unsigned);
        lhs = n;
    }
    return lhs;
}

/* K&R A.7.11, A.7.12 and A.7.13 all close with the same sentence -- "The
 * operator applies only to integral operands" -- and a struct or union value is
 * not one.  fcc used to accept it and compile the operand as its ADDRESS, which
 * is how mount(8) came to print "Signal 0" on a mount that had just succeeded:
 * 2.11BSD's mount.c declares `union wait status' and tests it with WIFEXITED,
 * and FGX's sys/wait.h defines that macro over an int -- so `(status) & 0x7F'
 * ANDed a stack address with 127, which is nonzero, so the exit arm was never
 * taken and the signal arm printed signal 0.  The port was wrong and nothing
 * said so; a rejected operand says so at build time.
 *
 * A POINTER TO A STRUCT IS FINE and must stay fine -- it is an address, and
 * masking one is ordinary.  Only the bare struct/union VALUE is refused, which
 * is BT_STRUCT with no derivation on top. */
static void
require_integral_operand(int n, int line, int col)
{
    tword t = (tword)g_ast[n].type;
    if (BTYPE(t) == BT_STRUCT && DERIV(t) == 0)
        die(line, col,
            "'&', '^' and '|' apply only to integral operands, and a "
            "struct/union value is not one (K&R A.7.11); name a member of it");
    if (t == LT_FLOAT)
        die(line, col,
            "'&', '^' and '|' apply only to integral operands, and a float "
            "is not one (K&R A.7.11)");
}

/* The multiplicative and shift operators' operand rules.  K&R A.7.6 (p.166):
 * "The operands of * and / must have arithmetic type; the operands of % must
 * have integral type."  A.7.8: "each operand must be integral".  A pointer is
 * neither, a float is not integral, and a struct value is neither -- and each
 * of those compiled to the operator applied to whatever word the operand left
 * in A: `p * 2' shifted an address, `f << 1' shifted a mantissa, and `p % 2'
 * stopped the compiler with an internal register-leak error. */
static void
require_mulshift_operand(int n, TokKind op, int line, int col)
{
    tword t = (tword)g_ast[n].type;
    int integral_only = (op != TOK_STAR && op != TOK_SLASH);
    if ((BTYPE(t) == BT_STRUCT && DERIV(t) == 0) || ISPTR(t) ||
        (integral_only && (t == LT_FLOAT || t == LT_DOUBLE)))
        die(line, col, integral_only
            ? "'%', '<<' and '>>' apply only to integral operands "
              "(K&R A.7.6, A.7.8)"
            : "'*' and '/' need arithmetic operands, and a pointer is not "
              "one (K&R A.7.6)");
}

static int
build_bit_and(void)
{
    int lhs = build_eq_expr();
    while (g_cur.kind == TOK_AMP) {
        int op_line = g_cur.line, op_col = g_cur.col;
        LocalType lhs_type = g_ast[lhs].type;
        int lhs_u = g_ast[lhs].is_unsigned;
        require_integral_operand(lhs, op_line, op_col);
        next_tok();
        int rhs = build_eq_expr();
        require_integral_operand(rhs, op_line, op_col);
        int n = ast_new(N_BINOP, op_line, op_col);
        g_ast[n].a = lhs; g_ast[n].b = rhs; g_ast[n].op = TOK_AMP;
        ast_type_scalar_binop(n, 0, lhs_type, lhs_u,
                              g_ast[rhs].type, g_ast[rhs].is_unsigned);
        lhs = n;
    }
    return lhs;
}

static int
build_bit_xor(void)
{
    int lhs = build_bit_and();
    while (g_cur.kind == TOK_CARET) {
        int op_line = g_cur.line, op_col = g_cur.col;
        LocalType lhs_type = g_ast[lhs].type;
        int lhs_u = g_ast[lhs].is_unsigned;
        require_integral_operand(lhs, op_line, op_col);
        next_tok();
        int rhs = build_bit_and();
        require_integral_operand(rhs, op_line, op_col);
        int n = ast_new(N_BINOP, op_line, op_col);
        g_ast[n].a = lhs; g_ast[n].b = rhs; g_ast[n].op = TOK_CARET;
        ast_type_scalar_binop(n, 0, lhs_type, lhs_u,
                              g_ast[rhs].type, g_ast[rhs].is_unsigned);
        lhs = n;
    }
    return lhs;
}

static int
build_bit_or(void)
{
    int lhs = build_bit_xor();
    while (g_cur.kind == TOK_PIPE) {
        int op_line = g_cur.line, op_col = g_cur.col;
        LocalType lhs_type = g_ast[lhs].type;
        int lhs_u = g_ast[lhs].is_unsigned;
        require_integral_operand(lhs, op_line, op_col);
        next_tok();
        int rhs = build_bit_xor();
        require_integral_operand(rhs, op_line, op_col);
        int n = ast_new(N_BINOP, op_line, op_col);
        g_ast[n].a = lhs; g_ast[n].b = rhs; g_ast[n].op = TOK_PIPE;
        ast_type_scalar_binop(n, 0, lhs_type, lhs_u,
                              g_ast[rhs].type, g_ast[rhs].is_unsigned);
        lhs = n;
    }
    return lhs;
}

static int
build_logic_and(void)
{
    int lhs = build_bit_or();
    while (g_cur.kind == TOK_AMPAMP) {
        int op_line = g_cur.line, op_col = g_cur.col;
        next_tok();
        int rhs = build_bit_or();
        int n = ast_new(N_LOGIC_AND, op_line, op_col);
        g_ast[n].a = lhs; g_ast[n].b = rhs;
        g_ast[n].type = LT_INT;
        /* The parser never set g_expr_unsigned here — the result inherits the
         * RHS operand's flag (parent decisions read it).  Preserve the quirk. */
        g_ast[n].is_unsigned = g_ast[rhs].is_unsigned;
        lhs = n;
    }
    return lhs;
}

static int
build_logic_or(void)
{
    int lhs = build_logic_and();
    while (g_cur.kind == TOK_PIPEPIPE) {
        int op_line = g_cur.line, op_col = g_cur.col;
        next_tok();
        int rhs = build_logic_and();
        int n = ast_new(N_LOGIC_OR, op_line, op_col);
        g_ast[n].a = lhs; g_ast[n].b = rhs;
        g_ast[n].type = LT_INT;
        g_ast[n].is_unsigned = g_ast[rhs].is_unsigned;
        lhs = n;
    }
    return lhs;
}

/* A ?: arm's value, converted to the node's type as it leaves the arm, so
 * both paths reach the join holding the same width (A.7.16).  Only a long,
 * long long or float result converts anything; an int result leaves A as it
 * is. */
static void
ternary_arm_conv(int n)
{
    LocalType r = g_ast[n].type;

    if (IS_QUAD(r)) {
        emit_to_quad(r);                /* by the arm's own signedness */
    } else if (r == LT_FLOAT) {
        if (g_expr_type == LT_LONG)
            emit_long_to_float();
        else if (g_expr_type != LT_FLOAT)
            emit_int_to_float();
    } else if (r == LT_LONG) {
        if (g_expr_type == LT_FLOAT)
            emit_float_to_long();
        else if (g_expr_type != LT_LONG)
            emit_promote_a_to_long();
    } else
        return;
    g_expr_type = r;
    g_expr_unsigned = g_ast[n].is_unsigned;
}

static int
build_ternary(void)
{
    int cond = build_logic_or();
    if (g_cur.kind == TOK_QMARK) {
        int op_line = g_cur.line, op_col = g_cur.col;
        next_tok();
        int then_n = build_ternary();          /* right-associative */
        expect(TOK_COLON, "':' in ternary");
        int else_n = build_ternary();
        int n = ast_new(N_TERNARY, op_line, op_col);
        g_ast[n].a = cond; g_ast[n].b = then_n; g_ast[n].c = else_n;
        /* Result descriptor = whatever the ELSE branch (emitted last) leaves —
         * the parser's historical behavior (then-branch type is ignored).
         *
         * EXCEPT WHEN ONE ARM IS A POINTER AND THE OTHER IS THE CONSTANT 0,
         * which K&R 2nd ed A.7.16 settles: "If one is a pointer and the other
         * the constant 0, the 0 is converted to the pointer type, and the
         * result has that type" (p.168).  Taking the else arm's type there
         * made `p ? q : 0' an INT -- and on this machine a pointer is four
         * bytes and an int is two, so the then arm's far pointer was
         * truncated to its offset, the bank was dropped, and a call taking
         * the result pushed two bytes where the callee reads four.
         *
         * MEASURED, and it is exactly the shape apple/fgx#327 records for
         * malloc: 2.11BSD's mount(8) writes `catopt(mntopts ? strdup(mntopts)
         * : 0, options)', which emitted `LDA _fcc_fpr0' -- the low word only
         * -- then a single PHA, and hung the machine with no output.  On a
         * PDP-11 the two widths are the same and upstream cannot see it.
         *
         * AN INTEGER ARM THAT IS NOT THE CONSTANT 0 GIVES THE POINTER TOO.
         * The standard stops at the constant, but the reference compiler does
         * not: 2.11BSD's ccom takes "e ? i : p" and "e ? p : i" with a warning
         * and a POINTER result (examples/2.11BSD/usr/lib/ccom/c01.c:290-305,
         * `werror("illegal combination of pointer and integer, op :")' and
         * the conversion cancelled), and 2.11BSD's sh is written against it:
         * macro.c:87 expands $0..$9 through
         *
         *     v=((c==0) ? cmdadr : (c<=dolc) ? dolv[c] : (dolg=0));
         *
         * Typed int, both pointer arms kept only their offset and the store
         * to v gave them DBR's bank -- right while argv sat in the data bank,
         * empty strings once apple/fgx#303 moved it out, so every script saw
         * $0..$9 empty (apple/fgx#454).  The integer arm converts the way an
         * integer assigned to a pointer does (apple/fgx#12): walk_fpr's
         * fpr_from_walked takes bank 0 for a constant and _fcc_bank_for_int's
         * answer for a runtime value, which keeps a runtime 0 null.  Only
         * int and char arms: a long or float against a pointer keeps the old
         * typing. */
        int src = else_n;
        int tp = ISPTR(g_ast[then_n].type), ep = ISPTR(g_ast[else_n].type);
        int ti = (g_ast[then_n].type == LT_INT || g_ast[then_n].type == LT_CHAR);
        int ei = (g_ast[else_n].type == LT_INT || g_ast[else_n].type == LT_CHAR);
        int iarm = -1;
        if (tp && !ep && ei) {
            src = then_n;
            iarm = else_n;
        } else if (ep && !tp && ti) {
            src = else_n;
            iarm = then_n;
        }
        if (iarm >= 0 && !(g_ast[iarm].kind == N_LIT_INT &&
                           g_ast[iarm].val == 0 && g_ast[iarm].val_hi == 0))
            fprintf(stderr, "%s:%d:%d: warning: illegal combination of "
                    "pointer and integer, op :\n",
                    g_input_path, op_line, op_col);
        g_ast[n].type        = g_ast[src].type;
        g_ast[n].struct_id   = g_ast[src].struct_id;
        g_ast[n].fn_sig      = g_ast[src].fn_sig;
        g_ast[n].is_unsigned = g_ast[src].is_unsigned;
        /* TWO ARITHMETIC ARMS MEET IN A COMMON TYPE.  A.7.16: "If the second
         * and third operands are arithmetic, the usual arithmetic conversions
         * are performed to bring them to a common type, and that type is the
         * type of the result."  Typed by the else arm, `c ? f : 1' was an int
         * and `c ? big : 1' read only the long's low word when the float or
         * long arm ran.  The walker converts each arm to this type as it
         * leaves it.  Only a long or float arm changes the answer: two int or
         * char arms stay as they were. */
        if (!tp && !ep &&
            (g_ast[then_n].type == LT_LONG || g_ast[then_n].type == LT_FLOAT ||
             IS_QUAD(g_ast[then_n].type) ||
             g_ast[else_n].type == LT_LONG || g_ast[else_n].type == LT_FLOAT ||
             IS_QUAD(g_ast[else_n].type)) &&
            (ti || g_ast[then_n].type == LT_LONG ||
                   g_ast[then_n].type == LT_FLOAT ||
                   IS_QUAD(g_ast[then_n].type)) &&
            (ei || g_ast[else_n].type == LT_LONG ||
                   g_ast[else_n].type == LT_FLOAT ||
                   IS_QUAD(g_ast[else_n].type)))
            ast_type_scalar_binop(n, 0,
                                  g_ast[then_n].type, g_ast[then_n].is_unsigned,
                                  g_ast[else_n].type, g_ast[else_n].is_unsigned);
        return n;
    }
    return cond;
}

/* `sv = rhs' with sv a whole struct VARIABLE, as an expression.  K&R A.7.17
 * (p.169): "the value of the expression replaces that of the object referred
 * to by the lvalue", and it admits "structures or unions of the same type".
 * N_STORE_VAR stores one word; the walker's store copies the object and
 * yields it.  The variable is a chain of no steps. */
int
build_struct_var_store(Local *lc, Global *gv, int rhs, int line, int col)
{
    int head = ast_new(N_LV_CHAIN, line, col);
    g_ast[head].c = -1;                            /* named base, no steps */
    g_ast[head].sym_lc = lc; g_ast[head].sym_gv = gv;
    g_ast[head].type = LT_STRUCT;
    g_ast[head].struct_id = lc ? lc->struct_id : gv->struct_id;
    int nn = ast_new(N_LV_STORE_E, line, col);
    g_ast[nn].a = head; g_ast[nn].op = TOK_EQ; g_ast[nn].c = rhs;
    g_ast[nn].type = LT_STRUCT;
    g_ast[nn].struct_id = g_ast[head].struct_id;
    return nn;
}

/* Shared tail for `NAME = rhs` / `NAME op= rhs` in expression context —
 * called with the identifier consumed and the cursor ON the candidate
 * operator.  Returns the store node, or -1 if the cursor is not at an
 * assignment operator (caller rewinds or falls through). */
static int
build_ident_assign_tail(const char *name_ptr, int name_len, int line, int col)
{
    if (g_cur.kind == TOK_EQ) {
        next_tok();
        int rhs = build_assign();
        Local  *lc = locals_lookup(name_ptr, name_len);
        Global *gv = (lc == NULL) ? globals_lookup(name_ptr, name_len) : NULL;
        if (lc == NULL && gv == NULL) {
            char buf[64];
            snprintf(buf, sizeof buf,
                     "'%.*s' undeclared", name_len, name_ptr);
            die(line, col, buf);
        }
        require_assignable(lc ? lc->type : gv->type, TOK_EQ);
        if ((lc ? lc->type : gv->type) == LT_STRUCT)
            return build_struct_var_store(lc, gv, rhs, line, col);
        int n = ast_new(N_STORE_VAR, line, col);
        g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
        g_ast[n].a = rhs;
        /* stores are A-preserving: the expression descriptor stays the
         * RHS's (chained a = b = c) */
        g_ast[n].type        = g_ast[rhs].type;
        g_ast[n].struct_id   = g_ast[rhs].struct_id;
        g_ast[n].is_unsigned = g_ast[rhs].is_unsigned;
        g_ast[n].fn_sig      = g_ast[rhs].fn_sig;
        return n;
    }
    if (is_compound_op(g_cur.kind)) {
        TokKind op = g_cur.kind;
        next_tok();
        int rhs = build_assign();
        Local  *lc = locals_lookup(name_ptr, name_len);
        Global *gv = (lc == NULL) ? globals_lookup(name_ptr, name_len) : NULL;
        if (lc == NULL && gv == NULL) {
            char buf[64];
            snprintf(buf, sizeof buf, "'%.*s' undeclared", name_len, name_ptr);
            die(line, col, buf);
        }
        require_assignable(lc ? lc->type : gv->type, op);
        int n = ast_new(N_COMPOUND_VAR, line, col);
        g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
        g_ast[n].op = op; g_ast[n].a = rhs;
        g_ast[n].type = lc ? lc->type : gv->type;
        g_ast[n].is_unsigned = lc ? lc->is_unsigned : gv->is_unsigned;
        return n;
    }
    return -1;
}

/* CU-3: compound-op -> base binop token (`t.f |= x` == `t.f = t.f | x`;
 * safe wherever the LHS address is a symbol + constant offset, so the
 * re-read has no side effects). */
static TokKind
compound_base_op(TokKind k)
{
    switch (k) {
        case TOK_PLUSEQ:    return TOK_PLUS;
        case TOK_MINUSEQ:   return TOK_MINUS;
        case TOK_STAREQ:    return TOK_STAR;
        case TOK_SLASHEQ:   return TOK_SLASH;
        case TOK_PERCENTEQ: return TOK_PERCENT;
        case TOK_AMPEQ:     return TOK_AMP;
        case TOK_PIPEEQ:    return TOK_PIPE;
        case TOK_CARETEQ:   return TOK_CARET;
        case TOK_LSHIFTEQ:  return TOK_LSHIFT;
        default:            return TOK_RSHIFT;   /* TOK_RSHIFTEQ */
    }
}

/* Peek (token-vector scan, no consume): is the IDENT-led token run at the
 * current position a multi-step lvalue chain `base <suffix..> [op]= rhs` (or
 * `++/--`)?  Used ONLY as build_assign's LAST resort -- reached after every
 * per-shape store arm has tried and rewound, so any chain-store that lands here
 * is one those arms cannot build (arrow-then-dot `t->R.T_cdr =`, dot-then-arrow,
 * arrow-arrow, index-in-the-middle, ...).  A trailing `==`/`)`/`,`/`;` (a
 * read/compare, not a store) returns 0 -> the rvalue path.  K&R A.7.17: the LHS
 * of an assignment is ANY modifiable lvalue, shape-independent.
 * Returns 0 / 1 (store) / 2 (postfix incdec). */
static int
peek_expr_lvalue_store(void)
{
    int i = g_tok_idx - 1;                    /* the base IDENT (== g_cur) */
    if (g_toks[i].kind != TOK_IDENT) return 0;
    i++;
    int saw_suffix = 0;
    for (;;) {
        TokKind k = g_toks[i].kind;
        if (k == TOK_DOT || k == TOK_ARROW) { saw_suffix = 1; i += 2; continue; }
        if (k == TOK_LBRACKET) {
            saw_suffix = 1;
            int d = 1; i++;
            while (d && g_toks[i].kind != TOK_EOF) {
                if (g_toks[i].kind == TOK_LBRACKET) d++;
                else if (g_toks[i].kind == TOK_RBRACKET) d--;
                i++;
            }
            continue;
        }
        break;
    }
    if (!saw_suffix) return 0;
    TokKind fin = g_toks[i].kind;
    if (fin == TOK_EQ || is_compound_op(fin))          return 1;
    if (fin == TOK_PLUSPLUS || fin == TOK_MINUSMINUS)  return 2;
    return 0;
}

/* Peek: is this a PARENTHESIZED member-lvalue store `( chain ) =/op= rhs`?
 * g_cur is the base IDENT (the wrapping '(' just consumed).  A parenthesized
 * lvalue is still a modifiable lvalue (K&R A.7.2 grouping preserves lvalue-ness,
 * A.7.17 LHS is any modifiable lvalue).  The 2.11BSD Bourne shell hits this via
 * macro expansion: `input` == `(standin->fdes)`, so `(input=rhs)` becomes
 * `((standin->fdes)=rhs)`.  Requires >=1 chain suffix, then ')' then '='/'op='. */
static int
peek_paren_lvalue_store(void)
{
    int i = g_tok_idx - 1;                    /* the base IDENT (== g_cur) */
    if (g_toks[i].kind != TOK_IDENT) return 0;
    i++;
    int saw_suffix = 0;
    for (;;) {
        TokKind k = g_toks[i].kind;
        if (k == TOK_DOT || k == TOK_ARROW) { saw_suffix = 1; i += 2; continue; }
        if (k == TOK_LBRACKET) {
            saw_suffix = 1;
            int d = 1; i++;
            while (d && g_toks[i].kind != TOK_EOF) {
                if (g_toks[i].kind == TOK_LBRACKET) d++;
                else if (g_toks[i].kind == TOK_RBRACKET) d--;
                i++;
            }
            continue;
        }
        break;
    }
    if (!saw_suffix) return 0;
    if (g_toks[i].kind != TOK_RPAREN) return 0;   /* the grouping ')' */
    i++;
    TokKind fin = g_toks[i].kind;
    return (fin == TOK_EQ || is_compound_op(fin)) ? 1 : 0;
}

/* Peek: is this a NESTED-paren member-lvalue store `( ( IDENT ) chain ) =/op=`?
 * g_cur is the INNER '(' (the outer '(' just consumed).  This is the 2.11BSD
 * Bourne shell's Lcheat macro -- Lcheat(a) == ((a)._cheat) -- so
 * `Lcheat(gchain) |= ARGMK` expands to `((gchain)._cheat) |= 01`: a member pun
 * ('.' on a non-struct pointer, resolved in the global namespace, aliasing the
 * pointer's own storage) wrapped in the grouping paren the macro adds.  K&R
 * A.7.2 (grouping keeps lvalue-ness), A.7.3 (1st-ed member namespace), A.7.17
 * (any modifiable lvalue is an assignment LHS). */
static int
peek_nested_paren_member_store(void)
{
    int i = g_tok_idx - 1;                    /* the inner '(' (== g_cur) */
    if (g_toks[i].kind != TOK_LPAREN) return 0;
    i++;
    if (g_toks[i].kind != TOK_IDENT)  return 0;   /* the base identifier */
    i++;
    if (g_toks[i].kind != TOK_RPAREN) return 0;   /* close the base paren */
    i++;
    int saw_suffix = 0;
    for (;;) {
        TokKind k = g_toks[i].kind;
        if (k == TOK_DOT || k == TOK_ARROW) { saw_suffix = 1; i += 2; continue; }
        if (k == TOK_LBRACKET) {
            saw_suffix = 1;
            int d = 1; i++;
            while (d && g_toks[i].kind != TOK_EOF) {
                if (g_toks[i].kind == TOK_LBRACKET) d++;
                else if (g_toks[i].kind == TOK_RBRACKET) d--;
                i++;
            }
            continue;
        }
        break;
    }
    if (!saw_suffix) return 0;
    if (g_toks[i].kind != TOK_RPAREN) return 0;   /* close the grouping wrap */
    i++;
    TokKind fin = g_toks[i].kind;
    return (fin == TOK_EQ || is_compound_op(fin)) ? 1 : 0;
}

/* Peek (token-vector scan, no consume) from a chain suffix position: does a
 * `.field` in the '->'/'.'/'[' run BRIDGE to a later `->` -- i.e. a dot-reached
 * member is itself dereferenced further on?  That is the exact shape the
 * pure-arrow read chain (N_ARROW_CHAIN) cannot follow (`t->L.T_dcar->t_dflg`,
 * tcsh sh.sem): it continues only struct-ptr fields reached BY an arrow, so a
 * `->` after a `.` stops it.  NOT bridged: dot-then-index (`p->buf.c[1]`) and a
 * trailing dot (`t->a.f`) -- those already read fine, so leave them alone.
 * Excluded: a trailing store op (=/op=/++/--) -- those are the store/incdec
 * paths, not a read.  K&R A.7.3: one uniform postfix production; read via
 * emit_lvalue_addr + deref-load.  Returns 1 to route. */
/* `(p)->v_link[1]` -- a COMPUTED base, one arrow hop to a POINTER-ARRAY
 * member, then a subscript that ENDS the chain (tcsh sh.set's rleft/rright
 * rotate macros, where v_right is a macro for v_link[1] and the base carries
 * its own grouping parens).  The arrow-chain reader decays CHAR/INT/LONG array
 * members and indexes them, but a POINTER array matches neither arm and leaves
 * '[' unread ("expected ';'").  This is the same
 * a-pointer-leaf-indexes-like-an-array-leaf non-uniformity already fixed for
 * the named-base read, the store and the address-of; the walker handles it with
 * the far-pointer bank preserved.
 *
 * TYPE-gated on the member actually being an array of pointers, so the
 * char/int/long array members keep their existing golden-covered path -- a
 * token-only gate would steal them. */
static int
peek_arrow_ptrarr_index(int sid)
{
    int    i = g_tok_idx - 1;                     /* at the '->' */
    Field *f;
    if (sid < 0) return 0;
    if (g_toks[i].kind != TOK_ARROW)          return 0;
    if (g_toks[i + 1].kind != TOK_IDENT)      return 0;
    if (g_toks[i + 2].kind != TOK_LBRACKET)   return 0;
    f = struct_field_lookup(sid, g_toks[i + 1].id_ptr, g_toks[i + 1].id_len);
    if (f == NULL) return 0;
    if (!(ISARY(f->type) && ISPTR(DECREF(f->type)))) return 0;
    /* READS only.  A STORE target must fall through to the computed-base store
     * route further down -- claiming it here consumed the chain as a read and
     * left the '=' orphaned ("expected ')'"), which is exactly what broke
     * `((p->v_link[1])->v_link[0] = t) ? ... : 0` in tcsh sh.set.
     * peek_chain_dot_bridges excludes stores for the same reason.  A run that
     * BUMPS -- ending in '++'/'--', or with a prefix one pending -- is not a
     * read either, and claiming it orphaned the operator the same way. */
    if (value_chain_ends_in_store()) return 0;
    if (value_chain_ends_in_incdec() || g_preincdec_chain) return 0;
    return 1;
}

static int
peek_chain_dot_bridges(void)
{
    int i = g_tok_idx - 1;                    /* at the current suffix token */
    int seen_dot = 0, seen_arrow = 0, seen_index = 0, bridges = 0;
    for (;;) {
        TokKind k = g_toks[i].kind;
        if (k == TOK_DOT)   { seen_dot = 1; i += 2; continue; }
        if (k == TOK_ARROW) {
            if (seen_dot) bridges = 1;
            /* An ARROW that RESUMES the chain past a subscript
             * (`p->v_link[1]->v_bal` in tcsh sh.set, where v_right is a macro
             * for v_link[1]).  K&R A.7.3 makes ./->/[] ONE recursive postfix
             * production with lvalue-ness propagating along it, so
             * arrow-then-arrow working while arrow-then-index-then-arrow does
             * not is a non-uniformity, not a language distinction: the
             * specialised arrow path consumes a single pointer hop and cannot
             * cross an index.
             *
             * The depth-1 shape `arr[i]->f` keeps its existing handler, but NOT
             * because of any test here -- it is the scan's START POSITION that
             * excludes it.  Both call sites require g_cur to be '->' (or '.'),
             * and the scan begins on that token, so a bracket-LED suffix run
             * never reaches this peek at all: its subscript is already consumed
             * and the resumed '->' is the first token scanned, with seen_index
             * still 0.  Do not add a `seen_arrow || seen_dot` conjunct here
             * thinking it guards that case -- it is vacuously true by the same
             * argument (iteration 1 always sets one of them). */
            if (seen_index) bridges = 1;
            seen_arrow = 1; i += 2; continue;
        }
        if (k == TOK_LBRACKET) {
            /* A dot bridging to a SUBSCRIPT is the same postfix production
             * (K&R A.7.3: E1[E2] is *(E1+E2), and lvalue-ness propagates along
             * the chain), and build_dot_access cannot do it when the leaf field
             * is a POINTER -- it consumes '[' only for ARRAY leaves, so
             * `B.Bfbuf[i]` with `char **Bfbuf` fell through with '[' unread.
             *
             * Gated on no preceding ARROW, following this peek's own rule that
             * only shapes the specialised paths CANNOT handle get intercepted.
             * `p->buf.c[1]` (arrow, then dot into an embedded aggregate, then
             * index) is handled correctly by the existing path -- routing it
             * here regressed the arrow_dot golden, which is why an earlier
             * attempt narrowed this gate to dot-then-ARROW and left the
             * dot-then-index case unreachable. */
            if (seen_dot && !seen_arrow) bridges = 1;
            seen_index = 1;
            int d = 1; i++;
            while (d && g_toks[i].kind != TOK_EOF) {
                if (g_toks[i].kind == TOK_LBRACKET) d++;
                else if (g_toks[i].kind == TOK_RBRACKET) d--;
                i++;
            }
            continue;
        }
        break;
    }
    if (!bridges) return 0;
    TokKind fin = g_toks[i].kind;
    if (fin == TOK_EQ || is_compound_op(fin) ||
        fin == TOK_PLUSPLUS || fin == TOK_MINUSMINUS) return 0;   /* a store */
    return 1;
}

/* build_assign — parse_assign's expression-context store classifier (3a-F).
 * All lookahead rewinds are cursor checkpoints; the RHS recursion keeps the
 * right-associativity. */
static int build_assign_body(void);

static int
build_assign(void)
{
    int saved = g_unop_operand, r;

    g_unop_operand = 0;
    r = build_assign_body();
    g_unop_operand = saved;
    return r;
}

static int
build_assign_body(void)
{
    /* --libso: a block static on the left goes to the lvalue walker, which
     * build_primary_ast enters for it (build_block_static), not to the
     * assignment arms below, which name a global's storage by label. */
    /* `(s) = e' -- a parenthesized lvalue is the same lvalue (K&R A.7.2). */
    if (g_cur.kind == TOK_LPAREN && g_toks[g_tok_idx].kind == TOK_IDENT &&
        g_toks[g_tok_idx + 1].kind == TOK_RPAREN &&
        (g_toks[g_tok_idx + 2].kind == TOK_EQ ||
         is_compound_op(g_toks[g_tok_idx + 2].kind))) {
        Global *pgv = block_static_named(g_toks[g_tok_idx].id_ptr,
                                         g_toks[g_tok_idx].id_len);
        if (pgv) {
            int line = g_cur.line, col = g_cur.col;
            next_tok();                                /* '(' */
            next_tok();                                /* the IDENT */
            next_tok();                                /* ')' */
            return build_block_static(pgv, line, col, 1);
        }
    }
    if (g_cur.kind == TOK_IDENT) {
        Global *bgv = block_static_named(g_cur.id_ptr, g_cur.id_len);
        if (bgv) {
            if (block_static_store_ahead()) {
                int line = g_cur.line, col = g_cur.col;
                next_tok();                            /* the IDENT */
                return build_block_static(bgv, line, col, 1);
            }
            return build_ternary();
        }
    }
    if (g_cur.kind == TOK_STAR) {
        LexPeek ds_pk;
        lex_peek_save(&ds_pk);
        int op_line = g_cur.line, op_col = g_cur.col;
        next_tok();                                    /* consume '*' */
        int pre = 0;
        if (g_cur.kind == TOK_PLUSPLUS)        { pre = 1;  next_tok(); }
        else if (g_cur.kind == TOK_MINUSMINUS) { pre = -1; next_tok(); }
        int paren_wrap = 0;
        if (g_cur.kind == TOK_LPAREN) { paren_wrap = 1; next_tok(); }
        if (g_cur.kind == TOK_IDENT) {
            Local  *dlc = locals_lookup(g_cur.id_ptr, g_cur.id_len);
            Global *dgv = (dlc == NULL) ? globals_lookup(g_cur.id_ptr, g_cur.id_len) : NULL;
            LocalType pt = dlc ? dlc->type : (dgv ? dgv->type : LT_INT);
            if ((dlc != NULL || dgv != NULL) && ISPTR(pt)) {
                LocalType target = DECREF(pt);
                int is_byte = (BTYPE(target) == BT_CHAR || BTYPE(target) == BT_VOID);
                int is_int  = (BTYPE(target) == BT_INT);
                int is_ptr  = ISPTR(target);
                /* A STRUCT target, for `(*p = obj)' in EXPRESSION position
                 * (apple/fgx#281; 2.11BSD fsck.h's `#define zapino(x) (*(x) =
                 * zino)', called at pass1.c:46).  The statement `*p = obj;'
                 * has always worked -- it is built by parse_stmt.c as
                 * S_DSTORE_STRUCT_COPY -- and so has the parenthesised form
                 * with an OBJECT destination, `(other = zino)'.  Only the
                 * DEREF destination was missing from the expression layer, so
                 * the arm below rewound to the rvalue path and the '=' was
                 * left orphaned ("expected ')'").
                 *
                 * K&R A.7.17 admits it twice over: the simple assignment's
                 * operands may "both be structures or unions of the same
                 * type", and "The type of an assignment expression is that of
                 * its left operand, and the value is the value stored in the
                 * left operand" -- an assignment expression HAS a type and a
                 * value whatever its operand type, so there is no statement-
                 * only class of assignment to belong to.  A.5 supplies the
                 * lvalue: "if E is an expression of pointer type, then *E is
                 * an lvalue expression referring to the object to which E
                 * points." */
                int is_struct = (target == LT_STRUCT);
                /* A LONG OR FLOAT pointee: `if ((*pl = v) != 0)' was refused
                 * in value position while the statement spelling worked
                 * (apple/fgx#396).  Its op= is a whole 4-byte read-modify-write
                 * in the N_DSTORE walker. */
                int is_long = (target == LT_LONG || target == LT_FLOAT ||
                               IS_QUAD(target));
                if (is_byte || is_int || is_ptr || is_struct || is_long) {
                    next_tok();                        /* consume IDENT */
                    int paren_ok = 1;
                    if (paren_wrap) {
                        if (g_cur.kind == TOK_RPAREN) next_tok();
                        else paren_ok = 0;
                    }
                    int post = 0;
                    if (paren_ok && !pre) {
                        if (g_cur.kind == TOK_PLUSPLUS)        { post = 1;  next_tok(); }
                        else if (g_cur.kind == TOK_MINUSMINUS) { post = -1; next_tok(); }
                    }
                    /* `*p op= rhs` as well as `*p = rhs`.  tcsh sh.misc's
                     * `while (*dp++ &= TRIM)` is the motivating shape: the
                     * lvalue is the ORIGINAL *dp and dp advances exactly once,
                     * so it cannot be desugared to `*dp++ = *dp++ & X` (that
                     * increments twice).  N_DSTORE already computes the address
                     * once and keeps the pre/post distinction, so the compound
                     * form is a read-modify-write on that same address.
                     * Restricted to byte/int leaves: a POINTER leaf has no
                     * meaningful compound op, and long/float would need the
                     * 32-bit accumulator dance -- both fail closed. */
                    int aop = TOK_EQ;
                    /* Struct joins pointer in refusing `op=': K&R A.7.17's
                     * compound forms are the arithmetic and shift operators,
                     * and none of them has a meaning for a structure operand.
                     * Fails closed, exactly as the pointer leaf does. */
                    if (paren_ok && g_cur.kind != TOK_EQ &&
                        is_compound_op(g_cur.kind) && !is_ptr && !is_struct)
                        aop = g_cur.kind;
                    if (paren_ok && (g_cur.kind == TOK_EQ || aop != TOK_EQ)) {
                        next_tok();                    /* consume '=' / 'op=' */
                        int rhs = build_assign();
                        int n = ast_new(N_DSTORE, op_line, op_col);
                        g_ast[n].sym_lc = dlc; g_ast[n].sym_gv = dgv;
                        /* the RAW compound token: emit_binop_for_compound
                         * switches on `op=` forms, not the base binop. */
                        g_ast[n].op = aop;
                        g_ast[n].a = rhs;
                        g_ast[n].val    = (unsigned)(pre + 1);   /* -1/0/1 -> 0/1/2 */
                        g_ast[n].val_hi = (unsigned)(post + 1);
                        g_ast[n].flags = (is_byte ? AF_IS_BYTE : 0) |
                                         (is_ptr ? AF_IS_PTRSTORE : 0);
                        g_ast[n].type = (is_ptr || is_long) ? target
                                      : is_struct ? LT_STRUCT
                                      : (is_byte ? LT_CHAR : LT_INT);
                        if (is_struct)
                            g_ast[n].struct_id = dlc ? dlc->struct_id
                                                     : dgv->struct_id;
                        return n;
                    }
                }
            }
        }
        /* `*E =/op= rhs' with E any other pointer expression: `**pp = d',
         * `*(p + 1) = i', `*a[i] = c'.  K&R A.7.4.3: unary * "is an lvalue
         * if the operand is a pointer to an object of arithmetic, structure,
         * union, or pointer type", and A.7.17 asks no more of a left operand.
         * The `*IDENT' arm above builds only a named pointer, and the
         * statement layer builds the rest itself (S_DSTORE_GENERAL), so this
         * was reached only in expression context -- and by every statement
         * that names a long long or a double, which stmt_names_llong sends
         * here whole.  Built as the `(*E) =' arm under `(' builds it: a
         * computed-base N_LV_CHAIN stored through N_LV_STORE_E. */
        lex_peek_restore(&ds_pk);
        next_tok();                                    /* consume '*' */
        {
            int e = build_unary_operand();             /* the pointer value E */
            if (ISPTR(g_ast[e].type) && g_ast[e].type != LT_FN_PTR &&
                (g_cur.kind == TOK_EQ || is_compound_op(g_cur.kind))) {
                int head = ast_new(N_LV_CHAIN, op_line, op_col);
                g_ast[head].c = e;                     /* computed pointer base */
                g_ast[head].sym_lc = NULL; g_ast[head].sym_gv = NULL;
                build_lvalue_suffixes(head, DECREF(g_ast[e].type),
                                      g_ast[e].struct_id);
                require_assignable(g_ast[head].type, g_cur.kind);
                TokKind op = g_cur.kind;               /* TOK_EQ or op= */
                next_tok();
                int rhs = build_assign();              /* right-assoc */
                int nn = ast_new(N_LV_STORE_E, op_line, op_col);
                g_ast[nn].a = head; g_ast[nn].op = op; g_ast[nn].c = rhs;
                g_ast[nn].type = g_ast[head].type;
                g_ast[nn].struct_id = g_ast[head].struct_id;
                return nn;
            }
        }
        /* not a deref-store -> rewind and parse as an rvalue. */
        lex_peek_restore(&ds_pk);
    }
    if (g_cur.kind == TOK_LPAREN) {
        /* T5-C C2: `(name) = rhs` / `(name) op= rhs` — the paren-wrapped
         * lvalue shape (va_arg's `((ap) += slot)`).  Exact one-deep wrap of
         * a plain identifier only; anything else rewinds to the rvalue
         * path.  Mirrors the deref-store arm's paren_wrap tolerance. */
        LexPeek pw;
        lex_peek_save(&pw);
        int line = g_cur.line, col = g_cur.col;
        next_tok();                                    /* consume '(' */
        if (g_cur.kind == TOK_IDENT) {
            const char *name_ptr = g_cur.id_ptr;
            int         name_len = g_cur.id_len;
            /* `( chain ) =/op= rhs` -- a parenthesized member lvalue as the
             * store target (Bourne sh `(input=rhs)` == `((standin->fdes)=rhs)`).
             * Route the chain through the uniform K&R walker (K&R A.7.2 grouping
             * keeps lvalue-ness, A.7.17 store yields the value). */
            if (peek_paren_lvalue_store()) {
                Local  *blc = locals_lookup(name_ptr, name_len);
                Global *bgv = (blc == NULL) ? globals_lookup(name_ptr, name_len)
                                            : NULL;
                if (blc || bgv) {
                    LocalType bt   = blc ? blc->type      : bgv->type;
                    int       bsid = blc ? blc->struct_id : bgv->struct_id;
                    next_tok();                    /* consume base IDENT */
                    int head = ast_new(N_LV_CHAIN, line, col);
                    g_ast[head].c = -1;            /* named base */
                    g_ast[head].sym_lc = blc; g_ast[head].sym_gv = bgv;
                    build_lvalue_suffixes(head, bt, bsid);
                    expect(TOK_RPAREN, "')'");     /* close the grouping wrap */
                    require_assignable(g_ast[head].type, g_cur.kind);
                    TokKind op = g_cur.kind;       /* TOK_EQ or op= */
                    next_tok();
                    int rhs = build_assign();      /* right-assoc */
                    int nn = ast_new(N_LV_STORE_E, line, col);
                    g_ast[nn].a = head; g_ast[nn].op = op; g_ast[nn].c = rhs;
                    g_ast[nn].type = g_ast[head].type;
                    g_ast[nn].struct_id = g_ast[head].struct_id;
                    return nn;
                }
            }
            next_tok();
            if (g_cur.kind == TOK_RPAREN) {
                next_tok();
                /* `(base)-><chain> =/op= rhs` -- the grouping parens wrap only
                 * the BASE, with the chain continuing AFTER them (tcsh sh.set's
                 * rleft/rright rotate macros: `(t)->v_link[2] = (p)->v_link[2]`
                 * as a comma operand).  The arm above handles the other
                 * spelling, `(base-><chain>) = rhs`.  K&R A.7.2 makes grouping
                 * parens type- and lvalue-transparent, so the two spell the
                 * SAME lvalue and neither is a special case; only the statement
                 * form of this one already worked.  Pure peek, so a chain that
                 * turns out to be a READ falls through untouched. */
                if ((g_cur.kind == TOK_ARROW || g_cur.kind == TOK_DOT ||
                     g_cur.kind == TOK_LBRACKET) &&
                    value_chain_ends_in_store()) {
                    Local  *blc = locals_lookup(name_ptr, name_len);
                    Global *bgv = (blc == NULL)
                                ? globals_lookup(name_ptr, name_len) : NULL;
                    if (blc || bgv) {
                        LocalType bt   = blc ? blc->type      : bgv->type;
                        int       bsid = blc ? blc->struct_id : bgv->struct_id;
                        int head = ast_new(N_LV_CHAIN, line, col);
                        g_ast[head].c = -1;            /* named base */
                        g_ast[head].sym_lc = blc; g_ast[head].sym_gv = bgv;
                        build_lvalue_suffixes(head, bt, bsid);
                        require_assignable(g_ast[head].type, g_cur.kind);
                        TokKind op = g_cur.kind;       /* TOK_EQ or op= */
                        next_tok();
                        int rhs = build_assign();      /* right-assoc */
                        int nn = ast_new(N_LV_STORE_E, line, col);
                        g_ast[nn].a = head; g_ast[nn].op = op;
                        g_ast[nn].c = rhs;
                        g_ast[nn].type = g_ast[head].type;
                        g_ast[nn].struct_id = g_ast[head].struct_id;
                        return nn;
                    }
                }
                int n = build_ident_assign_tail(name_ptr, name_len, line, col);
                if (n >= 0) return n;
            }
        }
        /* `(*E) =/op= rhs` -- a parenthesized deref of a COMPUTED pointer.
         * The top-of-function deref arm handles the simple `*IDENT`; this is
         * the general `*(expr)` case -- joe va.h's `aLen(v)` expands to
         * `(*((int *)(v) - 1))` and vaadd/vaset store through it inside a comma
         * expression, which the statement-level deref-store never reached.
         * Build the pointer value E, then represent `*E` as a computed-base
         * N_LV_CHAIN (address = E, no suffix) and store via N_LV_STORE_E, the
         * same value-leaving path the `(base)->m = rhs` arm above uses. */
        else if (g_cur.kind == TOK_STAR) {
            next_tok();                        /* consume '*' */
            int e = build_unary();             /* the pointer value E */
            if (ISPTR(g_ast[e].type) && g_ast[e].type != LT_FN_PTR &&
                g_cur.kind == TOK_RPAREN) {
                LexPeek after_e;
                lex_peek_save(&after_e);
                next_tok();                    /* close the grouping ')' */
                if (g_cur.kind == TOK_EQ || is_compound_op(g_cur.kind)) {
                    int head = ast_new(N_LV_CHAIN, line, col);
                    g_ast[head].c = e;         /* computed pointer base */
                    g_ast[head].sym_lc = NULL; g_ast[head].sym_gv = NULL;
                    build_lvalue_suffixes(head, DECREF(g_ast[e].type),
                                          g_ast[e].struct_id);
                    require_assignable(g_ast[head].type, g_cur.kind);
                    TokKind op = g_cur.kind;       /* TOK_EQ or op= */
                    next_tok();
                    int rhs = build_assign();      /* right-assoc */
                    int nn = ast_new(N_LV_STORE_E, line, col);
                    g_ast[nn].a = head; g_ast[nn].op = op; g_ast[nn].c = rhs;
                    g_ast[nn].type = g_ast[head].type;
                    g_ast[nn].struct_id = g_ast[head].struct_id;
                    return nn;
                }
                lex_peek_restore(&after_e);     /* not a store: fall through */
            }
            lex_peek_restore(&pw);              /* rewind to the '(' */
        }
        /* `((base) chain) =/op= rhs` -- a nested-paren member-lvalue store, the
         * 2.11BSD Bourne Lcheat macro (Lcheat(gchain) |= ARGMK ==
         * ((gchain)._cheat) |= 01).  The base is a parenthesized identifier; a
         * '.' member on a non-struct base is a global-namespace pun aliasing the
         * base's OWN storage (build_lvalue_suffixes).  K&R A.7.2/A.7.3/A.7.17. */
        else if (g_cur.kind == TOK_LPAREN && peek_nested_paren_member_store()) {
            next_tok();                        /* consume inner '(' */
            const char *bn = g_cur.id_ptr; int bl = g_cur.id_len;
            Local  *blc = locals_lookup(bn, bl);
            Global *bgv = (blc == NULL) ? globals_lookup(bn, bl) : NULL;
            if (blc || bgv) {
                LocalType bt   = blc ? blc->type      : bgv->type;
                int       bsid = blc ? blc->struct_id : bgv->struct_id;
                next_tok();                    /* consume base IDENT */
                expect(TOK_RPAREN, "')'");     /* close the base paren */
                int head = ast_new(N_LV_CHAIN, line, col);
                g_ast[head].c = -1;            /* named base */
                g_ast[head].sym_lc = blc; g_ast[head].sym_gv = bgv;
                build_lvalue_suffixes(head, bt, bsid);
                expect(TOK_RPAREN, "')'");     /* close the grouping wrap */
                require_assignable(g_ast[head].type, g_cur.kind);
                TokKind op = g_cur.kind;       /* TOK_EQ or op= */
                next_tok();
                int rhs = build_assign();      /* right-assoc */
                int nn = ast_new(N_LV_STORE_E, line, col);
                g_ast[nn].a = head; g_ast[nn].op = op; g_ast[nn].c = rhs;
                g_ast[nn].type = g_ast[head].type;
                g_ast[nn].struct_id = g_ast[head].struct_id;
                return nn;
            }
        }
        lex_peek_restore(&pw);
    }
    if (g_cur.kind == TOK_IDENT) {
        LexPeek saved_lp;
        lex_peek_save(&saved_lp);
        const char *name_ptr = g_cur.id_ptr;
        int         name_len = g_cur.id_len;
        int         line     = g_cur.line;
        int         col      = g_cur.col;
        next_tok();
        {
            int n = build_ident_assign_tail(name_ptr, name_len, line, col);
            if (n >= 0) return n;
        }
        if (g_cur.kind == TOK_DOT) {
            Local  *lc = locals_lookup(name_ptr, name_len);
            Global *gv = (lc == NULL) ? globals_lookup(name_ptr, name_len) : NULL;
            if ((lc != NULL || gv != NULL) &&
                (lc ? lc->type : gv->type) == LT_STRUCT) {
                int    sid     = lc ? lc->struct_id : gv->struct_id;
                int    cum_off = 0;
                Field *leaf    = NULL;
                while (g_cur.kind == TOK_DOT) {
                    next_tok();
                    if (g_cur.kind != TOK_IDENT)
                        die(g_cur.line, g_cur.col, "field name");
                    Field *f = field_lookup_dot(sid, g_cur.id_ptr,
                                                g_cur.id_len);
                    if (f == NULL)
                        die(g_cur.line, g_cur.col, "no such field");
                    cum_off += f->byte_offset;
                    sid      = f->struct_id;
                    leaf     = f;
                    next_tok();
                }
                if (leaf != NULL)
                    require_assignable(leaf->type, g_cur.kind);
                if (g_cur.kind == TOK_EQ && leaf != NULL &&
                    leaf->type != LT_STRUCT && !IS_QUAD(leaf->type) &&
                    leaf->type != LT_CHAR_ARRAY &&
                    leaf->type != LT_INT_ARRAY &&
                    leaf->type != LT_STRUCT_ARRAY) {
                    next_tok();                    /* consume '=' */
                    int rhs = build_assign();
                    int n = ast_new(N_STORE_DOTFIELD, line, col);
                    g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                    g_ast[n].sym_f = leaf;
                    g_ast[n].val = (unsigned)cum_off;
                    g_ast[n].a = rhs;
                    g_ast[n].type = leaf->type;
                    g_ast[n].struct_id = leaf->struct_id;
                    return n;
                }
                /* CU-3: `t.flags op= rhs` as an EXPRESSION (comma operand
                 * in curses.h's cbreak()/noecho() tty macros:
                 * `(_tty.sg_flags |= CBREAK, _rawmode = TRUE, stty(...))`).
                 * The field address is symbol + constant offset, so the
                 * compound desugars losslessly to the nodes the working
                 * `t.flags = t.flags | rhs` twin builds: N_DOT_SCALAR
                 * read -> N_BINOP -> N_STORE_DOTFIELD. */
                if (is_compound_op(g_cur.kind) && leaf != NULL &&
                    !ISPTR(leaf->type) && !ISARY(leaf->type) &&
                    leaf->type != LT_STRUCT && !IS_QUAD(leaf->type)) {
                    TokKind bop = compound_base_op(g_cur.kind);
                    next_tok();                    /* consume 'op=' */
                    int rd = ast_new(N_DOT_SCALAR, line, col);
                    g_ast[rd].sym_lc = lc; g_ast[rd].sym_gv = gv;
                    g_ast[rd].sym_f = leaf;
                    g_ast[rd].val = (unsigned)cum_off;
                    g_ast[rd].type = leaf->type;
                    g_ast[rd].struct_id = leaf->struct_id;
                    g_ast[rd].is_unsigned = leaf->is_unsigned;
                    int rhs = build_assign();
                    int bn = ast_new(N_BINOP, line, col);
                    g_ast[bn].a = rd; g_ast[bn].b = rhs;
                    g_ast[bn].op = bop;
                    ast_type_scalar_binop(bn, 0, g_ast[rd].type,
                                          g_ast[rd].is_unsigned,
                                          g_ast[rhs].type,
                                          g_ast[rhs].is_unsigned);
                    int n = ast_new(N_STORE_DOTFIELD, line, col);
                    g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                    g_ast[n].sym_f = leaf;
                    g_ast[n].val = (unsigned)cum_off;
                    g_ast[n].a = bn;
                    g_ast[n].type = leaf->type;
                    g_ast[n].struct_id = leaf->struct_id;
                    return n;
                }
            }
            /* not a scalar member assignment -> fall through to rewind. */
        }
        if (g_cur.kind == TOK_ARROW) {
            Local  *alc = locals_lookup(name_ptr, name_len);
            Global *agv = (alc == NULL) ? globals_lookup(name_ptr, name_len) : NULL;
            if ((alc != NULL || agv != NULL) &&
                (alc ? alc->type : agv->type) == LT_STRUCT_PTR) {
                int    asid = alc ? alc->struct_id : agv->struct_id;
                LexPeek av_pk;
                lex_peek_save(&av_pk);
                next_tok();                            /* consume '->' */
                Field *af = (g_cur.kind == TOK_IDENT)
                          ? struct_field_lookup(asid, g_cur.id_ptr, g_cur.id_len)
                          : NULL;
                if (af != NULL && is_ptr_array(af->type)) {
                    next_tok();                        /* consume field name */
                    if (g_cur.kind == TOK_LBRACKET) {
                        LexPeek pk2_lp;
                        lex_peek_save(&pk2_lp);
                        int is_assign = 0, pdepth = 1;
                        next_tok();                    /* consume '[' (scan) */
                        while (pdepth > 0 && g_cur.kind != TOK_EOF) {
                            if (g_cur.kind == TOK_LBRACKET) pdepth++;
                            else if (g_cur.kind == TOK_RBRACKET) {
                                pdepth--;
                                if (pdepth == 0) break;
                            }
                            next_tok();
                        }
                        if (g_cur.kind == TOK_RBRACKET) {
                            next_tok();
                            if (g_cur.kind == TOK_EQ) is_assign = 1;
                        }
                        lex_peek_restore(&pk2_lp);
                        if (is_assign) {
                            next_tok();                /* consume '[' (real) */
                            int idx = build_comma_entry();
                            expect(TOK_RBRACKET, "']'");
                            expect(TOK_EQ, "'='");
                            int rhs = build_assign();
                            int n = ast_new(N_STORE_PTRARR_ELEM, line, col);
                            g_ast[n].sym_lc = alc; g_ast[n].sym_gv = agv;
                            g_ast[n].sym_f = af;
                            g_ast[n].a = idx; g_ast[n].c = rhs;
                            g_ast[n].type = DECREF(af->type);
                            g_ast[n].struct_id = af->struct_id;
                            return n;
                        }
                    }
                }
                /* not a ptr-array element store -> restore for the scalar case. */
                lex_peek_restore(&av_pk);
            }
        }
        if (g_cur.kind == TOK_ARROW) {
            Local  *lc = locals_lookup(name_ptr, name_len);
            Global *gv = (lc == NULL) ? globals_lookup(name_ptr, name_len) : NULL;
            if ((lc != NULL || gv != NULL) &&
                (lc ? lc->type : gv->type) == LT_STRUCT_PTR) {
                int sid = lc ? lc->struct_id : gv->struct_id;
                next_tok();                        /* consume '->' */
                if (g_cur.kind == TOK_IDENT) {
                    Field *f = struct_field_lookup(sid, g_cur.id_ptr,
                                                   g_cur.id_len);
                    if (f != NULL) {
                        next_tok();                /* consume field name */
                        require_assignable(f->type, g_cur.kind);
                        if (g_cur.kind == TOK_EQ &&
                            f->type != LT_STRUCT && !IS_QUAD(f->type) &&
                            f->type != LT_CHAR_ARRAY &&
                            f->type != LT_INT_ARRAY &&
                            f->type != LT_STRUCT_ARRAY &&
                            f->type != LT_LONG_ARRAY) {
                            next_tok();            /* consume '=' */
                            int rhs = build_assign();
                            int n = ast_new(N_STORE_MEMBER, line, col);
                            g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                            g_ast[n].sym_f = f;
                            g_ast[n].a = rhs;
                            g_ast[n].type = f->type;
                            g_ast[n].struct_id = f->struct_id;
                            return n;
                        }
                        /* `p->f op= rhs` as an EXPRESSION (comma operand) --
                         * the arrow twin of the dot-field `t.flags op= rhs`
                         * desugar above (tcsh sh.time `tsum->tv_usec -= N`).
                         * Losslessly `p->f = p->f op rhs`: N_ARROW_LOAD_CHAIN
                         * read (single hop) -> N_BINOP -> N_STORE_MEMBER (which
                         * already stores int/char/long members).  Scalar-only
                         * (a pointer member would need element scaling). */
                        if (is_compound_op(g_cur.kind) &&
                            (f->type == LT_INT || f->type == LT_CHAR ||
                             f->type == LT_LONG || f->type == LT_FLOAT)) {
                            TokKind bop = compound_base_op(g_cur.kind);
                            next_tok();            /* consume 'op=' */
                            int rd = ast_new(N_ARROW_LOAD_CHAIN, line, col);
                            g_ast[rd].sym_lc = lc; g_ast[rd].sym_gv = gv;
                            g_ast[rd].kid0 = g_n_ast_fields; g_ast[rd].n_kids = 0;
                            g_ast[rd].sym_f = f;
                            g_ast[rd].type = f->type;
                            g_ast[rd].struct_id = f->struct_id;
                            g_ast[rd].is_unsigned = f->is_unsigned;
                            g_ast[rd].fn_sig = -1;
                            int rhs = build_assign();
                            int bn = ast_new(N_BINOP, line, col);
                            g_ast[bn].a = rd; g_ast[bn].b = rhs;
                            g_ast[bn].op = bop;
                            ast_type_scalar_binop(bn, 0, f->type, f->is_unsigned,
                                                  g_ast[rhs].type,
                                                  g_ast[rhs].is_unsigned);
                            int n = ast_new(N_STORE_MEMBER, line, col);
                            g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                            g_ast[n].sym_f = f;
                            g_ast[n].a = bn;
                            g_ast[n].type = f->type;
                            g_ast[n].struct_id = f->struct_id;
                            return n;
                        }
                    }
                }
            }
            /* not a scalar/ptr ->member assignment -> fall through to rewind. */
        }
        /* IDENT[i].field = rhs  where IDENT is a struct ARRAY — expression
         * context (value-yielding), which enables chained assignment like
         * `a[i].m = b[j].m = 0` (tar's setimes tv[].tv_usec).  The statement
         * path has S_FIELD_STORE_AT for this; build_assign lacked it, so the
         * RHS of a chain saw only a value-read.  Peek-guarded: rewinds if the
         * shape isn't `[expr].scalarfield =`. */
        if (g_cur.kind == TOK_LBRACKET) {
            Local  *slc = locals_lookup(name_ptr, name_len);
            Global *sgv = (slc == NULL) ? globals_lookup(name_ptr, name_len) : NULL;
            LocalType sat = slc ? slc->type : (sgv ? sgv->type : LT_INT);
            if ((slc != NULL || sgv != NULL) && sat == LT_STRUCT_ARRAY) {
                int sasid = slc ? slc->struct_id : sgv->struct_id;
                LexPeek sm_pk;
                lex_peek_save(&sm_pk);
                next_tok();                         /* consume '[' */
                int sidx = build_comma_entry();
                if (g_cur.kind == TOK_RBRACKET) {
                    next_tok();                     /* consume ']' */
                    if (g_cur.kind == TOK_DOT) {
                        next_tok();                 /* consume '.' */
                        Field *sf = (g_cur.kind == TOK_IDENT)
                            ? field_lookup_dot(sasid, g_cur.id_ptr, g_cur.id_len)
                            : NULL;
                        if (sf != NULL &&
                            sf->type != LT_STRUCT &&
                            sf->type != LT_CHAR_ARRAY && sf->type != LT_INT_ARRAY &&
                            sf->type != LT_LONG_ARRAY && sf->type != LT_FLOAT_ARRAY &&
                            sf->type != LT_STRUCT_ARRAY) {
                            next_tok();              /* consume field name */
                            require_assignable(sf->type, g_cur.kind);
                            if (g_cur.kind == TOK_EQ) {
                                next_tok();          /* consume '=' */
                                int rhs = build_assign();   /* right-assoc */
                                int n = ast_new(N_STORE_SARR_MEMBER, line, col);
                                g_ast[n].sym_lc = slc; g_ast[n].sym_gv = sgv;
                                g_ast[n].sym_f = sf;
                                g_ast[n].a = sidx; g_ast[n].b = rhs;
                                g_ast[n].val =
                                    (unsigned)elem_size_for(sat, sasid);
                                g_ast[n].type = sf->type;
                                g_ast[n].struct_id = sf->struct_id;
                                return n;
                            }
                        }
                    }
                }
                lex_peek_restore(&sm_pk);           /* not our shape — rewind */
            }
        }
        if (g_cur.kind == TOK_LBRACKET) {
            Local  *lc = locals_lookup(name_ptr, name_len);
            Global *gv = (lc == NULL) ? globals_lookup(name_ptr, name_len) : NULL;
            LocalType at = lc ? lc->type : (gv ? gv->type : LT_INT);
            /* One subscript is the element only of a ONE-dimensional array;
             * of `m[2][3]' it is a row, which the walker types and refuses. */
            int el_is_arr = (at == LT_CHAR_ARRAY || at == LT_INT_ARRAY) &&
                            (lc ? lc->n_dims : (gv ? gv->n_dims : 1)) <= 1;
            int el_is_ptr = (at == LT_CHAR_PTR || at == LT_INT_PTR ||
                             at == LT_VOID_PTR);
            if ((lc != NULL || gv != NULL) && (el_is_arr || el_is_ptr)) {
                LexPeek pk_lp;
                lex_peek_save(&pk_lp);
                int is_assign = 0, depth = 1;
                next_tok();                            /* consume '[' */
                while (depth > 0 && g_cur.kind != TOK_EOF) {
                    if (g_cur.kind == TOK_LBRACKET) depth++;
                    else if (g_cur.kind == TOK_RBRACKET) {
                        depth--;
                        if (depth == 0) break;
                    }
                    next_tok();
                }
                if (g_cur.kind == TOK_RBRACKET) {
                    next_tok();                         /* consume ']' */
                    if (g_cur.kind == TOK_EQ) is_assign = 1;
                }
                lex_peek_restore(&pk_lp);
                if (is_assign) {
                    int is_byte = (at == LT_CHAR_ARRAY || at == LT_CHAR_PTR ||
                                   at == LT_VOID_PTR);
                    next_tok();                         /* consume '[' (real) */
                    int idx = build_comma_entry();
                    expect(TOK_RBRACKET, "']'");
                    expect(TOK_EQ, "'='");
                    int rhs = build_assign();
                    int n = ast_new(N_STORE_ARR_ELEM, line, col);
                    g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                    g_ast[n].a = idx; g_ast[n].c = rhs;
                    g_ast[n].flags = (is_byte ? AF_IS_BYTE : 0) |
                                     (el_is_ptr ? AF_EL_PTR : 0);
                    g_ast[n].type = is_byte ? LT_CHAR : LT_INT;
                    return n;
                }
            }
            /* not a 1-D char/int array-element assignment -> rewind. */
        }
        lex_peek_restore(&saved_lp);
        /* LAST RESORT: a multi-step lvalue chain store the per-shape arms above
         * cannot build, in EXPRESSION context (comma operand, for-header, macro
         * body): `t->R.T_cdr = t->L.T_car` (tcsh sh.parse), the rleft/rright
         * comma-store macros (sh.set).  Route to the uniform K&R walker
         * (build_lvalue_suffixes/emit_lvalue_addr), which leaves the stored
         * value per K&R A.7.17.  Reached only after every arm rewound, so no
         * working golden is intercepted. */
        if (peek_expr_lvalue_store() == 1) {
            Local  *blc = locals_lookup(name_ptr, name_len);
            Global *bgv = (blc == NULL) ? globals_lookup(name_ptr, name_len)
                                        : NULL;
            if (blc || bgv) {
                LocalType bt  = blc ? blc->type      : bgv->type;
                int       bsid = blc ? blc->struct_id : bgv->struct_id;
                next_tok();                        /* consume base IDENT */
                int head = ast_new(N_LV_CHAIN, line, col);
                g_ast[head].c = -1;                /* named base (not computed) */
                g_ast[head].sym_lc = blc; g_ast[head].sym_gv = bgv;
                build_lvalue_suffixes(head, bt, bsid);
                require_assignable(g_ast[head].type, g_cur.kind);
                TokKind op = g_cur.kind;           /* TOK_EQ or op= */
                next_tok();
                int rhs = build_assign();          /* right-assoc */
                int nn = ast_new(N_LV_STORE_E, line, col);
                g_ast[nn].a = head; g_ast[nn].op = op; g_ast[nn].c = rhs;
                g_ast[nn].type = g_ast[head].type;
                g_ast[nn].struct_id = g_ast[head].struct_id;
                return nn;
            }
        }
    }
    return build_ternary();
}

/* Is there a comma operator (depth-0 ',') still ahead in this expression?
 * Used by build_comma to relax the void-in-expression check for a DISCARDED
 * comma operand: `(adel(x), v[p] = e, v)` (joe va.h vaset) has a void call as
 * a non-final operand, which is legal C -- only the FINAL operand's value (and
 * thus void-ness) reaches the enclosing context.  Scans from g_cur, tracking
 * ()/[] nesting; stops at the matching close or ';'. */
static int
comma_follows_at_depth0(void)
{
    int i = g_tok_idx - 1;                    /* g_cur == g_toks[g_tok_idx-1] */
    int d = 0;
    for (; g_toks[i].kind != TOK_EOF; i++) {
        TokKind k = g_toks[i].kind;
        if (k == TOK_LPAREN || k == TOK_LBRACKET) d++;
        else if (k == TOK_RPAREN || k == TOK_RBRACKET) { if (d == 0) return 0; d--; }
        else if (d == 0 && k == TOK_COMMA) return 1;
        else if (d == 0 && (k == TOK_SEMI || k == TOK_LBRACE)) return 0;
    }
    return 0;
}

static int
build_comma(void)
{
    int saved_void_ok = g_void_ctx_ok;
    /* A comma operand that a comma FOLLOWS is discarded -> void is legal there;
     * the final operand keeps the caller's context. */
    g_void_ctx_ok = saved_void_ok || comma_follows_at_depth0();
    int lhs = build_assign();
    g_void_ctx_ok = saved_void_ok;
    while (g_cur.kind == TOK_COMMA) {
        int op_line = g_cur.line, op_col = g_cur.col;
        next_tok();
        g_void_ctx_ok = saved_void_ok || comma_follows_at_depth0();
        int rhs = build_assign();
        g_void_ctx_ok = saved_void_ok;
        int n = ast_new(N_COMMA, op_line, op_col);
        g_ast[n].a = lhs; g_ast[n].b = rhs;
        g_ast[n].type        = g_ast[rhs].type;
        g_ast[n].struct_id   = g_ast[rhs].struct_id;
        g_ast[n].fn_sig      = g_ast[rhs].fn_sig;
        g_ast[n].is_unsigned = g_ast[rhs].is_unsigned;
        lhs = n;
    }
    return lhs;
}

/* Walk twin of emit_chained_index_offset: replay the captured index
 * subtrees with the per-level scale/accumulate glue.  Returns the number of
 * levels consumed (== the build-time count). */
int
walk_cio(int kid0, int n_kids, int n_dims, const int *dims, int row_stride)
{
    int level = 0;
    int stride = row_stride;
    int pushed = 0;
    walk_val(g_ast_kids[kid0]);
    emit_cio_scale(stride);
    level = 1;
    if (n_dims > 1) {
        int d = dims[1];
        if (d > 0) stride /= d;
    }
    for (int i = 1; i < n_kids; i++) {
        if (!pushed) {
            emit_push_a();                       /* accumulator @ 1,S */
            pushed = 1;
        }
        walk_val(g_ast_kids[kid0 + i]);
        emit_cio_scale(stride);
        ir_emitf("                CLC\n");
        ir_emitf("                ADC     1,S\n");
        ir_emitf("                STA     1,S\n");
        if (level + 1 < n_dims) {
            int d = dims[level + 1];
            if (d > 0) stride /= d;
        }
        level++;
    }
    if (pushed) {
        ir_record_raw(IR_POP_A, 0, 0, NULL);
        g_s_delta -= 2;
    }
    return level;
}


/* Walker — P3-2.2 FPR pointer model.  Every pointer- or address-valued
 * node deposits its result in a far-pointer register (g_fpr_res); scalar
 * results stay in A (+_fcc_long_hi) exactly as before.  P3-2.7 retired
 * the carrier as a cross-call convention (libc shims return in FPR0;
 * air/airg element loads fill an FPR directly).  What remains bridged
 * (fpr_in immediately after a self-contained helper, one-statement
 * lifetime, never across a call): the deref-postinc/deref-fast IR
 * family, member incdec, ptr-local preinc — all rewritten wholesale by
 * the P3-3 soft-stack flip, which is where they convert.  LT_STRUCT
 * values stay carrier-carried by design (2.2 decision). */
/* apple/fgx#12: whether the value a walk just produced is a compile-time
 * integer constant.  Given the SAME lifetime as g_expr_type deliberately -- set
 * by the walk, consumed by the pointer-store lowerings in emit.c, which already
 * branch on `g_expr_type == LT_INT || LT_CHAR` and need exactly one more bit to
 * pick the bank.  The wrapper (not an append to the switch) so a future early
 * `return` inside an arm cannot silently skip it.
 *
 * WHY THIS EXISTS, from the reference implementation rather than from ANSI:
 * 2.11BSD's own compiler (examples/2.11BSD/usr/lib/ccom/c01.c:244-266) warns
 * "illegal combination of pointer and integer, op =" for a non-zero integer
 * assigned to a pointer and then does `cvn = leftc = 0`, CANCELLING the
 * conversion so the pointer takes the integer's bits verbatim.  Its CAST arm
 * eight lines below does the identical `cvn = leftc = 0`.  So a cast and an
 * implicit assignment are ONE construct in the language 2.11BSD was written
 * against, and fcc must emit the same code for both.  On a PDP-11 "the bits
 * verbatim" is the whole address; on FGX the int carries only the offset, so
 * the bank has to come from somewhere -- DBR for a runtime value, 0 for a
 * constant (K&R A.6.6 leaves the mapping to the implementation). */
static void walk_expr_body(int n);

/* The binary operator an `op=' applies. */
static void
(*compound_binop_fn(TokKind op))(void)
{
    switch (op) {
    case TOK_PLUSEQ:    return emit_binop_add;
    case TOK_MINUSEQ:   return emit_binop_sub;
    case TOK_STAREQ:    return emit_binop_mul;
    case TOK_SLASHEQ:   return emit_binop_div;
    case TOK_PERCENTEQ: return emit_binop_mod;
    case TOK_LSHIFTEQ:  return emit_binop_shl;
    case TOK_RSHIFTEQ:  return emit_binop_shr;
    case TOK_AMPEQ:     return emit_binop_band;
    case TOK_PIPEEQ:    return emit_binop_bor;
    case TOK_CARETEQ:   return emit_binop_bxor;
    default:            die(0, 0, "internal: not a compound assignment");
    }
    return emit_binop_add;
}

/* Whether `E1 op= E2', E1 of type ht, runs at 64 bits: E1 is long long or
 * long double, or E2 is and the op is not a shift, whose count does not
 * balance (A.7.8).  `%=', the shifts and the bitwise forms need integral
 * operands (A.7.6, A.7.8, A.7.11), and `+=' on a pointer an integral one
 * (A.7.7), so a long double on either side of those is refused. */
static int
llong_opassign_applies(LocalType ht, TokKind op, int rhs)
{
    LocalType rt = g_ast[rhs].type;
    if ((ht == LT_DOUBLE || rt == LT_DOUBLE) &&
        (op == TOK_PERCENTEQ || op == TOK_LSHIFTEQ || op == TOK_RSHIFTEQ ||
         op == TOK_AMPEQ || op == TOK_PIPEEQ || op == TOK_CARETEQ ||
         ISPTR(ht)))
        die(g_ast[rhs].line, g_ast[rhs].col, "this operator needs integral "
            "operands, and a double is not one (K&R A.7.6-A.7.11)");
    if (ISPTR(ht)) return 0;
    if (IS_QUAD(ht)) return 1;
    return IS_QUAD(rt) && op != TOK_LSHIFTEQ && op != TOK_RSHIFTEQ;
}

/* E1 op= E2 at 64 bits, by A.7.17's own reading: "An expression of the form
 * E1 op= E2 is equivalent to E1 = E1 op (E2) except that E1 is evaluated only
 * once."  E1's value is in the accumulator, of type ht and signedness lhs_u;
 * it is brought to the common type -- long double if either side is one,
 * else long long (A.6.5) -- and the result is left in that type, which the
 * caller's store converts back to E1's, so `i /= ll' divides by the whole of
 * ll. */
static void
llong_opassign(int n, TokKind op, int rhs, LocalType ht, int lhs_u)
{
    LocalType rt = g_ast[rhs].type;
    LocalType common = (ht == LT_DOUBLE || rt == LT_DOUBLE) ? LT_DOUBLE
                                                            : LT_LLONG;
    if (common == LT_LLONG && ht == LT_FLOAT)
        die(g_ast[n].line, g_ast[n].col, "long long meeting float "
            "is not implemented yet (apple/fgx#447 increment 2)");
    g_expr_type = ht;
    g_expr_unsigned = lhs_u;
    emit_to_quad(common);
    emit_push_llong();
    walk_val(rhs);
    emit_scalar_binop(common, rt, (ht == common) ? lhs_u : 0,
                      g_ast[rhs].is_unsigned, compound_binop_fn(op));
}

/* The statement-context root whose value walk_expr_stmt discards. */
static int g_discard_node = -1;

/* The type of the object an expression-context store writes, or LT_VOID
 * when n is not one.  N_STORE_VAR carries its RHS's descriptor (chained
 * pointer stores read it), so its object's type comes from the symbol. */
static LocalType
store_object_type(int n)
{
    switch (g_ast[n].kind) {
    case N_STORE_VAR:
        return g_ast[n].sym_lc ? g_ast[n].sym_lc->type : g_ast[n].sym_gv->type;
    case N_DSTORE: case N_COMPOUND_VAR:
    case N_STORE_DOTFIELD: case N_STORE_PTRARR_ELEM: case N_STORE_MEMBER:
    case N_STORE_SARR_MEMBER: case N_STORE_ARR_ELEM: case N_LV_STORE_E:
        return g_ast[n].type;
    default:
        return LT_VOID;
    }
}

void
walk_expr(int n)
{
    walk_expr_body(n);
    /* K&R A.7.17: "The type of an assignment expression is that of its left
     * operand, and the value is the value stored in the left operand after
     * the assignment has taken place."  A char store writes A's low byte;
     * the value is that byte, so A drops its high one -- unless the
     * statement discards the value. */
    if (n != g_discard_node && g_fpr_res < 0 &&
        store_object_type(n) == LT_CHAR)
        ir_emitf("                AND     #$00FF\n");
    g_expr_const_int = cast_operand_is_const(n);
}

/* fpr k += index * stride.  A constant index is a constant offset (K&R
 * A.7.3.1: E1[E2] is *((E1)+(E2))), added at compile time. */
void
emit_fpr_add_index(int k, int idx, unsigned stride)
{
    long v;
    if (ast_const_int(idx, &v)) {
        emit_fpr_add_const(k, (int)(v * (long)(stride > 1 ? stride : 1)));
        return;
    }
    walk_val(idx);
    emit_index_scale(stride);
    emit_fpr_add_a(k);
}

/* emit_addr_field_index -- add `index * elemsize' to an address already in
 * fpr k.  The tail of `&arr[i].field[j]' (apple/fgx#202), split out because
 * the multi-dimensional twin below needs the identical three steps and two
 * copies of an index scale is how the two spellings come to disagree. */
static void
emit_addr_field_index(int k, int idx_ast, int elemsize)
{
    walk_val(idx_ast);
    emit_index_scale(elemsize);
    emit_fpr_add_a(k);
}


static void
walk_expr_body(int n)
{
        g_fpr_res = -1;
    switch (g_ast[n].kind) {
    case N_MUL_INLINE_CONST:
        walk_val(g_ast[n].a);
        if (g_ast[n].op == TOK_STAR) emit_inline_mul_const(g_ast[n].val);
        else if (g_ast[n].op == TOK_SLASH && !g_ast[n].is_unsigned &&
                 g_ast[n].val != 1)
            emit_inline_divs_pow2(g_ast[n].val);
        else if (g_ast[n].op == TOK_PERCENT && !g_ast[n].is_unsigned &&
                 g_ast[n].val != 1)
            emit_inline_mods_pow2(g_ast[n].val);
        else emit_inline_divmod_pow2(g_ast[n].op, g_ast[n].val);
        g_expr_unsigned = g_ast[n].is_unsigned;
        break;
    case N_MUL_CONST_LIBCALL:
        walk_val(g_ast[n].a);
        ir_emitf("                LDX     #%u\n", g_ast[n].val);
        ir_emitf("                STX     _fcc_tmp_b\n");
        /* SIGNEDNESS PICKS THE HELPER.  This node used to be reachable only
         * for `*` and for unsigned `/`,`%`, so the unsigned helpers were
         * unconditional; signed `/` by a non-power-of-two constant arrives
         * here now and must not be divided unsigned. */
        ir_emitf("                JSR     %s\n",
                g_ast[n].op == TOK_STAR  ? "_fcc_mul16"  :
                g_ast[n].op == TOK_SLASH ? (g_ast[n].is_unsigned ? "_fcc_divu16"
                                                                 : "_fcc_divs16")
                                         : (g_ast[n].is_unsigned ? "_fcc_modu16"
                                                                 : "_fcc_mods16"));
        g_expr_type = LT_INT;
        g_expr_unsigned = g_ast[n].is_unsigned;
        break;
    case N_BINOP: {
        Node *a = &g_ast[g_ast[n].a], *b = &g_ast[g_ast[n].b];
        TokKind op = g_ast[n].op;
        int is_rel = (op == TOK_LT || op == TOK_GT ||
                      op == TOK_LE || op == TOK_GE);
        int is_eq  = (op == TOK_EQEQ || op == TOK_NE);
        void (*fn)(void) =
            (op == TOK_STAR)    ? emit_binop_mul :
            (op == TOK_SLASH)   ? emit_binop_div :
            (op == TOK_PERCENT) ? emit_binop_mod :
            (op == TOK_PLUS)    ? emit_binop_add :
            (op == TOK_MINUS)   ? emit_binop_sub :
            (op == TOK_LSHIFT)  ? emit_binop_shl :
            (op == TOK_RSHIFT)  ? emit_binop_shr :
            (op == TOK_AMP)     ? emit_binop_band :
            (op == TOK_CARET)   ? emit_binop_bxor :
            (op == TOK_PIPE)    ? emit_binop_bor :
            (op == TOK_LT)      ? emit_cmp_lt :
            (op == TOK_GT)      ? emit_cmp_gt :
            (op == TOK_LE)      ? emit_cmp_le :
            (op == TOK_GE)      ? emit_cmp_ge :
            (op == TOK_EQEQ)    ? emit_cmp_eq : emit_cmp_ne;
        if ((is_eq || is_rel) && (ISPTR(a->type) || ISPTR(b->type))) {
            /* Pointer comparison on the FPR carrier.  Equality under
             * --data-segment compares offset word + bank BYTE (the pad
             * discipline; replaces the ptr->long reinterpret).  FGX1 and
             * all relationals compare offset words as unsigned ints
             * (bank equality assumed, as before). */
            int ka = walk_fpr(g_ast[n].a);
            int kb = walk_fpr(g_ast[n].b);
            if (is_eq) {
                emit_fpr_cmp(ka, kb, op == TOK_NE);
            } else {
                emit_fpr_to_a(ka);
                emit_push_a();
                emit_fpr_to_a(kb);
                emit_scalar_binop(LT_INT, LT_INT, is_rel, is_rel, fn);
            }
            fpr_drop(kb);
            fpr_drop(ka);
            g_expr_type      = LT_INT;
            g_expr_unsigned  = 0;
            g_expr_struct_id = -1;
            break;
        }
        /* A POINTER operand here is one of `&', `^' or `|' masking an address
         * (require_integral_operand keeps that legal); the operator sees its
         * offset word, so the far pointer is collapsed into A rather than left
         * live in an FPR nobody drops -- `p & m' stopped the compiler with a
         * register-leak error while `m & p' compiled. */
        if (ISPTR(a->type)) walk_val(g_ast[n].a);
        else                walk_expr(g_ast[n].a);
        LocalType lt = a->type;
        int lu = a->is_unsigned;
        if (lt == LT_DOUBLE || b->type == LT_DOUBLE) {
            /* Widened BEFORE the push: a conversion calls the soft double,
             * which the right operand's parking in the second-operand cells
             * would not survive (emit_scalar_binop). */
            emit_to_quad(LT_DOUBLE);
            lt = LT_DOUBLE;
            lu = 0;
            emit_push_llong();
        }
        else if (lt == LT_LLONG)                  emit_push_llong();
        else if (lt == LT_LONG || lt == LT_FLOAT) emit_push_long();
        else                                      emit_push_a();
        if (ISPTR(b->type)) walk_val(g_ast[n].b);
        else                walk_expr(g_ast[n].b);
        LocalType rt = b->type;
        int ru = b->is_unsigned;
        emit_scalar_binop(lt, rt, lu, ru, fn);
        break;
    }
    case N_ADD_IPLUSP: {
        walk_expr(g_ast[n].a);         /* int -> A */
        emit_push_a();
        int kb = walk_fpr(g_ast[n].b); /* ptr */
        emit_pop_a();                  /* int back in A */
        /* Scale the INT side (fixes the historical arm, which scaled the
         * pointer offset — `2 + iarr` computed 2*arr+2). */
        emit_scale_index_by((int)g_ast[n].val);
        emit_fpr_add_a(kb);
        g_fpr_res        = kb;
        g_expr_type      = g_ast[n].type;
        g_expr_struct_id = g_ast[n].struct_id;
        break;
    }
    case N_ADD_PPLUSI:
    case N_SUB_PTR_INT: {
        int ka = walk_fpr(g_ast[n].a);
        walk_val(g_ast[n].b);          /* int index -> A */
        emit_scale_index_by((int)g_ast[n].val);
        if (g_ast[n].kind == N_ADD_PPLUSI) emit_fpr_add_a(ka);
        else                               emit_fpr_sub_a(ka);
        g_fpr_res        = ka;
        g_expr_type      = g_ast[n].type;
        g_expr_struct_id = g_ast[n].struct_id;
        break;
    }
    case N_SUB_PTR_PTR: {
        int ka = walk_fpr(g_ast[n].a);
        int kb = walk_fpr(g_ast[n].b);
        emit_fpr_diff(ka, kb);         /* A = offset difference */
        fpr_drop(kb);
        fpr_drop(ka);
        int s = (int)g_ast[n].val;     /* shared pointee stride */
        if (s > 1) {
            if ((s & (s - 1)) == 0) {
                for (int t = s; t > 1; t >>= 1)
                    ir_emitf("                LSR\n");
            } else {
                ir_emitf("                LDX     #%d\n", s);
                ir_emitf("                STX     _fcc_tmp_b\n");
                emit_jsr_rt("_fcc_divs16");
            }
        }
        g_expr_type = LT_INT;
        g_expr_unsigned = 0;
        break;
    }
    case N_SHIFT_NOP:
        walk_val(g_ast[n].a);
        g_expr_type = g_ast[n].type;
        g_expr_unsigned = g_ast[n].is_unsigned;
        break;
    case N_SHIFT_INLINE:
        walk_val(g_ast[n].a);
        if (g_ast[n].type == LT_LONG) {
            if (g_ast[n].op == TOK_LSHIFT)
                emit_inline_long_shl(g_ast[n].val);
            else
                emit_inline_long_shr(g_ast[n].is_unsigned, g_ast[n].val);
            g_expr_unsigned = g_ast[n].is_unsigned;
        } else {
            emit_inline_shift(g_ast[n].op, g_ast[n].is_unsigned, g_ast[n].val);
        }
        break;
    case N_LOGIC_AND: {
        int lab_false = new_label();
        int lab_end   = new_label();
        walk_cond_branch(g_ast[n].a, lab_false, 0);  /* LHS false -> result 0 */
        walk_cond_branch(g_ast[n].b, lab_false, 0);
        ir_emitf("                LDA     #1\n");
        emit_bra_label(lab_end);
        emit_label(lab_false);
        ir_emitf("                LDA     #0\n");
        emit_label(lab_end);
        g_expr_type = LT_INT;
        break;
    }
    case N_LOGIC_OR: {
        int lab_true = new_label();
        int lab_end  = new_label();
        walk_cond_branch(g_ast[n].a, lab_true, 1);
        walk_cond_branch(g_ast[n].b, lab_true, 1);
        ir_emitf("                LDA     #0\n");
        emit_bra_label(lab_end);
        emit_label(lab_true);
        ir_emitf("                LDA     #1\n");
        emit_label(lab_end);
        g_expr_type = LT_INT;
        break;
    }
    case N_TERNARY: {
        int lab_else = new_label();
        int lab_end  = new_label();
        /* A struct value is its address, carried like a pointer's. */
        int res_ptr  = ISPTR(g_ast[n].type) || g_ast[n].type == LT_STRUCT;
        int kb = -1, kc = -1;
        walk_cond_branch(g_ast[n].a, lab_else, 0);
        /* Each arm leaves its value in the register the join re-allocates,
         * so a constant address is built before the drop. */
        if (res_ptr) { kb = walk_fpr(g_ast[n].b); fpr_sym_flush(kb); fpr_drop(kb); }
        else         { walk_val(g_ast[n].b); ternary_arm_conv(n); }
        emit_bra_label(lab_end);
        emit_label(lab_else);
        if (res_ptr) { kc = walk_fpr(g_ast[n].c); fpr_sym_flush(kc); fpr_drop(kc); }
        else         { walk_val(g_ast[n].c); ternary_arm_conv(n); }
        emit_label(lab_end);
        if (res_ptr) {
            /* Join rule: both arms deposited into the SAME slot (the
             * walk-time tracker state is identical at each arm's entry). */
            if (kb != kc)
                die(g_ast[n].line, g_ast[n].col, "fcc-fpr: ternary join slot");
            g_fpr_res = fpr_alloc();   /* == kb */
        }
        break;
    }
    case N_COMMA: {
        int saved = g_discard_node;    /* K&R A.7.18: the left value is discarded */
        g_discard_node = g_ast[n].a;
        walk_expr(g_ast[n].a);
        g_discard_node = saved;
        if (g_fpr_res >= 0) { fpr_drop(g_fpr_res); g_fpr_res = -1; }
        walk_expr(g_ast[n].b);
        break;
    }
    /* --- unary --- */
    case N_SIZEOF:
        ir_emitf("                LDA     #%d\n", (int)g_ast[n].val);
        g_expr_type = LT_INT;
        break;
    case N_PREINC_MEMBER:
        if (g_ast[n].sym_f->type == LT_LONG ||
            g_ast[n].sym_f->type == LT_FLOAT || IS_QUAD(g_ast[n].sym_f->type))
            emit_wide_member_incdec(g_ast[n].sym_lc, g_ast[n].sym_gv,
                                    g_ast[n].sym_f->byte_offset,
                                    g_ast[n].sym_f->type,
                                    (int)g_ast[n].val,
                                    /*return_old=*/0);   /* prefix -> NEW */
        else
            emit_member_incdec(g_ast[n].sym_lc, g_ast[n].sym_gv, g_ast[n].sym_f,
                               (int)g_ast[n].val, /*is_prefix=*/1);
        if (ISPTR(g_ast[n].type)) fpr_in();
        break;
    case N_PREINC_GLOBAL: {
        Global *gv = g_ast[n].sym_gv;
        if (IS_QUAD(gv->type)) {
            emit_llong_incdec(NULL, gv, g_ast[n].val != 0, 0);
            g_fpr_res = -1;
            break;
        }
        if (gv->type == LT_FLOAT) {
            emit_float_var_incdec(NULL, gv, g_ast[n].val != 0, /*return_old=*/0);
            g_fpr_res = -1;
            break;
        }
        if (ISPTR(gv->type)) {
            int k = fpr_alloc();
            emit_fpr_load_global_ptr(k, gv);
            emit_fpr_incdec_home_global(k, gv,
                g_ast[n].val ? (int)g_ast[n].val_hi : -(int)g_ast[n].val_hi,
                /*update_fpr=*/1);
            g_fpr_res        = k;
            g_expr_type      = gv->type;
            g_expr_struct_id = gv->struct_id;
            g_expr_unsigned  = gv->is_unsigned;
            break;
        }
        if (gv->type == LT_LONG) {          /* prefix ++/-- yields the NEW value */
            emit_long_incdec_global(gv, g_ast[n].val ? 1 : 0, /*return_old=*/0);
            g_expr_type      = gv->type;
            g_expr_struct_id = gv->struct_id;
            break;
        }
        emit_load_global(gv);
        if (g_ast[n].val) {
            ir_record_raw(IR_ADD_CONST, (unsigned)((int)g_ast[n].val_hi), 0, NULL);
        } else {
            ir_record_raw(IR_SUB_CONST, (unsigned)((int)g_ast[n].val_hi), 0, NULL);
        }
        if (gv->type == LT_CHAR) emit_store_global_char(gv);
        else                     emit_store_global_int(gv);
        g_expr_type      = gv->type;
        g_expr_struct_id = gv->struct_id;
        break;
    }
    case N_PREINC_LOCAL: {
        Local *lc = g_ast[n].sym_lc;
        if (IS_QUAD(lc->type)) {
            emit_llong_incdec(lc, NULL, g_ast[n].val != 0, 0);
            g_fpr_res = -1;
            break;
        }
        if (lc->type == LT_FLOAT) {
            emit_float_var_incdec(lc, NULL, g_ast[n].val != 0, /*return_old=*/0);
            g_fpr_res = -1;
            break;
        }
        if (lc->type == LT_LONG) {          /* prefix ++/-- yields the NEW value */
            /* 32-bit ±1 with carry/borrow into the high word.  The 16-bit path
             * below (ADD/SUB_CONST on A only) drops the high word entirely, so
             * `--x` on a long that reaches 0 wraps to 0x0000FFFF (65535 >= 0),
             * not -1 — the tar(1) `while (--blocks >= 0) putempty()` zero-write
             * runaway.  Mirrors the N_PREINC_GLOBAL long branch. */
            emit_long_incdec_local(lc, g_ast[n].val ? 1 : 0, /*return_old=*/0);
            g_expr_type      = LT_LONG;
            g_expr_struct_id = -1;
            g_expr_unsigned  = lc->is_unsigned;
            break;
        }
        emit_load_local(lc);
        if (g_ast[n].val) {
            ir_record_raw(IR_ADD_CONST, (unsigned)((int)g_ast[n].val_hi), 0, NULL);
        } else {
            ir_record_raw(IR_SUB_CONST, (unsigned)((int)g_ast[n].val_hi), 0, NULL);
        }
        emit_incdec_store_local(lc);
        if (ISPTR(lc->type)) fpr_in();   /* A = new offset, carrier bank */
        g_expr_type = lc->type;
        break;
    }
    case N_NEG:
        walk_val(g_ast[n].a);
        if (g_expr_type == LT_DOUBLE) emit_neg_double();
        else                          emit_unary_neg();
        break;
    case N_BNOT:
        walk_val(g_ast[n].a);
        emit_unary_bnot();
        break;
    case N_LNOT:
        walk_cond(g_ast[n].a);         /* sets Z; a ptr weighs its bank too */
        emit_unary_lnot();
        break;
    case N_ADDR_FUNC: {
        int k = fpr_alloc();
        emit_fpr_addr_func(k, &g_funcs[g_ast[n].val]);
        g_fpr_res        = k;
        g_expr_type      = LT_FN_PTR;
        g_expr_struct_id = -1;
        g_expr_fn_sig    = g_ast[n].fn_sig;
        break;
    }
    case N_ADDR_ARROW_BARE: {
        Field *f = g_ast[n].sym_f;
        int k = fpr_load_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        /* val_hi IS THE PARENT-CHAIN OFFSET, as it is on N_ADDR_DOT_BARE, and
         * it is zero for every `&p->f' -- ast_new clears it.  The `p->o.m'
         * spelling needs it: the leaf's own byte_offset is the LAST hop only
         * (apple/fgx#207). */
        emit_fpr_add_const(k, f->byte_offset + (int)g_ast[n].val_hi);
        g_fpr_res        = k;
        g_expr_type      = g_ast[n].type;
        g_expr_struct_id = g_ast[n].struct_id;
        g_expr_unsigned  = 0;
        break;
    }
    case N_ADDR_ARROW_ARRFIELD:
    case N_ADDR_DOT_ARRFIELD: {
        Field *f = g_ast[n].sym_f;
        int k;
        if (g_ast[n].kind == N_ADDR_ARROW_ARRFIELD)
            k = fpr_load_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        else
            k = fpr_addr_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        emit_fpr_add_const(k, f->byte_offset);
        if (g_ast[n].val_hi)                   /* nested value-member hops */
            emit_fpr_add_const(k, (int)g_ast[n].val_hi);
        walk_val(g_ast[n].a);                  /* index -> A */
        emit_index_scale(g_ast[n].val);
        emit_fpr_add_a(k);
        g_fpr_res        = k;
        g_expr_type      = g_ast[n].type;
        g_expr_struct_id = g_ast[n].struct_id;
        g_expr_unsigned  = 0;
        break;
    }
    case N_ADDR_CHAIN_IDX: {
        int k = fpr_load_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        for (int h = 0; h < g_ast[n].n_kids; h++) {
            Field *f = g_ast_fields[g_ast[n].kid0 + h];
            if (f->type == LT_CHAR_ARRAY || f->type == LT_INT_ARRAY) {
                emit_fpr_add_const(k, f->byte_offset);
                g_expr_type      = (f->type == LT_CHAR_ARRAY) ? LT_CHAR_PTR
                                                              : LT_INT_PTR;
                g_expr_struct_id = -1;
                break;
            }
            if (f->type == LT_STRUCT && h < g_ast[n].n_kids - 1) {
                /* The address twin of the read chain's embedded-struct hop
                 * (apple/fgx#189).  `&E->m->d.arr[i]': `d' is a struct MEMBER
                 * of what `m' points at, so its bytes are already under k and
                 * the hop adds an offset.  Deref'ing it loaded d's first word
                 * and indexed off that -- which PARSED, and produced a wild
                 * address that no compile-time check can see.  The fixture
                 * caught it by asserting the VALUE at the address rather than
                 * that the expression compiled. */
                emit_fpr_add_const(k, f->byte_offset);
                g_expr_type      = LT_STRUCT;
                g_expr_struct_id = f->struct_id;
                continue;
            }
            emit_fpr_deref_field(k, f->type, f->byte_offset);
            g_expr_type      = f->type;
            g_expr_struct_id = f->struct_id;
        }
        int es = (int)g_ast[n].val;
        walk_val(g_ast[n].a);                  /* index -> A */
        /* emit_index_scale, NOT a pair of hand-rolled power-of-two arms.  This
         * read `if (es == 2) ASL; else if (es == 4) ASL ASL;` and emitted NO
         * SCALING AT ALL for every other size -- so a stride of 6 (a struct of
         * two shorts and a pointer) silently became a stride of 1 and the
         * index landed inside the first element.
         *
         * It is the same defect as the parse-side one above and they masked
         * each other: the parser could only ever hand this 1, 2 or 4, because
         * a struct pointee was coerced to 2 before it got here, so the missing
         * arms were unreachable and looked complete.  Fixing only the parser
         * turns a wrong-by-2 into a wrong-by-1.
         *
         * emit_index_scale handles an arbitrary stride and is what
         * N_ADDR_ARR_ELEM immediately below already uses -- the twin that was
         * right all along. */
        emit_index_scale((unsigned)es);
        emit_fpr_add_a(k);
        g_fpr_res        = k;
        g_expr_type      = g_ast[n].type;
        g_expr_struct_id = -1;
        g_expr_unsigned  = 0;
        break;
    }
    case N_ADDR_DOT_BARE: {
        Field *f = g_ast[n].sym_f;
        int k = fpr_addr_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        emit_fpr_add_const(k, f->byte_offset);
        if (g_ast[n].val_hi)                   /* nested value-member hops */
            emit_fpr_add_const(k, (int)g_ast[n].val_hi);
        g_fpr_res        = k;
        g_expr_type      = g_ast[n].type;
        g_expr_struct_id = g_ast[n].struct_id;
        g_expr_unsigned  = 0;
        break;
    }
    case N_ADDR_ARR_ELEM: {
        int k = fpr_addr_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        emit_fpr_add_index(k, g_ast[n].a, g_ast[n].val);
        if (g_ast[n].b == -2 && g_ast[n].val_hi > 0)   /* '.field...' chain */
            emit_fpr_add_const(k, (int)g_ast[n].val_hi);
        if (g_ast[n].c >= 0)                  /* `.arrayfield[j]' (#202) */
            emit_addr_field_index(k, g_ast[n].c, g_ast[n].n_kids);
        g_fpr_res        = k;
        g_expr_type      = g_ast[n].type;
        g_expr_struct_id = g_ast[n].struct_id;
        break;
    }
    case N_ADDR_ARR_ELEM_MD: {
        /* The address twin of N_ARR_READ's offset walk (apple/fgx#192): the
         * SAME walk_cio, so `&a[i][j]' and `a[i][j]' cannot disagree about
         * where the element is. */
        Local  *mlc = g_ast[n].sym_lc;
        Global *mgv = g_ast[n].sym_gv;
        int k = fpr_addr_sym(mlc, mgv);
        if (mlc != NULL)
            (void)walk_cio(g_ast[n].kid0, g_ast[n].n_kids,
                           mlc->n_dims, mlc->dims, air_row_stride(mlc));
        else
            (void)walk_cio(g_ast[n].kid0, g_ast[n].n_kids,
                           mgv->n_dims, mgv->dims, mgv->row_stride);
        emit_fpr_add_a(k);
        if (g_ast[n].b == -2 && g_ast[n].val_hi > 0)   /* '.field...' chain */
            emit_fpr_add_const(k, (int)g_ast[n].val_hi);
        g_fpr_res        = k;
        g_expr_type      = g_ast[n].type;
        g_expr_struct_id = g_ast[n].struct_id;
        break;
    }
    case N_ADDR_PTR_ELEM: {
        int k = fpr_load_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        walk_val(g_ast[n].a);                  /* index -> A */
        emit_index_scale(g_ast[n].val);
        emit_fpr_add_a(k);
        g_fpr_res        = k;
        g_expr_type      = g_ast[n].type;
        g_expr_struct_id = g_ast[n].struct_id;
        g_expr_unsigned  = 0;
        break;
    }
    case N_ADDR_VAR:
        refuse_homed_addr(n);
        fpr_addr_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        break;
    case N_DEREF_POSTINC:
        emit_deref_postinc_local(g_ast[n].sym_lc, (int)g_ast[n].val,
                                 (int)g_ast[n].val_hi);
        if (ISPTR(g_ast[n].type)) fpr_in();
        break;
    case N_FNPTR_DESIG:
        fpr_load_sym(g_ast[n].sym_lc, NULL);
        g_expr_type   = LT_FN_PTR;
        g_expr_fn_sig = g_ast[n].sym_lc->fn_sig_id;
        break;
    case N_DEREF_FAST:
        emit_deref_fast(g_ast[n].sym_lc);
        if (ISPTR(g_ast[n].type)) fpr_in();
        break;
    case N_DEREF_GENERAL: {
        int ka = walk_fpr(g_ast[n].a);
        if (g_ast[g_ast[n].a].type == LT_FN_PTR) {
            g_fpr_res = ka;            /* fn designator: '*' is a no-op */
            break;
        }
        tword result = DECREF(g_ast[g_ast[n].a].type);
        emit_fpr_deref_field(ka, result, 0);
        g_expr_type = deref_result_expr_type(result);
        g_expr_unsigned = g_ast[n].is_unsigned;   /* A-1: pointee signedness */
        if (ISPTR(result)) g_fpr_res = ka;
        else               fpr_drop(ka);
        break;
    }
    /* --- primary, pre-IDENT arms --- */
    case N_CAST: {
        LocalType target = (LocalType)g_ast[n].val;
        /* Key on the TARGET TYPE, not build's star-count flag: a typedef'd
         * fn-ptr cast `(cb_t)f` has val_hi==0 but a pointer target. */
        int is_ptr = ISPTR(target) || (int)g_ast[n].val_hi;
        LocalType ct = g_ast[g_ast[n].a].type;
        if (target == LT_VOID && ct == LT_DOUBLE) {
            /* K&R A.6.7: "An expression may be converted to type void by a
             * cast.  For example, a void cast documents the discarding of
             * the value" -- so nothing is computed from it.  Converting it
             * as to an integer called the soft double for a value no one
             * reads (printf.c's `(void)va_arg(ap, double)'). */
            walk_val(g_ast[n].a);
            g_expr_type = LT_VOID;
            break;
        }
        if (target == LT_DOUBLE || ct == LT_DOUBLE) {
            /* A.6.3/A.6.4: to or from double, by value. */
            if (is_ptr)
                die(g_ast[n].line, g_ast[n].col, "a double cannot be "
                    "converted to a pointer");
            walk_val(g_ast[n].a);
            if (target == LT_DOUBLE)
                emit_to_quad(LT_DOUBLE);
            else
                emit_from_double(target);
            if (target == LT_CHAR)
                ir_emitf("                AND     #$00FF\n");
            g_expr_type = target;
            g_expr_unsigned = g_ast[n].is_unsigned;
            break;
        }
        if (is_ptr) {
            int k;
            if (ISPTR(ct)) {
                k = walk_fpr(g_ast[n].a);      /* ptr -> ptr: retype only */
            } else if (ct == LT_LONG) {
                /* T5-C C4: long -> ptr restores the far value — the high
                 * word IS the bank (symmetric with ptr -> long above). */
                walk_val(g_ast[n].a);          /* A=lo, _fcc_long_hi=hi */
                k = fpr_alloc();
                emit_fpr_from_a(k, BANK_LONG_HI);
            } else if (ct == LT_STRUCT) {
                /* apple/fgx#42: a STRUCT VALUE is already an ADDRESS, carried
                 * the legacy way -- A = offset, _fcc_ptr+2 = bank -- and that
                 * bank is the storage's: 0 for a hardware frame, DBR for a
                 * soft frame or a global.  Casting it to a pointer is a
                 * RETYPE, exactly like the ISPTR arm above; it is not an
                 * integer becoming a pointer.  Without this arm it fell to the
                 * ITP rule below, which stamps DBR unconditionally, so
                 * `(char *)automatic_struct` addressed the DATA bank at the
                 * bank-0 frame offset.
                 *
                 * That is #42.  tcsh's sh.parse.c alias() declares
                 * `jmp_buf osetexit` -- an automatic -- and sh.h's getexit()
                 * expands to copy((char *)(osetexit), ...).  The destination
                 * reached copy() as DBR:frame_offset, so 12 bytes of jmp_buf
                 * landed in the malloc heap on top of whatever block sat at
                 * that offset.  At tcsh's shipping data-segment size the write
                 * was harmless; add ~6 KB and the heap moves under it, the
                 * write lands on a live free-list block, and the next free()
                 * walks a cycle forever -- a login that never prints a prompt.
                 *
                 * setjmp.h documents the stack-local jmp_buf hazard and says
                 * fcc fails closed on it, but that guard fires at a setjmp()
                 * CALL and alias() never calls setjmp on osetexit -- it only
                 * copies it.  walk_val is safe here: the struct walk leaves no
                 * FPR, so fpr_collapse is a no-op and _fcc_ptr+2 survives. */
                walk_val(g_ast[n].a);
                k = fpr_alloc();
                emit_fpr_from_carrier_a(k);
            } else {
                walk_val(g_ast[n].a);          /* int -> A */
                k = fpr_alloc();
                /* int -> ptr: a RUNTIME integer reconstitutes into the data
                 * bank (DBR); a COMPILE-TIME constant keeps bank 0 (NULL,
                 * `(char*)-1` sentinel, `(char*)0xC000` hardware addr).  The
                 * 2.11BSD sh/tcsh blok.c arena round-trips pointers through `int`
                 * (Rcheat) and casts back with BLK((int)x) -- that reconstitution
                 * must land in the data bank or the free-block chain walk loops
                 * forever. */
                emit_fpr_from_a(k,
                    BANK_OF_CONST(cast_operand_is_const(g_ast[n].a)));
            }
            g_fpr_res = k;
            g_expr_type = target;
            if (target == LT_STRUCT_PTR)
                g_expr_struct_id = g_ast[n].struct_id;
            g_expr_unsigned = g_ast[n].is_unsigned;
            break;
        }
        if (target == LT_LONG && (ISPTR(ct) || ISARY(ct))) {   /* arrays decay */
            /* T5-C C4: ptr -> long carries the FULL far value — offset in
             * the low word, BANK in the high.  The old path promoted the
             * offset through long_from_int and dropped the bank (caught
             * by M37/fileops: write()'s buffer bank arrived as 0). */
            int k = walk_fpr(g_ast[n].a);
            fpr_sym_flush(k);
            ir_emitf("                LDA     %s+2\n", fpr_name(k));
            ir_emitf("                STA     _fcc_long_hi\n");
            emit_fpr_to_a(k);
            fpr_drop(k);
            g_expr_type = LT_LONG;
            g_expr_unsigned = g_ast[n].is_unsigned;
            break;
        }
        walk_val(g_ast[n].a);                  /* ptr operand -> offset word */
        if (target == LT_FLOAT && ct == LT_LLONG) {
            die(g_ast[n].line, g_ast[n].col, "long long to float conversion "
                "is not implemented yet (apple/fgx#447 increment 2)");
        } else if (target == LT_LLONG) {
            /* Widen by the SOURCE's signedness (A.6.2), which walk_val
             * leaves in g_expr_unsigned. */
            emit_to_llong();
        } else if (ct == LT_LLONG && target != LT_FLOAT) {
            /* Narrowing to long, int or char: w0/w1 already are the low
             * half, so there is nothing to do here (the char mask is below). */
            g_expr_type = target;
        } else if (target == LT_FLOAT &&
            (ct == LT_INT || ct == LT_CHAR)) {
            emit_int_to_float();
        } else if (target == LT_FLOAT && ct == LT_LONG) {
            emit_long_to_float();
        } else if ((target == LT_INT || target == LT_CHAR) &&
                   ct == LT_FLOAT) {
            emit_float_to_int();
        } else if (target == LT_LONG && ct == LT_FLOAT) {
            emit_float_to_long();
        } else if (target == LT_LONG && ct != LT_LONG) {
            emit_promote_a_to_long();
        } else if (target == LT_INT && ct == LT_LONG) {
            g_expr_type = LT_INT;      /* narrowing: A already holds low */
        }
        if (target == LT_CHAR) {
            ir_emitf("                AND     #$00FF\n");
        }
        g_expr_type = target;
        if (target == LT_STRUCT_PTR)
            g_expr_struct_id = g_ast[n].struct_id;
        g_expr_unsigned = g_ast[n].is_unsigned;
        break;
    }
    case N_CAST_FNPTR: {
        int k = walk_fpr(g_ast[n].a);
        g_fpr_res       = k;
        g_expr_type     = LT_FN_PTR;
        g_expr_unsigned = 0;
        break;
    }
    case N_LIT_INT:
        emit_load_lit(g_ast[n].val);
        /* Publish the constant's signedness (K&R A.2.5.1 ladder: an unsuffixed
         * hex/octal constant in [0x8000,0xFFFF] is UNSIGNED int, as is any U
         * suffix).  The node has carried is_unsigned since A-1, but this arm
         * never propagated it, so emit_promote_a_to_long saw a stale flag and
         * sign-extended: `long a = 0xFFFF` stored 0xFFFFFFFF, not 65535.  The
         * neighbouring LONG/FLOAT arms both manage this flag for the same
         * reason -- leaving it stale here let the previous primary leak in. */
        g_expr_unsigned = g_ast[n].is_unsigned;
        break;
    case N_LIT_LLONG:
        ir_emitf("                LDA     #%u\n", g_ast[n].val3 & 0xFFFF);
        ir_emitf("                STA     _fcc_q3\n");
        ir_emitf("                LDA     #%u\n", g_ast[n].val2 & 0xFFFF);
        ir_emitf("                STA     _fcc_q2\n");
        ir_emitf("                LDA     #%u\n", g_ast[n].val_hi & 0xFFFF);
        ir_emitf("                STA     _fcc_long_hi\n");
        ir_emitf("                LDA     #%u\n", g_ast[n].val & 0xFFFF);
        g_expr_type = LT_LLONG;
        g_expr_unsigned = g_ast[n].is_unsigned;
        break;
    case N_LIT_LONG:
        emit_load_lit_long(g_ast[n].val, g_ast[n].val_hi);
        g_expr_unsigned = 0;           /* primary entry reset */
        break;
    case N_LIT_FLOAT:
        if (g_ast[n].type == LT_DOUBLE) {
            ir_emitf("                LDA     #%u\n", g_ast[n].val3 & 0xFFFF);
            ir_emitf("                STA     _fcc_q3\n");
            ir_emitf("                LDA     #%u\n", g_ast[n].val2 & 0xFFFF);
            ir_emitf("                STA     _fcc_q2\n");
            ir_emitf("                LDA     #%u\n", g_ast[n].val_hi & 0xFFFF);
            ir_emitf("                STA     _fcc_long_hi\n");
            ir_emitf("                LDA     #%u\n", g_ast[n].val & 0xFFFF);
            g_expr_type = LT_DOUBLE;
        } else {
            emit_load_lit_float(g_ast[n].val, g_ast[n].val_hi);
        }
        g_expr_unsigned = 0;           /* primary entry reset */
        break;
    case N_LIT_CHAR:
        emit_load_lit(g_ast[n].val);
        g_expr_type = LT_CHAR;
        break;
    case N_LIT_STR: {
        int k = fpr_alloc();
        emit_fpr_lit_str(k, (int)g_ast[n].val);
        g_fpr_res = k;
        g_expr_type = LT_CHAR_PTR;
        g_expr_struct_id = -1;
        g_expr_unsigned = 0;
        break;
    }
    case N_IPV_READ: {
        int ka = walk_fpr(g_ast[n].a);         /* base pointer value */
        int es = (int)g_ast[n].val;
        walk_val(g_ast[n].b);                  /* index -> A */
        emit_index_scale((unsigned)es);
        emit_fpr_add_a(ka);
        tword pt   = (tword)g_ast[n].val_hi;
        tword elem = DECREF(pt);
        if (ISPTR(elem)) {
            emit_fpr_deref_field(ka, elem, 0);
            g_fpr_res   = ka;
            g_expr_type = elem;
        } else if (pt == LT_LONG_PTR || pt == LT_FLOAT_PTR ||
                   pt == LT_LLONG_PTR || pt == LT_DOUBLE_PTR) {
            emit_fpr_deref_field(ka, elem, 0);
            fpr_drop(ka);
            g_expr_type = elem;
        } else {
            emit_fpr_deref_field(ka, (es == 1) ? LT_CHAR : LT_INT, 0);
            fpr_drop(ka);
            g_expr_type = (es == 1) ? LT_CHAR : LT_INT;
        }
        g_expr_unsigned  = 0;
        g_expr_struct_id = -1;
        break;
    }
    case N_IPV_STORE: {
        int ka = walk_fpr(g_ast[n].a);
        int es = (int)g_ast[n].val;
        tword pt = (tword)g_ast[n].val_hi;
        walk_val(g_ast[n].b);                  /* index -> A */
        emit_index_scale((unsigned)es);
        emit_fpr_add_a(ka);
        if (pt == LT_LLONG_PTR || pt == LT_DOUBLE_PTR) {
            walk_val(g_ast[n].c);
            emit_to_quad(DECREF(pt));
            emit_fpr_deref_store_llong(ka, 0);
            fpr_drop(ka);
            g_fpr_res        = -1;
            g_expr_type      = DECREF(pt);
            g_expr_unsigned  = 0;
            g_expr_struct_id = -1;
            break;
        }
        if (pt == LT_LONG_PTR || pt == LT_FLOAT_PTR) {
            /* 32-bit element store: rhs -> long/float accumulator (int widened),
             * then a full 4-byte deref store — a word store would drop the high
             * 16 bits (the FD_SET bit-30 bug). */
            walk_val(g_ast[n].c);
            if (pt == LT_FLOAT_PTR &&
                (g_expr_type == LT_INT || g_expr_type == LT_CHAR))
                emit_itof_rt();
            else if (g_expr_type == LT_INT || g_expr_type == LT_CHAR)
                emit_promote_a_to_long();
            emit_fpr_deref_store_long(ka, 0);
            fpr_drop(ka);
            g_fpr_res        = -1;
            g_expr_type      = (pt == LT_FLOAT_PTR) ? LT_FLOAT : LT_LONG;
            g_expr_unsigned  = 0;
            g_expr_struct_id = -1;
            break;
        }
        walk_expr(g_ast[n].c);                 /* rhs */
        if (g_fpr_res >= 0) {
            /* pointer element store: full (offset,bank) — the legacy arm
             * word-stored and dropped the bank. */
            int ks = g_fpr_res;
            emit_fpr_deref_store_ptr(ka, ks, 0);
            emit_fpr_to_a(ks);                 /* result = RHS offset (node is int-typed) */
            fpr_drop(ks);
        } else if (es == 1) {
            emit_fpr_deref_store_byte(ka, 0);
        } else {
            emit_fpr_deref_store_word(ka, 0);
        }
        fpr_drop(ka);
        g_fpr_res        = -1;
        g_expr_type      = (es == 1) ? LT_CHAR : LT_INT;
        g_expr_unsigned  = 0;
        g_expr_struct_id = -1;
        break;
    }
    case N_ARROW_CHAIN: {
        int ka = walk_fpr(g_ast[n].a);
        for (int h = 0; h < g_ast[n].n_kids; h++) {
            Field *f = g_ast_fields[g_ast[n].kid0 + h];
            if (f->type == LT_CHAR_ARRAY || f->type == LT_INT_ARRAY) {
                emit_fpr_add_const(ka, f->byte_offset);
                g_expr_type      = (f->type == LT_CHAR_ARRAY) ? LT_CHAR_PTR
                                                              : LT_INT_PTR;
                g_expr_struct_id = -1;
                break;
            }
            if (f->type == LT_STRUCT && h < g_ast[n].n_kids - 1) {
                /* AN EMBEDDED STRUCT HOP IS AN ADDRESS STEP, NOT A LOAD
                 * (apple/fgx#189).  `E->m.n' where m is a struct MEMBER rather
                 * than a struct POINTER: m's bytes are inside the object ka
                 * already points at, so the hop adds m's offset and keeps the
                 * pointer, exactly as the array arm above does.  Deref'ing it
                 * would load the first word of m and then index off a value.
                 *
                 * Guarded on it not being the LAST hop, which is what keeps
                 * this from touching anything that already worked: before the
                 * parser change above, the hop run only continued through
                 * LT_STRUCT_PTR, so an INTERMEDIATE LT_STRUCT hop could not be
                 * produced at all.  A trailing one -- `E->m' read as a struct
                 * value -- still takes the old path. */
                emit_fpr_add_const(ka, f->byte_offset);
                g_expr_type      = LT_STRUCT;
                g_expr_struct_id = f->struct_id;
                g_expr_unsigned  = 0;
                continue;
            }
            emit_fpr_deref_field(ka, f->type, f->byte_offset);
            g_expr_type      = f->type;
            g_expr_struct_id = f->struct_id;
            g_expr_unsigned  = 0;
        }
        if (ISPTR(g_ast[n].type)) g_fpr_res = ka;
        else                      fpr_drop(ka);
        break;
    }
    case N_CALL_STASHED: {
        int nspill = emit_fpr_spill_live();
        int kc = walk_fpr(g_ast[n].a);         /* callee (offset,bank) */
        int sig = (int)g_ast[n].val;
        int actual_argc = 0, total_arg_bytes = 0;
        emit_fpr_push(kc);                 /* 4-byte stash (same layout) */
        fpr_drop(kc);
        g_fpr_res = -1;
        RtlArgs rtl;
        rtl_begin(&rtl, 1, g_fn_sigs[sig].is_variadic);
        total_arg_bytes = walk_call_args(g_ast[n].kid0, g_ast[n].n_kids,
                                         g_fn_sigs[sig].param_types, NULL,
                                         g_fn_sigs[sig].n_params, -1, &rtl,
                                         &actual_argc);
        rtl_finish(&rtl, g_ast[n].line, g_ast[n].col);
        call_stashed_fnptr(total_arg_bytes, g_ast[n].line, g_ast[n].col);
        g_expr_type      = g_fn_sigs[sig].return_type;
        g_expr_struct_id = -1;
        g_expr_unsigned  = g_fn_sigs[sig].ret_unsigned;   /* A-1 */
        g_expr_fn_sig    = -1;
        if (ISPTR(g_expr_type) && !(g_ast[n].flags & AF_STMT_DISCARD))
            fpr_capture_ret(nspill);
        else
            emit_fpr_restore_live(nspill);
        break;
    }
    /* --- primary IDENT arm --- */
    case N_SETJMP: {
        int nspill = emit_fpr_spill_live();
        walk_val(g_ast[n].a);          /* env -> A = &jmp_buf offset */
        ir_record_raw(IR_TAX, 0, 0, NULL);
        emit_libc_call("setjmp");
        emit_fpr_restore_live(nspill);
        g_expr_type      = LT_INT;
        g_expr_struct_id = -1;
        g_expr_unsigned  = 0;
        break;
    }
    case N_LONGJMP: {
        int nspill = emit_fpr_spill_live();
        walk_val(g_ast[n].a);
        emit_push_a();                 /* PHA &env */
        walk_val(g_ast[n].b);          /* val -> A */
        ir_emitf("                PLX\n");
        g_s_delta -= 2;
        emit_libc_call("longjmp");
        emit_fpr_restore_live(nspill);
        g_expr_type      = LT_INT;
        g_expr_struct_id = -1;
        g_expr_unsigned  = 0;
        break;
    }
    case N_SYSCALL: {
        /* Marshal a/x/y to the registers and emit the inline trampoline
         * pair.  DB variant: caller's DBR is saved UNDER the arg pushes
         * (so the pulls line up), the bank expression walks LAST (arg
         * expressions must evaluate under the caller's DBR), and the
         * carry/Y latch runs after the PLB restore (PLB preserves C). */
        int is_db = (g_ast[n].flags & AF_SYSCALL_DB) != 0;
        if (is_db) {
            ir_emitf("                PHB\n");
            g_s_delta += 1;
        }
        walk_val(g_ast_kids[g_ast[n].kid0 + 0]);
        emit_push_a();
        walk_val(g_ast_kids[g_ast[n].kid0 + 1]);
        emit_push_a();
        walk_val(g_ast_kids[g_ast[n].kid0 + 2]);
        if (is_db) {
            emit_push_a();
            walk_val(g_ast_kids[g_ast[n].kid0 + 3]);   /* A = buf bank */
            ir_emitf("                SEP     #$20\n");
            ir_emitf("                MX      %%10\n");
            ir_emitf("                PHA\n");
            ir_emitf("                PLB\n");
            ir_emitf("                REP     #$20\n");
            ir_emitf("                MX      %%00\n");
            ir_emitf("                PLY\n");
            ir_emitf("                PLX\n");
            ir_emitf("                PLA\n");
            g_s_delta -= 6;
        } else {
            ir_emitf("                TAY\n");
            ir_emitf("                PLX\n");
            ir_emitf("                PLA\n");
            g_s_delta -= 4;
        }
        ir_emitf("                JSL     SYS_TRAMP\n");
        ir_emitf("                DFB     %u\n", g_ast[n].val);
        if (is_db) {
            ir_emitf("                PLB\n");
            g_s_delta -= 1;
        }
        {   /* latch carry + Y for __syscall_c()/__syscall_y() */
            int lab = new_label();
            ir_emitf("                LDX     #0\n");
            emit_bcond(2 /* BCC */, lab, 0);
            ir_emitf("                LDX     #1\n");
            emit_label(lab);
            ir_emitf("                STX     __sys_c\n");
            ir_emitf("                STY     __sys_y\n");
        }
        g_expr_type      = LT_INT;
        g_expr_struct_id = -1;
        g_expr_unsigned  = 1;
        break;
    }
    case N_SYSCALL_CELL:
        ir_emitf("                LDA     %s\n",
                 g_ast[n].val ? "__sys_y" : "__sys_c");
        g_expr_type      = LT_INT;
        g_expr_struct_id = -1;
        g_expr_unsigned  = 1;
        break;
    case N_CALL_FPVAR: {
        int nspill = emit_fpr_spill_live();
        int sig = (int)g_ast[n].val;
        int actual_argc = 0, total_arg_bytes = 0;
        RtlArgs rtl;
        rtl_begin(&rtl, 1, g_fn_sigs[sig].is_variadic);
        total_arg_bytes = walk_call_args(g_ast[n].kid0, g_ast[n].n_kids,
                                         g_fn_sigs[sig].param_types, NULL,
                                         g_fn_sigs[sig].n_params, -1, &rtl,
                                         &actual_argc);
        rtl_finish(&rtl, g_ast[n].line, g_ast[n].col);
        {   /* P3-2.5b: the fn-ptr value rides an FPR into the dispatch
             * (locals via the 2.5a native IR op, globals native). */
            int kc = fpr_load_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
            emit_call_indirect(kc);
            fpr_drop(kc);
        }
        if (g_ast[n].flags & AF_STMT_DISCARD) {
            if (total_arg_bytes > 0) {
                ir_emitf("                TSC\n");
                ir_record_raw(IR_ADD_CONST, (unsigned)(total_arg_bytes), 0, NULL);
                ir_emitf("                TCS\n");
                g_s_delta -= total_arg_bytes;
            }
        } else if (total_arg_bytes == 2 * actual_argc) {
            emit_drop_args(actual_argc);
        } else {
            ir_record_raw(IR_TAY, 0, 0, NULL);
            ir_emitf("                TSC\n");
            ir_record_raw(IR_ADD_CONST, (unsigned)(total_arg_bytes), 0, NULL);
            ir_emitf("                TCS\n");
            ir_record_raw(IR_TYA, 0, 0, NULL);
            g_s_delta -= total_arg_bytes;
        }
        g_expr_type      = g_fn_sigs[sig].return_type;
        g_expr_struct_id = -1;
        g_expr_unsigned  = g_fn_sigs[sig].ret_unsigned;   /* A-1 */
        if (ISPTR(g_expr_type) && !(g_ast[n].flags & AF_STMT_DISCARD))
            fpr_capture_ret(nspill);
        else
            emit_fpr_restore_live(nspill);
        break;
    }
    case N_CALL_NAMED: {
        int nspill = emit_fpr_spill_live();
        int fn_idx = (int)g_ast[n].val;
        int actual_argc = 0, total_arg_bytes = 0;
        RtlArgs rtl;
        /* Marshalling order comes from the caller's declaration: an explicit
         * `...` or empty-paren decl marks right-to-left (variadic/K&R). */
        rtl_begin(&rtl, 1, g_funcs[fn_idx].is_variadic);
        total_arg_bytes = walk_call_args(g_ast[n].kid0, g_ast[n].n_kids,
                                         g_funcs[fn_idx].param_types,
                                         g_funcs[fn_idx].param_struct_ids,
                                         g_funcs[fn_idx].n_params,
                                         g_funcs[fn_idx].n_fixed, &rtl,
                                         &actual_argc);
        rtl_finish(&rtl, g_ast[n].line, g_ast[n].col);
        emit_call(g_ast[n].name, g_ast[n].name_len, !g_pile);
        if (total_arg_bytes == 2 * actual_argc) {
            emit_drop_args(actual_argc);
        } else if (g_ast[n].flags & AF_STMT_DISCARD) {
            ir_emitf("                TSC\n");
            ir_record_raw(IR_ADD_CONST, (unsigned)(total_arg_bytes), 0, NULL);
            ir_emitf("                TCS\n");
            g_s_delta -= total_arg_bytes;
        } else {
            ir_record_raw(IR_TAY, 0, 0, NULL);
            ir_emitf("                TSC\n");
            ir_record_raw(IR_ADD_CONST, (unsigned)(total_arg_bytes), 0, NULL);
            ir_emitf("                TCS\n");
            ir_record_raw(IR_TYA, 0, 0, NULL);
            g_s_delta -= total_arg_bytes;
        }
        g_expr_type      = g_funcs[fn_idx].return_type;
        g_expr_struct_id = g_funcs[fn_idx].return_struct_id;
        g_expr_unsigned  = g_funcs[fn_idx].ret_unsigned;
        if (ISPTR(g_expr_type) && !(g_ast[n].flags & AF_STMT_DISCARD)) {
            /* One pointer-return ABI (P3-2.7): C-compiled callees AND
             * hand-asm libc shims home the far return in FPR0. */
            fpr_capture_ret(nspill);
        } else {
            emit_fpr_restore_live(nspill);
        }
        break;
    }
    case N_ENUM_CONST:
        emit_load_lit(g_ast[n].val);
        break;
    case N_VAR_LOAD: {
        Local  *lc = g_ast[n].sym_lc;
        Global *gv = g_ast[n].sym_gv;
        if (lc != NULL) {
            if (lc->type == LT_STRUCT) {
                emit_addr_of_local(lc);        /* struct value: legacy A+carrier */
                g_expr_type = LT_STRUCT;
            } else if (lc->type == LT_INT_ARRAY || lc->type == LT_CHAR_ARRAY ||
                       ISARY(lc->type)) {
                fpr_addr_sym(lc, NULL);        /* array decay -> FPR */
            } else if (ISPTR(lc->type)) {
                fpr_load_sym(lc, NULL);
            } else {
                emit_load_local(lc);
            }
        } else {
            if (gv->type == LT_STRUCT) {
                emit_addr_of_global(gv);
                g_expr_type = LT_STRUCT;
            } else if (ISARY(gv->type)) {
                fpr_addr_sym(NULL, gv);
            } else if (ISPTR(gv->type)) {
                fpr_load_sym(NULL, gv);
            } else {
                emit_load_global(gv);
            }
        }
        break;
    }
    case N_ARR_READ: {
        Local  *lc = g_ast[n].sym_lc;
        Global *gv = g_ast[n].sym_gv;
        int k;
        if (lc != NULL) {
            int snap = emit_air_head(lc);
            int consumed = walk_cio(g_ast[n].kid0, g_ast[n].n_kids,
                                    lc->n_dims, lc->dims, air_row_stride(lc));
            k = emit_air_tail(lc, snap, consumed);
        } else {
            int consumed = walk_cio(g_ast[n].kid0, g_ast[n].n_kids,
                                    gv->n_dims, gv->dims, gv->row_stride);
            k = emit_airg_tail(gv, consumed);
        }
        if (ISPTR(g_ast[n].type)) {
            /* P3-2.7: every ptr-result tail path (element / row decay)
             * homes the value in an FPR itself — no carrier bridge. */
            if (k < 0)
                die(g_ast[n].line, g_ast[n].col,
                    "fcc-ast: N_ARR_READ ptr result missing its FPR");
            g_fpr_res = k;
        } else if (k >= 0) {
            fpr_drop(k);
        }
        break;
    }
    case N_ARR_POSTINC: {
        Local  *lc = g_ast[n].sym_lc;
        Global *gv = g_ast[n].sym_gv;
        int is_byte = (g_ast[n].flags & AF_IS_BYTE) != 0;
        int k = fpr_addr_sym(lc, gv);
        walk_val(g_ast[n].a);                  /* index -> A */
        if (!is_byte) ir_emitf("                ASL\n");
        emit_fpr_add_a(k);
        emit_fpr_deref_field(k, is_byte ? LT_CHAR : LT_INT, 0);
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* OLD (yield) */
        if (g_ast[n].flags & AF_IS_INC) {
            ir_emitf("                CLC\n");
            ir_emitf("                ADC     #1\n");
        } else {
            ir_emitf("                SEC\n");
            ir_emitf("                SBC     #1\n");
        }
        if (is_byte) emit_fpr_deref_store_byte(k, 0);
        else         emit_fpr_deref_store_word(k, 0);
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* A = OLD */
        fpr_drop(k);
        g_expr_type      = is_byte ? LT_CHAR : LT_INT;
        g_expr_struct_id = -1;
        g_expr_unsigned  = 0;
        break;
    }
    case N_POSTINC_LOCAL: {
        Local *lc = g_ast[n].sym_lc;
        if (IS_QUAD(lc->type)) {
            emit_llong_incdec(lc, NULL, (g_ast[n].flags & AF_IS_INC) != 0, 1);
            g_fpr_res = -1;
            break;
        }
        if (lc->type == LT_FLOAT) {
            emit_float_var_incdec(lc, NULL, (g_ast[n].flags & AF_IS_INC) != 0,
                                  /*return_old=*/1);
            g_fpr_res = -1;
            break;
        }
        if (lc->type == LT_LONG) {          /* postfix ++/-- yields the OLD value */
            /* 32-bit ±1 with carry/borrow; return_old recovers the pre-update
             * value.  See N_PREINC_LOCAL for the low-word-only wrap bug this
             * avoids. */
            emit_long_incdec_local(lc, (g_ast[n].flags & AF_IS_INC) ? 1 : 0,
                                   /*return_old=*/1);
            g_expr_type      = LT_LONG;
            g_expr_struct_id = -1;
            g_expr_unsigned  = lc->is_unsigned;
            break;
        }
        if (ISPTR(lc->type)) {
            emit_load_local(lc);
            int k = fpr_in();          /* k = OLD (offset+bank); A = old offset */
            if (g_ast[n].flags & AF_IS_INC) {
                ir_record_raw(IR_ADD_CONST, (unsigned)((int)g_ast[n].val), 0, NULL);
            } else {
                ir_record_raw(IR_SUB_CONST, (unsigned)((int)g_ast[n].val), 0, NULL);
            }
            emit_incdec_store_local(lc);       /* structured offset store */
            g_fpr_res   = k;
            g_expr_type = lc->type;
            break;
        }
        emit_load_local(lc);
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
        if (g_ast[n].flags & AF_IS_INC) {
            ir_record_raw(IR_ADD_CONST, (unsigned)((int)g_ast[n].val), 0, NULL);
        } else {
            ir_record_raw(IR_SUB_CONST, (unsigned)((int)g_ast[n].val), 0, NULL);
        }
        emit_incdec_store_local(lc);
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
        g_expr_type = lc->type;
        break;
    }
    case N_CALL_FPFIELD: {
        int nspill = emit_fpr_spill_live();
        int sig = (int)g_ast[n].val;
        int actual_argc = 0, total_arg_bytes = 0;
        RtlArgs rtl;
        rtl_begin(&rtl, 1, g_fn_sigs[sig].is_variadic);
        total_arg_bytes = walk_call_args(g_ast[n].kid0, g_ast[n].n_kids,
                                         g_fn_sigs[sig].param_types, NULL,
                                         g_fn_sigs[sig].n_params, -1, &rtl,
                                         &actual_argc);
        rtl_finish(&rtl, g_ast[n].line, g_ast[n].col);
        {   /* P3-2.5b: the stored (offset,bank) field pair rides an FPR
             * into the dispatch.  The stored bank is real under
             * --far-calls (FGX2_LONG_PTR reloc); single-bank dispatch
             * ignores the bank (computed RTS). */
            Field synth_fp = *g_ast[n].sym_f;
            int kc = fpr_alloc();
            synth_fp.byte_offset = (int)g_ast[n].val_hi;
            emit_fpr_load_field(kc, g_ast[n].sym_lc, g_ast[n].sym_gv,
                                &synth_fp);
            emit_call_indirect(kc);
            fpr_drop(kc);
        }
        if (total_arg_bytes == 2 * actual_argc) {
            emit_drop_args(actual_argc);
        } else {
            ir_record_raw(IR_TAY, 0, 0, NULL);
            ir_emitf("                TSC\n");
            ir_record_raw(IR_ADD_CONST, (unsigned)(total_arg_bytes), 0, NULL);
            ir_emitf("                TCS\n");
            ir_record_raw(IR_TYA, 0, 0, NULL);
            g_s_delta -= total_arg_bytes;
        }
        g_expr_type      = g_fn_sigs[sig].return_type;
        g_expr_struct_id = -1;
        g_expr_unsigned  = g_fn_sigs[sig].ret_unsigned;   /* A-1 */
        if (ISPTR(g_expr_type) && !(g_ast[n].flags & AF_STMT_DISCARD))
            fpr_capture_ret(nspill);
        else
            emit_fpr_restore_live(nspill);
        break;
    }
    case N_ELEM_ADDR: {
        int k;
        if (g_ast[n].flags & AF_BASE_LOAD)
            k = fpr_load_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        else
            k = fpr_addr_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        emit_fpr_add_const(k, (int)g_ast[n].val);
        walk_val(g_ast[n].a);                  /* index -> A */
        emit_index_scale(g_ast[n].val_hi);
        emit_fpr_add_a(k);
        g_fpr_res = k;
        break;
    }
    case N_AV_ELEM_ADDR: {
        int is_byte = (g_ast[n].flags & AF_IS_BYTE) != 0;
        int k = fpr_load_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        emit_fpr_add_const(k, (int)g_ast[n].val);
        walk_val(g_ast[n].a);                  /* index -> A */
        if (!is_byte) ir_emitf("                ASL\n");
        emit_fpr_add_a(k);
        emit_fpr_deref_field(k, is_byte ? LT_CHAR : LT_INT, 0);
        fpr_drop(k);
        g_expr_type      = is_byte ? LT_CHAR : LT_INT;
        g_expr_struct_id = -1;
        g_expr_unsigned  = 0;
        break;
    }
    case N_ELEM_CHAR:
    case N_ELEM_INT: {
        int ka = walk_fpr(g_ast[n].a);
        emit_fpr_deref_field(ka,
            (g_ast[n].kind == N_ELEM_CHAR) ? LT_CHAR : LT_INT, 0);
        fpr_drop(ka);
        g_expr_type = (g_ast[n].kind == N_ELEM_CHAR) ? LT_CHAR : LT_INT;
        g_expr_unsigned = g_ast[n].sym_f->is_unsigned;
        break;
    }
    case N_ELEM_LONG: {
        /* 4-byte element (long OR float array field — same carrier;
         * the node type keeps float expressions float-typed). */
        int ka = walk_fpr(g_ast[n].a);
        emit_fpr_deref_field(ka, g_ast[n].type, 0);
        fpr_drop(ka);
        g_expr_type = g_ast[n].type;
        g_expr_unsigned = g_ast[n].sym_f->is_unsigned;
        break;
    }
    case N_ELEM_FIELD: {
        Field *f2 = g_ast[n].sym_f2;
        int ka = walk_fpr(g_ast[n].a);
        emit_fpr_deref_field(ka, f2->type, f2->byte_offset);
        if (ISPTR(f2->type)) g_fpr_res = ka;
        else                 fpr_drop(ka);
        g_expr_type = f2->type;
        g_expr_unsigned = f2->is_unsigned;
        break;
    }
    case N_ELEM_PTRELEM: {
        int ka = walk_fpr(g_ast[n].a);
        emit_fpr_deref_field(ka, (LocalType)g_ast[n].val, 0);
        g_fpr_res = ka;
        g_expr_type = (LocalType)g_ast[n].val;
        g_expr_unsigned = 0;
        break;
    }
    case N_SAF_IDX: {
        Field *f = g_ast[n].sym_f;
        int is_byte = (g_ast[n].flags & AF_IS_BYTE) != 0;
        int ka = walk_fpr(g_ast[n].a);         /* &arr[i] */
        emit_fpr_add_const(ka, f->byte_offset);
        walk_val(g_ast[n].b);                  /* j -> A */
        if (!is_byte) ir_emitf("                ASL\n");
        emit_fpr_add_a(ka);
        if (g_ast[n].flags & AF_ROW) {         /* a row: its address */
            g_fpr_res   = ka;
            g_expr_type = g_ast[n].type;
            break;
        }
        emit_fpr_deref_field(ka, is_byte ? LT_CHAR : LT_INT, 0);
        fpr_drop(ka);
        g_expr_unsigned = f->is_unsigned;
        g_expr_type = is_byte ? LT_CHAR : LT_INT;
        break;
    }
    case N_SAF_IDXW: {
        /* apple/fgx#170.  N_SAF_IDX's shape with the stride and the load type
         * carried on the node instead of implied by a byte flag: &arr[i], plus
         * the field's offset, plus j scaled by the element size, then loaded. */
        Field *f = g_ast[n].sym_f;
        int ka = walk_fpr(g_ast[n].a);         /* &arr[i] */
        emit_fpr_add_const(ka, f->byte_offset);
        walk_val(g_ast[n].b);                  /* j -> A */
        emit_index_scale((unsigned)g_ast[n].val_hi);
        emit_fpr_add_a(ka);
        emit_fpr_deref_field(ka, g_ast[n].type, 0);
        if (ISPTR(g_ast[n].type)) g_fpr_res = ka;
        else                      fpr_drop(ka);
        g_expr_unsigned  = f->is_unsigned;
        g_expr_type      = g_ast[n].type;
        g_expr_struct_id = g_ast[n].struct_id;
        break;
    }
    case N_FIELD_DECAY: {
        Field *f = g_ast[n].sym_f;
        int ka = walk_fpr(g_ast[n].a);
        emit_fpr_add_const(ka, f->byte_offset);
        g_fpr_res   = ka;
        g_expr_type = g_ast[n].type;
        break;
    }
    case N_FIELD_DEREF: {
        Field *f = g_ast[n].sym_f;
        int ka = walk_fpr(g_ast[n].a);
        emit_fpr_deref_field(ka, f->type, f->byte_offset);
        if (ISPTR(f->type)) g_fpr_res = ka;
        else                fpr_drop(ka);
        g_expr_type = f->type;
        g_expr_unsigned = f->is_unsigned;
        if (f->type == LT_FN_PTR)
            g_expr_fn_sig = f->fn_sig_id;
        break;
    }
    case N_DOT_ARRAY_DECAY: {
        int k = fpr_addr_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        emit_fpr_add_const(k, (int)g_ast[n].val);
        g_fpr_res        = k;
        g_expr_type      = g_ast[n].type;
        /* -1 for every type this used to accept, and the struct's id for the
         * member arrays it now also accepts. */
        g_expr_struct_id = g_ast[n].struct_id;
        g_expr_unsigned  = 0;
        break;
    }
    case N_DOT_SCALAR: {
        Field synth = *g_ast[n].sym_f;
        synth.byte_offset = (int)g_ast[n].val;
        if (ISPTR(synth.type) && synth.type != LT_FN_PTR) {
            /* data-ptr field: read the STORED (offset,bank) pair in both
             * modes (see emit_fpr_load_field — PHK re-derivation broke
             * soft-stack/heap pointees; stale-carrier was the old "fix"). */
            int k = fpr_alloc();
            emit_fpr_load_field(k, g_ast[n].sym_lc, g_ast[n].sym_gv, &synth);
            g_fpr_res = k;
            g_expr_type      = synth.type;
            g_expr_struct_id = g_ast[n].struct_id;
            g_expr_unsigned  = synth.is_unsigned;
            break;
        }
        if (g_ast[n].sym_lc) emit_load_local_field(g_ast[n].sym_lc, &synth);
        else                 emit_load_global_field(g_ast[n].sym_gv, &synth);
        if (ISPTR(g_ast[n].type)) fpr_in();   /* fn-ptr: bank set both modes */
        break;
    }
    case N_G34_BANK:
        walk_expr(g_ast[n].a);         /* child lands in an FPR, bank correct */
        g_expr_struct_id = g_ast[n].struct_id;
        break;
    case N_AV_DECAY: {
        int k = fpr_load_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        emit_fpr_add_const(k, (int)g_ast[n].val);
        g_fpr_res   = k;
        g_expr_type = g_ast[n].type;
        if (g_ast[n].flags & AF_BASE_LOAD) {
            g_expr_struct_id = g_ast[n].struct_id;   /* full-decay variant */
        } else {
            g_expr_struct_id = -1;                   /* ->structval.leaf variant */
            g_expr_unsigned  = 0;
        }
        break;
    }
    case N_AV_SCALAR: {
        Field *leaf = g_ast[n].sym_f;
        int k = fpr_load_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        emit_fpr_add_const(k, (int)g_ast[n].val);
        emit_fpr_deref_field(k, leaf->type, 0);
        if (ISPTR(leaf->type)) g_fpr_res = k;
        else                   fpr_drop(k);
        g_expr_type      = leaf->type;
        g_expr_struct_id = leaf->struct_id;
        g_expr_unsigned  = 0;
        break;
    }
    case N_ARROW_LOAD_CHAIN: {
        Field *f = g_ast[n].sym_f;
        int k = fpr_load_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        for (int h = 0; h < g_ast[n].n_kids; h++) {
            Field *hop = g_ast_fields[g_ast[n].kid0 + h];
            emit_fpr_deref_field(k, LT_STRUCT_PTR, hop->byte_offset);
        }
        emit_fpr_deref_field(k, f->type, f->byte_offset);
        if (ISPTR(f->type)) g_fpr_res = k;
        else                fpr_drop(k);
        g_expr_type      = f->type;
        g_expr_unsigned  = f->is_unsigned;
        g_expr_struct_id = f->struct_id;
        g_expr_fn_sig = (f->type == LT_FN_PTR) ? f->fn_sig_id : -1;
        break;
    }
    case N_DSTORE: {
        Local  *dlc = g_ast[n].sym_lc;
        Global *dgv = g_ast[n].sym_gv;
        LocalType pt = dlc ? dlc->type : dgv->type;
        LocalType target = DECREF(pt);
        int pre  = (int)g_ast[n].val - 1;
        int post = (int)g_ast[n].val_hi - 1;
        int is_byte = (g_ast[n].flags & AF_IS_BYTE) != 0;
        int is_ptr  = (g_ast[n].flags & AF_IS_PTRSTORE) != 0;
        int kd = fpr_load_sym(dlc, dgv);       /* dest pointer home value */
        if (pre || post) {
            /* `*p++' bumps p by ITS pointee; ptr_stride returns 0 for a
             * struct pointer and the fallback made it one byte (#154). */
            int st  = elem_size_for(pt, dlc ? dlc->struct_id : dgv->struct_id);
            int dir = pre ? pre : post;
            int delta = (dir > 0) ? st : -st;
            if (dgv) {
                emit_fpr_incdec_home_global(kd, dgv, delta, pre ? 1 : 0);
            } else {
                emit_fpr_to_a(kd);
                if (delta > 0) {
                    ir_record_raw(IR_ADD_CONST, (unsigned)(delta), 0, NULL);
                } else {
                    ir_record_raw(IR_SUB_CONST, (unsigned)(-delta), 0, NULL);
                }
                if (pre) emit_fpr_off_from_a(kd);   /* prefix derefs the NEW */
                emit_slot_sta16(dlc, 0);            /* home offset word */
            }
        }
        if (is_ptr) {
            walk_expr(g_ast[n].a);             /* RHS pointer */
            int ks = g_fpr_res;
            if (ks < 0) {
                ks = fpr_alloc();
                fpr_from_walked(ks, g_ast[n].a);
            }
            emit_fpr_deref_store_ptr(kd, ks, 0);
            emit_fpr_mov(kd, ks);              /* result = RHS */
            fpr_drop(ks);
            g_fpr_res        = kd;
            g_expr_type      = target;
            g_expr_struct_id = -1;
            g_expr_unsigned  = 0;
            break;
        }
        if (target == LT_STRUCT) {
            /* A STRUCT LEAF IS COPIED, NOT STORED -- the same rule, and the
             * same sequence, as the N_LV_STORE_E struct arm below: destination
             * address in kd, source ADDRESS in ks, one Y-indexed copy loop.
             * Without it the fall-through would write TWO BYTES of the
             * source's address into the destination, which is apple/fgx#207's
             * shape reached by yet another route.
             *
             * kd IS LEFT AS THE RESULT rather than dropped, for the reason
             * that arm gives: A.7.17 says the value of an assignment is the
             * value stored, and a struct value in this compiler IS its
             * address.  emit_fpr_struct_copy indexes through both FPRs without
             * modifying either, so kd still holds the destination afterwards.
             * Struct values are carrier-carried, so a walk that yields no FPR
             * is materialised from the carrier as the by-value argument path
             * does. */
            int sid = dlc ? dlc->struct_id : dgv->struct_id;
            int nb  = (g_structs[sid].total_size + 1) & ~1;
            int ks  = walk_fpr(g_ast[n].a);
            if (ks < 0) { ks = fpr_alloc(); emit_fpr_from_carrier(ks); }
            emit_fpr_struct_copy(kd, ks, nb);
            fpr_drop(ks);
            g_fpr_res        = kd;
            g_expr_type      = LT_STRUCT;
            g_expr_struct_id = sid;
            g_expr_unsigned  = 0;
            break;
        }
        if (IS_QUAD(target) ||
            (g_ast[n].op != TOK_EQ &&
             llong_opassign_applies(target, g_ast[n].op, g_ast[n].a))) {
            /* A long long pointee, or an op= with a long long right operand:
             * all eight bytes, or the narrower pointee's own width, stored
             * back from the 64-bit result. */
            int du = dlc ? dlc->is_unsigned : dgv->is_unsigned;
            if (g_ast[n].op == TOK_EQ) {
                walk_val(g_ast[n].a);
                emit_to_quad(target);
            } else {
                emit_fpr_deref_field(kd, is_byte ? LT_CHAR : target, 0);
                llong_opassign(n, g_ast[n].op, g_ast[n].a,
                               is_byte ? LT_CHAR : target, du);
            }
            /* A double result is converted to the pointee's own type
             * (A.7.17: "the right operand is converted to the type of the
             * left by the assignment"); a float pointee takes all four
             * bytes. */
            if (g_expr_type == LT_DOUBLE && !IS_QUAD(target))
                emit_from_double(is_byte ? LT_CHAR : target);
            if (IS_QUAD(target))            emit_fpr_deref_store_llong(kd, 0);
            else if (target == LT_LONG || target == LT_FLOAT)
                                            emit_fpr_deref_store_long(kd, 0);
            else if (is_byte)               emit_fpr_deref_store_byte(kd, 0);
            else                            emit_fpr_deref_store_word(kd, 0);
            fpr_drop(kd);
            g_fpr_res        = -1;
            g_expr_type      = (IS_QUAD(target) || target == LT_LONG ||
                                target == LT_FLOAT)
                               ? target : (is_byte ? LT_CHAR : LT_INT);
            g_expr_struct_id = -1;
            g_expr_unsigned  = du;
            break;
        }
        if ((target == LT_LONG || target == LT_FLOAT) && g_ast[n].op != TOK_EQ) {
            /* A 4-byte pointee under op=: read, combine and write all four
             * bytes, the value left in A:_fcc_long_hi (A.7.17). */
            LocalType et = target;
            emit_fpr_deref_field(kd, et, 0);
            g_expr_type = et;
            emit_push_long();
            walk_val(g_ast[n].a);
            if (et == LT_FLOAT) {
                if (g_expr_type == LT_INT || g_expr_type == LT_CHAR) emit_int_to_float();
                else if (g_expr_type == LT_LONG)                      emit_long_to_float();
            } else if (g_expr_type == LT_INT || g_expr_type == LT_CHAR) {
                emit_promote_a_to_long();
            }
            if (g_expr_type != LT_FLOAT) g_expr_type = et;
            emit_stash_rhs();
            emit_pop_long();
            if (g_expr_type != LT_FLOAT) g_expr_type = et;
            emit_compound_op(g_ast[n].op, dlc ? dlc->is_unsigned : dgv->is_unsigned, et);
            emit_fpr_deref_store_long(kd, 0);
            fpr_drop(kd);
            g_fpr_res        = -1;
            g_expr_type      = et;
            g_expr_struct_id = -1;
            g_expr_unsigned  = 0;
            break;
        }
        if (target == LT_LONG || target == LT_FLOAT) {
            /* A 4-byte pointee, plain `='.  The right operand is converted to
             * the pointee's type (A.7.17) and stays in A:_fcc_long_hi as the
             * expression's value. */
            walk_val(g_ast[n].a);
            if (g_expr_type == LT_INT || g_expr_type == LT_CHAR) {
                if (target == LT_FLOAT) emit_int_to_float();
                else                    emit_promote_a_to_long();
            }
            emit_assign_conv(target);
            emit_fpr_deref_store_long(kd, 0);
            fpr_drop(kd);
            g_fpr_res        = -1;
            g_expr_type      = target;
            g_expr_struct_id = -1;
            g_expr_unsigned  = 0;
            break;
        }
        if (g_ast[n].op != TOK_EQ) {
            /* `*p op= rhs` -- read-modify-write on the address ALREADY held in
             * kd, so the pointer's ++/-- above happens exactly once (K&R
             * A.7.17: E1 op= E2 is E1 = E1 op E2 except E1 is evaluated once).
             * Same sequence the uniform walker uses for a compound chain
             * store: old -> stack, RHS -> A, stash, pop old, combine. */
            emit_fpr_deref_field(kd, is_byte ? LT_CHAR : LT_INT, 0);
            emit_push_a();
            walk_val(g_ast[n].a);              /* RHS -> A */
            emit_stash_rhs();
            emit_pop_a();                      /* A = old value */
            /* Pass the LEAF's signedness, not 0: `>>=`, `/=` and `%=` pick a
             * different helper for unsigned operands, and tcsh's Char is an
             * unsigned type. */
            emit_compound_op(g_ast[n].op,
                             promoted_unsigned(is_byte ? LT_CHAR : LT_INT,
                                 dlc ? dlc->is_unsigned : dgv->is_unsigned),
                             LT_INT);
        } else {
            walk_val(g_ast[n].a);              /* RHS -> A */
            emit_assign_conv(is_byte ? LT_CHAR : LT_INT);  /* A.7.17 */
        }
        if (is_byte) emit_fpr_deref_store_byte(kd, 0);
        else         emit_fpr_deref_store_word(kd, 0);
        fpr_drop(kd);
        g_fpr_res        = -1;                 /* A-preserving store */
        g_expr_type      = is_byte ? LT_CHAR : LT_INT;
        g_expr_struct_id = -1;
        g_expr_unsigned  = 0;
        break;
    }
    case N_LV_STORE_E: {
        /* Uniform lvalue store in EXPRESSION context: compute the address once
         * (emit_lvalue_addr; K&R A.7.3 postfix chain), store/RMW by leaf type,
         * and LEAVE the stored value (A / A:_fcc_long_hi / fpr) so the enclosing
         * expression can use it (K&R A.7.17: value == value stored). */
        int head = g_ast[n].a;
        LocalType leaf = g_ast[head].type;
        int is_byte = (leaf == LT_CHAR);
        int is_long = (leaf == LT_LONG || leaf == LT_FLOAT);
        int is_ptr  = ISPTR(leaf);
        if (IS_QUAD(leaf) ||
            (g_ast[n].op != TOK_EQ &&
             llong_opassign_applies(leaf, g_ast[n].op, g_ast[n].c))) {
            /* A long long leaf, or an op= with a long long right operand:
             * the 64-bit value stored back at the leaf's own width. */
            int kd = emit_lvalue_addr(head);
            if (g_ast[n].op == TOK_EQ) {
                walk_val(g_ast[n].c);
                emit_to_quad(leaf);
            } else {
                emit_fpr_deref_field(kd, leaf, 0);
                llong_opassign(n, g_ast[n].op, g_ast[n].c, leaf,
                               g_ast[head].is_unsigned);
            }
            /* A double result is converted to the leaf's own type (A.7.17);
             * a float leaf takes all four bytes. */
            if (g_expr_type == LT_DOUBLE && !IS_QUAD(leaf))
                emit_from_double(leaf);
            if (IS_QUAD(leaf))         emit_fpr_deref_store_llong(kd, 0);
            else if (leaf == LT_LONG || leaf == LT_FLOAT)
                                       emit_fpr_deref_store_long(kd, 0);
            else if (is_byte)          emit_fpr_deref_store_byte(kd, 0);
            else                       emit_fpr_deref_store_word(kd, 0);
            fpr_drop(kd);
            g_fpr_res = -1;
            g_expr_type = (IS_QUAD(leaf) || leaf == LT_LONG ||
                           leaf == LT_FLOAT)
                          ? leaf : (is_byte ? LT_CHAR : LT_INT);
            g_expr_struct_id = -1;
            g_expr_unsigned = g_ast[head].is_unsigned;
            break;
        }
        if (g_ast[n].op == TOK_EQ) {                 /* plain store */
            int kd = emit_lvalue_addr(head);
            if (is_ptr) {
                int ks = walk_fpr(g_ast[n].c);
                emit_fpr_deref_store_ptr(kd, ks, 0);
                emit_fpr_mov(kd, ks);                /* result = RHS pointer */
                fpr_drop(ks);
                g_fpr_res = kd; g_expr_type = leaf;
                g_expr_struct_id = g_ast[head].struct_id; g_expr_unsigned = 0;
            } else if (is_long) {
                walk_val(g_ast[n].c);
                {
                    LocalType rt = g_ast[g_ast[n].c].type;
                    if (rt == LT_DOUBLE) {
                        emit_from_double(leaf);      /* A.6.3, A.6.4 */
                    } else if (leaf == LT_FLOAT) {
                        if (rt == LT_INT || rt == LT_CHAR) emit_int_to_float();
                        else if (rt == LT_LONG)            emit_long_to_float();
                    } else if (rt == LT_INT || rt == LT_CHAR) {
                        emit_promote_a_to_long();
                    } else if (rt == LT_FLOAT)             emit_float_to_long();
                }
                g_expr_type = leaf;
                emit_fpr_deref_store_long(kd, 0);
                fpr_drop(kd);
                g_fpr_res = -1; g_expr_type = leaf;
                g_expr_struct_id = -1; g_expr_unsigned = 0;
            } else if (leaf == LT_STRUCT) {
                /* A STRUCT LEAF IS COPIED, NOT STORED.  Without this arm the
                 * chain fell through to the word store below and wrote TWO
                 * BYTES of the source's address into the member -- silently,
                 * which is apple/fgx#207's shape reached by a different route.
                 * It was unreachable while every deep chain died at the
                 * "struct-value leaf" refusal above; apple/fgx#213's routing
                 * made it reachable, and the miss was found by reading the
                 * emitted code rather than by any test going red.
                 *
                 * K&R A.7.17: "in the simple form, the value of the expression
                 * replaces that of the object referred to by the lvalue", and
                 * it admits operands that "are structures or unions of the
                 * same type".  The OBJECT -- all of it, not its first word.
                 *
                 * Same shape as S_DSTORE_STRUCT_COPY on the statement side:
                 * dest address in kd, source ADDRESS in ks, one Y-indexed copy
                 * loop.  Struct values are carrier-carried, so a walk that
                 * yields no FPR is materialised from the carrier exactly as
                 * the by-value ARGUMENT path does.
                 *
                 * kd IS LEFT AS THE RESULT and not dropped: A.7.17 says the
                 * value of an assignment is the value stored, and a struct
                 * value in this compiler IS its address.  emit_fpr_struct_copy
                 * indexes through both FPRs without modifying either, so kd
                 * still holds the destination when the loop ends. */
                int sid = g_ast[head].struct_id;
                int nb  = (g_structs[sid].total_size + 1) & ~1;
                int ks  = walk_fpr(g_ast[n].c);
                if (ks < 0) { ks = fpr_alloc(); emit_fpr_from_carrier(ks); }
                emit_fpr_struct_copy(kd, ks, nb);
                fpr_drop(ks);
                g_fpr_res = kd; g_expr_type = LT_STRUCT;
                g_expr_struct_id = sid; g_expr_unsigned = 0;
            } else {
                walk_val(g_ast[n].c);
                emit_assign_conv(is_byte ? LT_CHAR : LT_INT);  /* A.7.17 */
                if (is_byte) emit_fpr_deref_store_byte(kd, 0);
                else         emit_fpr_deref_store_word(kd, 0);
                fpr_drop(kd);
                g_fpr_res = -1; g_expr_type = is_byte ? LT_CHAR : LT_INT;
                g_expr_struct_id = -1; g_expr_unsigned = 0;
            }
        } else {                                     /* compound op= */
            int kd = emit_lvalue_addr(head);
            if (is_long) {
                emit_fpr_deref_field(kd, leaf, 0);   /* acc = old (32-bit) */
                g_expr_type = leaf;
                emit_push_long();
                walk_val(g_ast[n].c);
                {
                    LocalType rt = g_ast[g_ast[n].c].type;
                    if (leaf == LT_FLOAT) {
                        if (rt == LT_INT || rt == LT_CHAR) emit_int_to_float();
                        else if (rt == LT_LONG)            emit_long_to_float();
                    } else if (rt == LT_INT || rt == LT_CHAR) {
                        emit_promote_a_to_long();
                    }
                }
                if (g_expr_type != LT_FLOAT) g_expr_type = leaf;
                emit_stash_rhs();
                emit_pop_long();
                if (g_expr_type != LT_FLOAT) g_expr_type = leaf;
                emit_compound_op(g_ast[n].op, 0, leaf);
                emit_fpr_deref_store_long(kd, 0);
                fpr_drop(kd);
                g_fpr_res = -1; g_expr_type = leaf;
                g_expr_struct_id = -1; g_expr_unsigned = 0;
            } else {
                emit_fpr_deref_field(kd, is_byte ? LT_CHAR : LT_INT, 0);
                emit_push_a();
                walk_val(g_ast[n].c);
                /* A POINTER leaf scales its operand (apple/fgx#155).  This is
                 * the EXPRESSION twin of the S_LV_STORE arm in parse_stmt.c,
                 * and it is the arm a statement takes when the chain's base is
                 * a CALL -- `f()->next += 1' is built by the expression layer
                 * and only then wrapped as a statement, so fixing the
                 * statement arm alone left this one moving one byte.
                 * The load above already asks for the offset WORD, so kd is
                 * still the address and the word store leaves the bank. */
                emit_scale_compound_ptr(leaf, g_ast[head].struct_id,
                                        g_ast[n].op);
                emit_stash_rhs();
                emit_pop_a();
                emit_compound_op(g_ast[n].op, 0, LT_INT);
                if (is_byte) emit_fpr_deref_store_byte(kd, 0);
                else         emit_fpr_deref_store_word(kd, 0);
                fpr_drop(kd);
                g_fpr_res = -1;
                /* K&R A.7.17: the value of `E1 op= E2' has the type of E1.
                 * A pointer leaf leaves its OFFSET word in A -- the bank never
                 * moved and was never touched -- so publish the pointer type
                 * rather than int, or an enclosing expression treats the value
                 * as an int-to-pointer conversion and stamps a bank on it. */
                g_expr_type = is_ptr ? leaf : (is_byte ? LT_CHAR : LT_INT);
                g_expr_struct_id = is_ptr ? g_ast[head].struct_id : -1;
                g_expr_unsigned = 0;
            }
        }
        break;
    }
    case N_ADDR_LV_E: {
        /* &chain: the walker's ADDRESS fpr IS the value -- a far pointer whose
         * bank rides through every deref/scaled-add (K&R A.7.4.2). */
        int kd;
        refuse_homed_addr(n);
        kd = emit_lvalue_addr(g_ast[n].a);
        g_fpr_res        = kd;
        g_expr_type      = g_ast[n].type;
        g_expr_struct_id = g_ast[n].struct_id;
        g_expr_unsigned  = 0;
        break;
    }
    case N_LV_LOAD_E: {
        /* chain READ: address via the walker, then deref-load the leaf.
         * emit_fpr_deref_field loads a POINTER leaf as a full far pointer into
         * kd (rides the fpr), a LONG into A:_fcc_long_hi, a scalar into A. */
        LocalType leaf = g_ast[n].type;
        int kd = emit_lvalue_addr(g_ast[n].a);
        emit_fpr_deref_field(kd, leaf, 0);
        if (ISPTR(leaf)) {
            g_fpr_res        = kd;               /* far pointer in kd */
            g_expr_type      = leaf;
            g_expr_struct_id = g_ast[n].struct_id;
        } else {
            fpr_drop(kd);
            g_fpr_res        = -1;               /* A / A:_fcc_long_hi */
            g_expr_type      = leaf;
            g_expr_struct_id = -1;
        }
        g_expr_unsigned = g_ast[n].is_unsigned;
        break;
    }
    case N_LV_INCDEC_E: {
        /* postfix ++/-- of a deref LVALUE `(*p)++`: the ADDRESS of the pointee
         * is p's own value (the deref's operand), in an fpr; RMW the word
         * through it in place (bank preserved).  For a pointer leaf the
         * yielded far pointer is captured by fpr_in. */
        int op        = g_ast[n].a;
        int is_inc    = (g_ast[n].flags & AF_IS_INC) ? 1 : 0;
        int is_prefix = (g_ast[n].flags & AF_RET_OLD) ? 0 : 1;
        LocalType lt  = g_ast[n].type;
        int is_ptr    = ISPTR(lt);
        int kd;
        if (g_ast[op].kind == N_LV_CHAIN)
            kd = emit_lvalue_addr(op);                       /* &arr[i] etc. (chain) */
        else if (g_ast[op].kind == N_DEREF_FAST)
            kd = fpr_load_sym(g_ast[op].sym_lc, NULL);       /* addr = the ptr's value */
        else
            kd = walk_fpr(g_ast[op].a);                      /* N_DEREF_GENERAL operand */
        /* A LONG OR FLOAT LEAF IS A 32-BIT ±1.  The word RMW below reaches
         * only the low half: a long lost its carry and yielded whatever
         * _fcc_long_hi last held (`++s.lw[i]' in value position), and a float
         * had one added to its mantissa bits. */
        if (lt == LT_LONG || lt == LT_FLOAT || IS_QUAD(lt)) {
            fpr_sym_flush(kd);
            emit_wide_incdec_at_fpr(kd, 0, lt, is_inc, !is_prefix);
            fpr_drop(kd);
            g_fpr_res = -1;
            break;
        }
        if (fpr_is_sym(kd)) {                 /* a fixed address: RMW it there */
            emit_incdec_at_sym(kd, (int)g_ast[n].val, is_inc, is_prefix, is_ptr,
                               lt, g_ast[n].struct_id);
            fpr_drop(kd);
            if (is_ptr) fpr_in();
            else        g_fpr_res = -1;
            g_expr_type      = lt;
            g_expr_struct_id = g_ast[n].struct_id;
            g_expr_unsigned  = g_ast[n].is_unsigned;
            break;
        }
        if (is_ptr) {                          /* the result replaces the address */
            emit_ptr_incdec_into_fpr(kd, (int)g_ast[n].val, is_inc, is_prefix);
            g_fpr_res        = kd;
            g_expr_type      = lt;
            g_expr_struct_id = g_ast[n].struct_id;
            g_expr_unsigned  = g_ast[n].is_unsigned;
            break;
        }
        emit_incdec_at_fpr(kd, (int)g_ast[n].val, is_inc, is_prefix, is_ptr,
                           lt, g_ast[n].struct_id);
        fpr_drop(kd);
        if (is_ptr) {
            fpr_in();                          /* A + _fcc_ptr+2 -> fresh fpr */
        } else {
            g_fpr_res = -1;                    /* int scalar in A */
        }
        g_expr_type      = lt;
        g_expr_struct_id = g_ast[n].struct_id;
        g_expr_unsigned  = g_ast[n].is_unsigned;
        break;
    }
    case N_STORE_VAR: {
        walk_expr(g_ast[n].a);                 /* RHS (right-assoc) */
        /* #12: walk_expr has just set g_expr_const_int for this RHS; the store
         * lowerings in emit.c read it to pick the bank. */
        int ks = g_fpr_res;
        Local  *lc = g_ast[n].sym_lc;
        Global *gv = g_ast[n].sym_gv;
        LocalType ht = lc ? lc->type : gv->type;
        if (ISPTR(ht) && ks >= 0) {
            if (lc) {
                emit_fpr_store_ptr_local(ks, lc);   /* structured; promotion */
            } else {
                emit_fpr_store_global_ptr(ks, gv);
            }
            g_fpr_res = ks;                    /* result = RHS, still live */
            break;
        }
        if (ks >= 0) {
            /* pointer RHS into a non-pointer home: offset word semantics */
            emit_fpr_to_a(ks);
            fpr_drop(ks);
            g_fpr_res = -1;
        }
        if (lc != NULL)                emit_store_local(lc);
        else if (gv->type == LT_CHAR)  emit_store_global_char(gv);
        else                           emit_store_global_int(gv);
        if (ks < 0 && ISPTR(g_ast[n].type)) {  /* defensive: contract repair */
            int k = fpr_alloc();
            /* #12: the store's RESULT feeds chained assignment
             * (`a = b = round(x)`); publish the same bank the store used or
             * the outer assignment re-launders it back to bank 0. */
            emit_fpr_from_a(k, BANK_OF_RHS(g_expr_type, g_expr_const_int));
            g_fpr_res = k;
        }
        break;
    }
    case N_COMPOUND_VAR: {
        Local  *lc = g_ast[n].sym_lc;
        Global *gv = g_ast[n].sym_gv;
        TokKind op = g_ast[n].op;
        LocalType ht = lc ? lc->type : gv->type;
        if (ISPTR(ht) && (op == TOK_PLUSEQ || op == TOK_MINUSEQ)) {
            int k = fpr_load_sym(lc, gv);
            walk_val(g_ast[n].a);              /* RHS elements -> A */
            emit_scale_compound_ptr(ht, lc ? lc->struct_id : gv->struct_id, op);
            if (op == TOK_PLUSEQ) emit_fpr_add_a(k);
            else                  emit_fpr_sub_a(k);
            g_expr_type = ht;                  /* store reads RHS type: ptr */
            if (lc) {
                emit_fpr_store_ptr_local(k, lc);
            } else {
                emit_fpr_store_global_ptr(k, gv);
            }
            g_fpr_res        = k;
            g_expr_type      = ht;
            g_expr_struct_id = -1;
            g_expr_unsigned  = lc ? lc->is_unsigned : gv->is_unsigned;
            break;
        }
        if (lc != NULL) emit_load_local(lc);
        else            emit_load_global(gv);
        {
        /* A-1: LHS signedness at load, after promotion (A.6.1). */
        int lhs_u = promoted_unsigned(ht, g_expr_unsigned);
        if (llong_opassign_applies(ht, op, g_ast[n].a)) {
            llong_opassign(n, op, g_ast[n].a, ht, lhs_u);
        } else if (ht == LT_LONG || ht == LT_FLOAT) {
            /* 4-byte LHS: the RHS walk clobbers _fcc_long_hi, so save BOTH
             * words; promote an int/char RHS before the 32-bit op.  A lone
             * emit_push_a() here zeroed the high word of `now += 60` (H1
             * ls year-branch bug).  Mirrors the LONG_ARRAY op= arm. */
            emit_push_long();
            walk_val(g_ast[n].a);
            {
                LocalType rt = g_ast[g_ast[n].a].type;
                if (ht == LT_FLOAT) {
                    if (rt == LT_INT || rt == LT_CHAR) emit_int_to_float();
                    else if (rt == LT_LONG)            emit_long_to_float();
                } else {
                    if (rt == LT_INT || rt == LT_CHAR) emit_promote_a_to_long();
                }
            }
            if (g_expr_type != LT_FLOAT) g_expr_type = ht;
            emit_stash_rhs();
            emit_pop_long();
            if (g_expr_type != LT_FLOAT) g_expr_type = ht;
            emit_compound_op(op, lhs_u, ht);
        } else {
            emit_push_a();
            walk_val(g_ast[n].a);
            emit_scale_compound_ptr(ht, lc ? lc->struct_id : gv->struct_id, op);
            emit_stash_rhs();
            emit_pop_a();
            emit_compound_op(op, lhs_u, LT_INT);
        }
        }
        if (ISPTR(ht))
            g_expr_type = ht;
        if (lc != NULL)                emit_store_local(lc);
        else if (gv->type == LT_CHAR)  emit_store_global_char(gv);
        else                           emit_store_global_int(gv);
        g_expr_type      = ht;
        g_expr_struct_id = -1;
        g_expr_unsigned  = lc ? lc->is_unsigned : gv->is_unsigned;
        if (ISPTR(g_ast[n].type)) fpr_in();    /* exotic op on a ptr home */
        break;
    }
    case N_STORE_DOTFIELD: {
        Field synth = *g_ast[n].sym_f;
        synth.byte_offset = (int)g_ast[n].val;
        walk_expr(g_ast[n].a);         /* RHS -> A (right-assoc) */
        int ks = g_fpr_res;
        if (ks >= 0)
            emit_fpr_to_carrier(ks);   /* legacy field store consumes A+carrier */
        if (g_ast[n].sym_lc) emit_store_local_field(g_ast[n].sym_lc, &synth);
        else                 emit_store_global_field(g_ast[n].sym_gv, &synth);
        g_expr_type      = g_ast[n].sym_f->type;
        g_expr_struct_id = -1;
        g_expr_unsigned  = 0;
        if (ks >= 0) g_fpr_res = ks;   /* result = RHS, still live */
        else if (ISPTR(g_ast[n].type)) {
            int k = fpr_alloc();
            /* #12: the store's RESULT feeds chained assignment
             * (`a = b = round(x)`); publish the same bank the store used or
             * the outer assignment re-launders it back to bank 0. */
            emit_fpr_from_a(k, BANK_OF_RHS(g_expr_type, g_expr_const_int));
            g_fpr_res = k;
        }
        break;
    }
    case N_STORE_PTRARR_ELEM: {
        Field *af = g_ast[n].sym_f;
        int kd = fpr_load_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        emit_fpr_add_const(kd, af->byte_offset);
        walk_val(g_ast[n].a);          /* index -> A */
        ir_emitf("                ASL\n");        /* idx*2 */
        ir_emitf("                ASL\n");        /* idx*4 (4-byte ptr elems) */
        emit_fpr_add_a(kd);
        walk_expr(g_ast[n].c);         /* RHS ptr */
        {
        int ks = g_fpr_res;
        if (ks < 0) {
            ks = fpr_alloc();
            fpr_from_walked(ks, g_ast[n].c);
        }
        emit_fpr_deref_store_ptr(kd, ks, 0);
        emit_fpr_mov(kd, ks);
        fpr_drop(ks);
        }
        g_fpr_res        = kd;
        g_expr_type      = DECREF(af->type);
        g_expr_struct_id = -1;
        g_expr_unsigned  = 0;
        break;
    }
    case N_STORE_MEMBER: {
        Field *f = g_ast[n].sym_f;
        int kd = fpr_load_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        walk_expr(g_ast[n].a);         /* RHS (right-assoc) */
        if (ISPTR(f->type)) {
            int ks = g_fpr_res;
            if (ks < 0) {
                ks = fpr_alloc();
                fpr_from_walked(ks, g_ast[n].a);
            }
            emit_fpr_deref_store_ptr(kd, ks, f->byte_offset);
            emit_fpr_mov(kd, ks);
            fpr_drop(ks);
            g_fpr_res = kd;            /* result = RHS */
        } else if (f->type == LT_LONG || f->type == LT_FLOAT) {
            if (f->type == LT_FLOAT &&
                (g_expr_type == LT_INT || g_expr_type == LT_CHAR)) {
                emit_itof_rt();
            } else if (g_expr_type == LT_INT || g_expr_type == LT_CHAR) {
                emit_promote_a_to_long();   /* sign/zero-extend int RHS→long */
            }
            emit_assign_conv(f->type);  /* A.7.17: long<->float */
            emit_fpr_deref_store_long(kd, f->byte_offset);
            fpr_drop(kd);
        } else if (f->type == LT_CHAR) {
            fpr_collapse();
            emit_assign_conv(LT_CHAR);  /* A.7.17: a float truncates */
            emit_fpr_deref_store_byte(kd, f->byte_offset);
            fpr_drop(kd);
        } else {
            fpr_collapse();
            emit_assign_conv(LT_INT);   /* A.7.17: a float truncates */
            emit_fpr_deref_store_word(kd, f->byte_offset);
            fpr_drop(kd);
        }
        g_expr_type      = f->type;
        g_expr_struct_id = -1;
        g_expr_unsigned  = 0;
        break;
    }
    case N_STORE_SARR_MEMBER: {
        /* IDENT[i].field = rhs — base is the element ADDRESS (&arr[0] +
         * i*es), unlike N_STORE_MEMBER's pointer-deref base.  Store tail is
         * otherwise identical (value-yielding, so chaining works). */
        Field *f = g_ast[n].sym_f;
        int kd = fpr_addr_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);  /* &arr[0] */
        walk_val(g_ast[n].a);                  /* element index -> A */
        emit_index_scale(g_ast[n].val);        /* A *= elem size */
        emit_fpr_add_a(kd);                    /* kd = &arr[i] */
        walk_expr(g_ast[n].b);                 /* RHS (right-assoc) */
        if (ISPTR(f->type)) {
            int ks = g_fpr_res;
            if (ks < 0) {
                ks = fpr_alloc();
                fpr_from_walked(ks, g_ast[n].b);
            }
            emit_fpr_deref_store_ptr(kd, ks, f->byte_offset);
            emit_fpr_mov(kd, ks);
            fpr_drop(ks);
            g_fpr_res = kd;
        } else if (f->type == LT_LONG || f->type == LT_FLOAT) {
            if (f->type == LT_FLOAT &&
                (g_expr_type == LT_INT || g_expr_type == LT_CHAR)) {
                emit_itof_rt();
            } else if (g_expr_type == LT_INT || g_expr_type == LT_CHAR) {
                emit_promote_a_to_long();
            }
            emit_assign_conv(f->type);  /* A.7.17: long<->float */
            emit_fpr_deref_store_long(kd, f->byte_offset);
            fpr_drop(kd);
        } else if (f->type == LT_CHAR) {
            fpr_collapse();
            emit_assign_conv(LT_CHAR);  /* A.7.17: a float truncates */
            emit_fpr_deref_store_byte(kd, f->byte_offset);
            fpr_drop(kd);
        } else {
            fpr_collapse();
            emit_assign_conv(LT_INT);   /* A.7.17: a float truncates */
            emit_fpr_deref_store_word(kd, f->byte_offset);
            fpr_drop(kd);
        }
        g_expr_type      = f->type;
        g_expr_struct_id = -1;
        g_expr_unsigned  = 0;
        break;
    }
    case N_STORE_ARR_ELEM: {
        int is_byte = (g_ast[n].flags & AF_IS_BYTE) != 0;
        int kd;
        if (g_ast[n].flags & AF_EL_PTR)
            kd = fpr_load_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        else
            kd = fpr_addr_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        walk_val(g_ast[n].a);          /* index -> A */
        if (!is_byte) ir_emitf("                ASL\n");
        emit_fpr_add_a(kd);
        walk_val(g_ast[n].c);          /* RHS -> A (right-assoc) */
        emit_assign_conv(is_byte ? LT_CHAR : LT_INT);   /* A.7.17 */
        if (is_byte) emit_fpr_deref_store_byte(kd, 0);
        else         emit_fpr_deref_store_word(kd, 0);
        fpr_drop(kd);
        g_expr_type      = is_byte ? LT_CHAR : LT_INT;
        g_expr_struct_id = -1;
        g_expr_unsigned  = 0;
        break;
    }
    case N_POSTINC_MEMBER:
        if (g_ast[n].sym_f->type == LT_LONG ||
            g_ast[n].sym_f->type == LT_FLOAT || IS_QUAD(g_ast[n].sym_f->type))
            emit_wide_member_incdec(g_ast[n].sym_lc, g_ast[n].sym_gv,
                                    g_ast[n].sym_f->byte_offset,
                                    g_ast[n].sym_f->type,
                                    (g_ast[n].flags & AF_IS_INC) ? 1 : 0,
                                    /*return_old=*/1);   /* postfix -> OLD */
        else
            emit_member_incdec(g_ast[n].sym_lc, g_ast[n].sym_gv, g_ast[n].sym_f,
                               (g_ast[n].flags & AF_IS_INC) ? 1 : 0,
                               /*is_prefix=*/0);
        if (ISPTR(g_ast[n].type)) fpr_in();
        break;
    case N_POSTINC_GLOBAL: {
        Global *gv = g_ast[n].sym_gv;
        if (IS_QUAD(gv->type)) {
            emit_llong_incdec(NULL, gv, (g_ast[n].flags & AF_IS_INC) != 0, 1);
            g_fpr_res = -1;
            break;
        }
        if (gv->type == LT_FLOAT) {
            emit_float_var_incdec(NULL, gv, (g_ast[n].flags & AF_IS_INC) != 0,
                                  /*return_old=*/1);
            g_fpr_res = -1;
            break;
        }
        if (ISPTR(gv->type)) {
            int k = fpr_alloc();
            emit_fpr_load_global_ptr(k, gv);   /* k = OLD */
            emit_fpr_incdec_home_global(k, gv,
                (g_ast[n].flags & AF_IS_INC) ? (int)g_ast[n].val
                                             : -(int)g_ast[n].val,
                /*update_fpr=*/0);
            g_fpr_res   = k;
            g_expr_type = gv->type;
            break;
        }
        if (gv->type == LT_LONG) {          /* postfix ++/-- yields the OLD value */
            emit_long_incdec_global(gv, (g_ast[n].flags & AF_IS_INC) ? 1 : 0,
                                    /*return_old=*/1);
            g_expr_type = gv->type;
            break;
        }
        emit_load_global(gv);
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
        if (g_ast[n].flags & AF_IS_INC) {
            ir_record_raw(IR_ADD_CONST, (unsigned)((int)g_ast[n].val), 0, NULL);
        } else {
            ir_record_raw(IR_SUB_CONST, (unsigned)((int)g_ast[n].val), 0, NULL);
        }
        if (gv->type == LT_CHAR) {
            emit_store_global_char(gv);
        } else {
            emit_store_global_int(gv);
        }
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
        g_expr_type = gv->type;
        break;
    }
    default:
        die(g_ast[n].line, g_ast[n].col, "fcc-ast: walker: unhandled node kind");
    }
#ifdef FCC_AST_CHECK
    /* Glue nodes (address-in-A intermediates) carry a build-routing type; the
     * runtime flag at that point is an index-expression leftover the original
     * parser never set either — exempt. */
    if (g_expr_type != g_ast[n].type &&
        g_ast[n].kind != N_ELEM_ADDR) {
        char astbuf[96];
        snprintf(astbuf, sizeof astbuf,
                 "fcc-ast: type mismatch kind=%d built=%d emitted=%d",
                 (int)g_ast[n].kind, (int)g_ast[n].type, (int)g_expr_type);
        die(g_ast[n].line, g_ast[n].col, astbuf);
    }
    /* FPR contract: a pointer-typed (or address-glue) node must have its
     * result in an FPR; anything else must not. */
    {
        int want_fpr = (ISPTR(g_ast[n].type) || g_ast[n].kind == N_ELEM_ADDR) &&
                       !(g_ast[n].flags & AF_STMT_DISCARD);
        if (want_fpr != (g_fpr_res >= 0)) {
            char fprbuf[96];
            snprintf(fprbuf, sizeof fprbuf,
                     "fcc-fpr: contract kind=%d type=%d res=%d",
                     (int)g_ast[n].kind, (int)g_ast[n].type, g_fpr_res);
            die(g_ast[n].line, g_ast[n].col, fprbuf);
        }
    }
#endif
}

/* External entry: statement code (parse_stmt.c) and the four expression
 * entry points consume the LEGACY carrier convention until P3-2.3 —
 * bridge a pointer result out of its FPR (A = offset, _fcc_ptr+2 = bank)
 * and verify the walk left no leaked registers. */
void
walk_expr_root(int n)
{
    walk_expr(n);
    if (g_fpr_res >= 0) {
        emit_fpr_to_carrier(g_fpr_res);
        fpr_drop(g_fpr_res);
        g_fpr_res = -1;
    }
    if (fpr_live() != 0)
        die(g_ast[n].line, g_ast[n].col,
            "fcc-fpr: leaked expression registers");
}

/* Expression node in STATEMENT context: the value is discarded, so a
 * pointer result is DROPPED, never bridged to the carrier.  (The bridge
 * was dead code walk_expr_root emitted for every discarded ptr-valued
 * statement since 2.2; the peephole could only prove it dead when a
 * following fn-ptr dispatch overwrote _fcc_ptr+2 — P3-2.5b's FPR
 * dispatch removed that overwrite and exposed the waste.) */
void
walk_expr_stmt(int n)
{
    int saved = g_discard_node;
    g_discard_node = n;
    walk_expr(n);
    g_discard_node = saved;
    if (g_fpr_res >= 0)
        fpr_drop(g_fpr_res);
    if (fpr_live() != 0)
        die(g_ast[n].line, g_ast[n].col,
            "fcc-fpr: leaked expression registers");
}



/* --- end Increment 3a foundation ----------------------------------------- */


/* Scale the index in A by a pointer's element stride for pointer +/- arithmetic.
 * Thin wrapper over emit_index_scale (the single source of truth: ASL for pow2,
 * shift-add for small non-pow2, _fcc_mul16 otherwise).  stride 0/1 => no scaling. */
static void
emit_scale_index_by(int stride)
{
    emit_index_scale((unsigned)stride);
}


/* True if g_cur begins a type-name (for sizeof(...)/casts): a base-type
 * keyword, a type modifier (unsigned/signed/short/const/...), or a typedef
 * name.  Note 'long' is a keyword token; 'short'/'unsigned' are modifier
 * idents — both must be accepted so sizeof(long) / sizeof(unsigned short)
 * are recognised as types rather than falling through to sizeof(IDENT). */
int
cur_begins_type(void)
{
    return g_cur.kind == TOK_INT_KW    || g_cur.kind == TOK_CHAR_KW  ||
           g_cur.kind == TOK_VOID_KW   || g_cur.kind == TOK_LONG_KW  ||
           g_cur.kind == TOK_FLOAT_KW  || g_cur.kind == TOK_STRUCT_KW||
           g_cur.kind == TOK_UNION_KW  || g_cur.kind == TOK_ENUM_KW   ||
           (g_cur.kind == TOK_IDENT &&
            (typedefs_lookup(g_cur.id_ptr, g_cur.id_len) >= 0 ||
             is_type_modifier_ident(g_cur.id_ptr, g_cur.id_len)));
}

/* Positioned at a type-name inside sizeof(...): parse  type [*]... [ '[' n ']' ]
 * and return its size in bytes.  Consumes the type (and any array suffix) but
 * NOT the closing ')'.  Shared by the runtime sizeof path and the constant-
 * expression evaluator so both agree on every type. */
long
sizeof_type_value(void)
{
    TypeSpec t = parse_type_spec();
    int is_ptr = 0;
    while (g_cur.kind == TOK_STAR) { is_ptr = 1; next_tok(); }
    if (g_cur.kind == TOK_LBRACKET) {
        next_tok();
        if (g_cur.kind != TOK_INT_LIT)
            die(g_cur.line, g_cur.col, "expected array size");
        int n = (int)g_cur.value;
        next_tok();
        expect(TOK_RBRACKET, "']'");
        if (t.base == LT_STRUCT && !is_ptr)
            return (long)(((g_structs[t.struct_id].total_size + 1) & ~1) * n);
        if (is_ptr)                                  return 4L * n;
        if (t.base == LT_CHAR)                       return (long)n;
        if (t.base == LT_INT)                        return 2L * n;
        if (t.base == LT_LONG || t.base == LT_FLOAT) return 4L * n;
        if (IS_QUAD(t.base))                         return 8L * n;
        die(g_cur.line, g_cur.col, "bad sizeof type");
        return 0;   /* unreachable */
    }
    if (is_ptr) return 4;                       /* 24-bit long ptr = 4 B */
    if (t.base == LT_STRUCT) {
        if (g_structs[t.struct_id].is_forward)
            die(g_cur.line, g_cur.col, "sizeof of incomplete struct");
        return (long)((g_structs[t.struct_id].total_size + 1) & ~1);
    }
    if (t.base == LT_VOID)
        die(g_cur.line, g_cur.col, "cannot size 'void'");
    return (long)type_size_bytes(t.base, 1);
}

long
parse_const_atom(void)
{
    if (g_cur.kind == TOK_LPAREN) {
        next_tok();
        if (cur_begins_type()) {
            /* Cast in a constant initializer: `(char *)0`, `(char *)1`, `(int)N`
             * — curses.c's cursor-shape sentinels `char *CQ = (char *)0;` ...
             * `(char *)4`.  Consume the type + pointer stars + ')', then the
             * value is the casted constant (casting to a pointer or a narrower
             * int leaves the stored bit pattern unchanged here). */
            parse_type_spec();
            while (g_cur.kind == TOK_STAR) next_tok();
            expect(TOK_RPAREN, "')' in cast");
            /* parse_const_UNARY, not _atom: the casted operand may carry a
             * unary op -- `(unsigned int)-1`, which is joe config.h's
             * MAXINT = ((((unsigned int)-1)/2)-1) in a static initializer.
             * (The fold is signed `long`; an unsigned cast does not widen the
             * value here, which is fine for a sentinel like MAXINT but is a
             * known limitation for a static init that needs the unsigned range.) */
            return parse_const_unary();
        }
        long v = parse_const_bin(0);
        if (g_cur.kind != TOK_RPAREN)
            die(g_cur.line, g_cur.col, "expected ')' in constant expression");
        next_tok();
        return v;
    }
    if (g_cur.kind == TOK_INT_LIT || g_cur.kind == TOK_CHAR_LIT) {
        long v;
        if (g_cur.kind == TOK_INT_LIT && g_cur.is_llong)
            v = (long)(((unsigned long)(g_cur.value3 & 0xFFFF) << 48) |
                       ((unsigned long)(g_cur.value2 & 0xFFFF) << 32) |
                       ((unsigned long)(g_cur.value_hi & 0xFFFF) << 16) |
                       (unsigned long)(g_cur.value & 0xFFFF));
        else if (g_cur.is_long)
            v = ((long)(g_cur.value_hi & 0xFFFF) << 16) | (g_cur.value & 0xFFFF);
        else
            v = (long)(short)g_cur.value;   /* sign-extend 16-bit int/char */
        next_tok();
        return v;
    }
    /* G48: enum constant as a constant-expression atom — compile-time int.
     * Lets enum names appear in array dims, case labels, and struct-array
     * field initializers (general improvement, used by stevie's param table). */
    if (g_cur.kind == TOK_IDENT) {
        int eidx = enum_consts_lookup(g_cur.id_ptr, g_cur.id_len);
        if (eidx >= 0) {
            long v = (long)(short)g_enum_consts[eidx].value;
            next_tok();
            return v;
        }
    }
    die(g_cur.line, g_cur.col, "expected integer constant in initializer");
    return 0;   /* unreachable */
}

long
parse_const_unary(void)
{
    if (g_cur.kind == TOK_MINUS) { next_tok(); return -parse_const_unary(); }
    if (g_cur.kind == TOK_PLUS)  { next_tok(); return  parse_const_unary(); }
    if (g_cur.kind == TOK_TILDE) { next_tok(); return ~parse_const_unary(); }
    if (g_cur.kind == TOK_BANG)  { next_tok(); return !parse_const_unary(); }
    /* G49: sizeof as a constant-expression atom — a compile-time int.  Lets
     * sizeof appear in array dimensions / initializers.  Shares the runtime
     * operand parser so every form is accepted: sizeof(type), sizeof(ident),
     * sizeof *ptr, sizeof arr, sizeof(a[0]), sizeof(v.field) — e.g. tcsh's
     * `int nbfunc = sizeof bfunc / sizeof *bfunc;` and
     * `Char orhsb[sizeof(rhsb) / sizeof(Char)];`. */
    if (g_cur.kind == TOK_SIZEOF_KW) {
        next_tok();
        return (long)sizeof_operand_size();
    }
    return parse_const_atom();
}

int
parse_const_prec(int kind)
{
    /* Full C precedence ladder.  The relational, equality and logical rungs
     * were missing, which made the standard K&R compile-time assertion
     * `char _a[(EXPR) ? 1 : -1];` unparseable -- fcc rejected it at the `==`.
     * FGX needs that idiom to pin on-disk struct layouts at compile time (the
     * 2.11BSD filesystem work), so the ladder is completed rather than worked
     * around.  Renumbered upward to make room; parse_const_bin only ever
     * compares these relatively, so the absolute values do not matter. */
    switch (kind) {
        case TOK_STAR: case TOK_SLASH: case TOK_PERCENT: return 10;
        case TOK_PLUS: case TOK_MINUS:                   return 9;
        case TOK_LSHIFT: case TOK_RSHIFT:                return 8;
        case TOK_LT: case TOK_GT:
        case TOK_LE: case TOK_GE:                        return 7;
        case TOK_EQEQ: case TOK_NE:                      return 6;
        case TOK_AMP:                                    return 5;
        case TOK_CARET:                                  return 4;
        case TOK_PIPE:                                   return 3;
        case TOK_AMPAMP:                                 return 2;
        case TOK_PIPEPIPE:                               return 1;
        default:                                         return -1;
    }
}

long
parse_const_bin(int min_prec)
{
    long lhs = parse_const_unary();
    for (;;) {
        int prec = parse_const_prec(g_cur.kind);
        if (prec < 0 || prec < min_prec) break;
        int op = g_cur.kind;
        next_tok();
        long rhs = parse_const_bin(prec + 1);   /* left-assoc */
        switch (op) {
            case TOK_STAR:    lhs = lhs * rhs; break;
            case TOK_SLASH:   lhs = rhs ? lhs / rhs : 0; break;
            case TOK_PERCENT: lhs = rhs ? lhs % rhs : 0; break;
            case TOK_PLUS:    lhs = lhs + rhs; break;
            case TOK_MINUS:   lhs = lhs - rhs; break;
            case TOK_LSHIFT:  lhs = lhs << rhs; break;
            case TOK_RSHIFT:  lhs = lhs >> rhs; break;
            case TOK_AMP:     lhs = lhs & rhs; break;
            case TOK_CARET:   lhs = lhs ^ rhs; break;
            case TOK_PIPE:    lhs = lhs | rhs; break;
            case TOK_LT:      lhs = (lhs <  rhs); break;
            case TOK_GT:      lhs = (lhs >  rhs); break;
            case TOK_LE:      lhs = (lhs <= rhs); break;
            case TOK_GE:      lhs = (lhs >= rhs); break;
            case TOK_EQEQ:    lhs = (lhs == rhs); break;
            case TOK_NE:      lhs = (lhs != rhs); break;
            /* Both sides are already evaluated: a constant expression has no
             * side effects, so not short-circuiting is unobservable. */
            case TOK_AMPAMP:  lhs = (lhs && rhs); break;
            case TOK_PIPEPIPE:lhs = (lhs || rhs); break;
        }
    }
    /* The conditional operator binds looser than every binary rung, so it is
     * handled once the loop is done and only at top level -- a recursive
     * sub-parse (min_prec > 0) must leave the `?` for its caller.  Both arms
     * recurse at 0: the true arm because C makes it a full expression
     * (`a ? b ? c : d : e`), the false arm because `?:` is right-associative
     * (`a ? b : c ? d : e`). */
    if (min_prec == 0 && g_cur.kind == TOK_QMARK) {
        next_tok();
        long then_v = parse_const_bin(0);
        expect(TOK_COLON, "':' in constant conditional");
        long else_v = parse_const_bin(0);
        lhs = lhs ? then_v : else_v;
    }
    return lhs;
}

/* --- Increment 3a THE FLIP -------------------------------------------------
 * The four expression entry points build a per-expression AST and walk it
 * through the existing emit helpers.  (The historical parse-and-emit grammar
 * and its FCC_OLD_EXPR fallback were deleted at P3-2.0 — the old-vs-new net
 * is now the binary-vs-binary differential harness.)  Pool reset per entry
 * is safe: no caller holds node references across an entry (statement arms
 * emit between calls). */

void
ast_reset(void)
{
    if (g_n_ast > g_ast_peak) g_ast_peak = g_n_ast;   /* T2-0 */
    g_n_ast = 0;
    g_n_ast_kids = 0;
    g_n_ast_fields = 0;
    g_fpr_res = -1;
    fpr_reset();
}

/* Statement builders (parse_stmt.c, Increment 3b) build expression subtrees
 * through these non-static entries. */
int
ast_build_assign(void)
{
    return build_assign();
}

int
ast_build_comma(void)
{
    return build_comma();
}

int
ast_build_unary(void)
{
    return build_unary();
}

void
ast_build_call_args(int *kid0, int *n_kids)
{
    build_call_args(kid0, n_kids);
}

void
parse_expr(void)
{
    ast_reset();
    walk_expr_root(build_assign());
}

void
parse_comma(void)
{
    ast_reset();
    walk_expr_root(build_comma());
}

void
parse_assign(void)
{
    ast_reset();
    walk_expr_root(build_assign());
}

void
parse_unary(void)
{
    ast_reset();
    walk_expr_root(build_unary());
}
