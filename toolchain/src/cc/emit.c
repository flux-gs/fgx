#include "fcc.h"
#include <ctype.h>
#include <stdarg.h>   /* P3-5 I4: emit_mac_export's printf-style label */



/* Forward decl: the single-source-of-truth deref-result type helper lives next
 * to its emit_deref_result_via_fcc_ptr sibling far below, but the *p++ record
 * stub (emit_deref_postinc_local) up here needs it for faithful pointee width.
 * Increment 3a: exported (non-static) so the AST builder can type deref nodes. */
tword deref_result_expr_type(tword result);

int
new_label(void)
{
    return g_label_n++;
}

void
emit_file_header(void)
{
    ir_emitf(";---------------------------------------\n");
    ir_emitf("; fcc 0.0 \xe2\x80\x94 generated from %s\n", g_input_path);
    ir_emitf(";---------------------------------------\n");
    ir_emitf("\n");
    ir_emitf("                MX      %%00\n");
}

/* --libso: a block static has no fixed address, so a path that names its
 * label cannot reach it.  Every such path calls this first; a shape that
 * still arrives here needs routing through the lvalue walker, whose address
 * comes from emit_fpr_addr_global. */
void
refuse_block_static(Global *g, const char *path)
{
    if (g && is_block_static(g)) {
        char msg[200];
        snprintf(msg, sizeof msg, "block static '%s' reached %s, which "
                 "addresses it by label; route it through the lvalue walker",
                 gname(g), path);
        die(0, 0, msg);
    }
}

/* --libso: an __asm line is emitted verbatim, so one that names a block
 * static's label would address the shared template, not the process's
 * block.  Refuse it (a word match on each block static's label). */
void
refuse_block_static_in_asm(const char *t, int tl, int line, int col)
{
    for (int i = 0; i < g_n_globals; i++) {
        Global *g = &g_globals[i];
        const char *nm, *p;
        int nl;
        if (!is_block_static(g)) continue;
        nm = gname(g); nl = (int)strlen(nm);
        for (p = t; p + nl <= t + tl; p++) {
            if (memcmp(p, nm, (size_t)nl) != 0) continue;
            if ((p > t && (isalnum((unsigned char)p[-1]) || p[-1] == '_')) ||
                (p + nl < t + tl &&
                 (isalnum((unsigned char)p[nl]) || p[nl] == '_')))
                continue;
            {
                char msg[200];
                snprintf(msg, sizeof msg, "block static '%s' is named in an "
                         "__asm line; its address is per-process", nm);
                die(line, col, msg);
            }
        }
    }
}

const char *
gname(Global *g)
{
    if (g->is_static) {
        snprintf(g_gname_buf, sizeof g_gname_buf, "%s_%s",
                 g_tu_prefix, g->name);
        return g_gname_buf;
    }
    return g->name;
}

const char *fpr_name(int k);          /* FPR section (below); exported (T5-C cast funnel) */

const char *
fname(Func *fn)
{
    if (fn->is_static) {
        snprintf(g_fname_buf, sizeof g_fname_buf, "%s_%s",
                 g_tu_prefix, fn->name);
        return g_fname_buf;
    }
    return fn->name;
}

/*------------------------------------------------------------------------
 * P3-5 I4: THE reloc-macro funnel.  Every listing-significant FGX2_* row
 * fcc emits is formatted by exactly one of these three, keyed by construct
 * (far call / cross-segment long pointer / export).  New pointer constructs
 * MUST route through them — the by-construction rule.  The historic
 * alternative (a fresh fprintf per construct) is the accretion bug class:
 * N-D array partial-decay PHK/PHB, struct fn-ptr field promote-drift,
 * `char *field = &global` all shipped because a new construct's emission
 * site didn't exist yet.  Line POSITIONING (label column / continuation
 * indent) stays at the call site; the funnel owns the macro text, so the
 * macro's shape, arg order, and any future counting hook (P3-5 I3) have
 * one home.
 *
 * emit_mac_longptr: 4-byte cross-segment pointer in the DATA stream.
 *   `tag` is documentary (fgx_ld ignores it; conventions: _Fa=&function,
 *   _Sa/_Sg=string-pool, _Ga/_Spg=&global); `tgt_seg` is fgx_ld's
 *   compile-time guess (resolution is global — see fgx_ld slice 4.5).
 * emit_mac_farcall: cross-bank user/libc call in the CODE stream (IR).
 * emit_mac_export: zero-byte export marker; to_data selects the stream.
 *------------------------------------------------------------------------*/
/* emit_mac_kfarptr: a 4-byte function pointer in a statically linked KERNEL
 * bank -- far or tty -- whose runtime bank is not known at assembly
 * (apple/fgx#88).
 *
 * FGX2_LONG_PTR is wrong there and wrong SILENTLY: its offset is resolved by
 * fgx_ld and its bank byte written by the FGX2 loader, and a kernel bank is a
 * Merlin32 link that goes through neither, so every entry stays four zero
 * bytes.  A vector of them dispatches to $00:FFFF.
 *
 * The offset needs no linker: the image is ONE Merlin invocation, so a plain
 * `DA name` resolves -- the same reason LIBC_DATA_PTR can do it for a
 * same-segment &global.  The bank byte is written once at image init by
 * Far_BankInit or Tty_BankInit, from the table tools/gen_mod_bankpatch.py
 * builds by scanning the listing FOR THIS MACRO NAME, and every indirect call
 * reads it (see emit_call_indirect). */
static void
emit_mac_kfarptr(const char *tag, const char *name_fmt, ...)
{
    char name[128];
    va_list ap;
    va_start(ap, name_fmt);
    vsnprintf(name, sizeof name, name_fmt, ap);
    va_end(ap);
    fprintf(g_data_out, "KFAR_FN_PTR %s;%s\n", tag, name);
}

/* MOD_FN_PTR -- the same four bytes as KFAR_FN_PTR, under a DIFFERENT macro
 * name, and the difference is the whole point.
 *
 * An FGXM module is one Merlin invocation like a kernel bank, so the OFFSET
 * still needs no linker, and its bank byte is written once at init the same
 * way -- PHK inside mod_init yields the module's bank, and _Mod_StampFnPtrs
 * writes it into every cell tools/gen_mod_bankpatch.py finds BY THIS MACRO
 * NAME.
 *
 * Two macro names rather than one, because different code stamps each: a
 * module stamps MOD_FN_PTR from mod_init, a kernel bank stamps KFAR_FN_PTR
 * from its bank init, and a listing scan has only the name to tell a cell that
 * one image's table must list from one that belongs to another. */
static void
emit_mac_modfnptr(const char *tag, const char *name_fmt, ...)
{
    char name[128];
    va_list ap;
    va_start(ap, name_fmt);
    vsnprintf(name, sizeof name, name_fmt, ap);
    va_end(ap);
    fprintf(g_data_out, "MOD_FN_PTR %s;%s\n", tag, name);
}

static void
emit_mac_longptr(const char *tag, int tgt_seg, const char *name_fmt, ...)
{
    char name[128];   /* labels cap at prefix(27)+'_'+name(31); 128 is ample */
    va_list ap;
    va_start(ap, name_fmt);
    vsnprintf(name, sizeof name, name_fmt, ap);
    va_end(ap);
    g_n_datamac++;   /* P3-5 I3: feeds the FGX2_RELOC_COUNT trailer */
    fprintf(g_data_out, "FGX2_LONG_PTR %s;%s;%d\n", tag, name, tgt_seg);
}

/* emit_mac_dataptr: 4-byte SAME-segment far pointer in the DATA stream
 * (&global in a data initialiser — the target global's storage is in the
 * same data segment as the pointer cell).  LIBC_DATA_PTR resolves the
 * 16-bit offset at ASSEMBLY (seg1 is one Merlin invocation, so cross-TU
 * labels resolve with no export row); only the bank byte gets a load-time
 * reloc.  FGX2_LONG_PTR/_Ga is wrong for this class: it needs an
 * FGX2_EXPORT at the DEFINING TU, which an extern target's TU never emits
 * (curses cr_tty.c `sflags[] = {&AM, ...}` with AM defined in curses.c). */
static void
emit_mac_dataptr(const char *tag, const char *name_fmt, ...)
{
    char name[128];   /* labels cap at prefix(27)+'_'+name(31); 128 is ample */
    va_list ap;
    va_start(ap, name_fmt);
    vsnprintf(name, sizeof name, name_fmt, ap);
    va_end(ap);
    g_n_datamac++;   /* P3-5 I3: feeds the FGX2_RELOC_COUNT trailer */
    fprintf(g_data_out, "LIBC_DATA_PTR %s;%s\n", tag, name);
}

static void
emit_mac_farcall(const char *tgt)
{
    ir_emitf("                FGX2_FARCALL %s\n", tgt);
}

static void emit_pile_call(const char *tgt);

/* A long long or soft double runtime routine: the llong archive's members
 * (toolchain/lib/libllong/), or the double archive's stubs, which call the
 * fpsim module (lib/libdouble/d_stub.s).  Not fcc_runtime.s, which every
 * multi-bank binary carries once per code bank -- so only a tool that uses
 * them pays, and pays once.  Their members are selected into the tool's libc
 * pile, so a call from the pile's own code is a pile call: the pile is
 * reloc-free (fgx_ld's LIBC gate) and the routine is co-assembled with it.
 * From anywhere else the call is far (FGX2_FARCALL, resolved and relocated by
 * fgx_ld).  Either way the routine returns with RTL. */
void
emit_ll_call(const char *name)
{
    if (g_pile && !g_pile_far_extern)
        emit_pile_call(name);
    else
        emit_mac_farcall(name);
}

/* A call into the soft double.  Its entry points are hand-written glue, but
 * behind them is compiled C (lib/libdouble/softdouble.c), which uses the FPR
 * band freely -- so the caller-save discipline of any call to compiled C
 * applies: every live FPR is spilled around it (emit_fpr_spill_live).  The
 * operands travel in the carrier and B, so nothing is pushed below the
 * spill, and the reload keeps A. */
void
emit_d_call(const char *name)
{
    int n = emit_fpr_spill_live();
    emit_ll_call(name);
    emit_fpr_restore_live(n);
}

static void
emit_mac_export(int to_data, const char *fmt, ...)
{
    char lbl[128];   /* labels cap at prefix(27)+'_'+name(31); 128 is ample */
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(lbl, sizeof lbl, fmt, ap);
    va_end(ap);
    if (to_data) {
        g_n_datamac++;   /* P3-5 I3: feeds the FGX2_RELOC_COUNT trailer */
        fprintf(g_data_out, "                FGX2_EXPORT %s\n", lbl);
    } else {
        ir_emitf("                FGX2_EXPORT %s\n", lbl);
    }
}

void
emit_func_prologue(const char *name, int name_len)
{
    /* If the just-declared function is static, emit the mangled label. */
    Func *fn = (g_cur_fn_idx >= 0) ? &g_funcs[g_cur_fn_idx] : NULL;
    if (fn != NULL && fn->is_static) {
        const char *fn_lbl = fname(fn);
        /* Update g_func_name too so FRAMESIZE EQU matches. */
        int n = (int)strlen(fn_lbl);
        if (n >= MAX_IDENT) n = MAX_IDENT - 1;
        memcpy(g_func_name, fn_lbl, (size_t)n);
        g_func_name[n] = '\0';
        /* C2: export the function so a cross-bank FGX2_FARCALL (C1, same name)
         * resolves via the linker's global export table.  Data-segment mode
         * exports too (P3-2.6): fn-ptr INITIALIZERS in seg1 resolve via
         * FGX2_LONG_PTR _Fa, which needs the fn in the export table; the
         * marker is zero-byte, so single-code-bank layout is unshifted. */
        if (g_sections)
            ir_emitf("                FGX_SECT %s\n", fn_lbl);
        emit_mac_export(0, "%s", fn_lbl);
        ir_emitf("%s            ENT\n", fn_lbl);
    } else {
        if (g_sections)
            ir_emitf("                FGX_SECT %.*s\n", name_len, name);
        emit_mac_export(0, "%.*s", name_len, name);
        ir_emitf("%.*s            ENT\n", name_len, name);
    }
    /* No frame: M0 has no locals or args. */
}

static void
emit_load_lit_lower(unsigned value)
{
    ir_emitf("                LDA     #%u\n", value);
}

void
emit_load_lit(unsigned value)
{
    ir_record_op1(IR_LOAD_LIT, value);
    g_expr_type = LT_INT;
    g_expr_unsigned = 0;   /* A-1: plain int literal is signed */
}

void
emit_load_lit_long(unsigned lo, unsigned hi)
{
    ir_emitf("                LDA     #$%04X\n", hi & 0xFFFFu);
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
    ir_emitf("                LDA     #$%04X\n", lo & 0xFFFFu);
    g_expr_type = LT_LONG;
}

void
emit_load_lit_float(unsigned lo, unsigned hi)
{
    /* B-6: load a 32-bit IEEE-754 single literal into A:_fcc_long_hi (the
     * same 4-byte register convention as a long), tagged LT_FLOAT.  The bits
     * were computed on the host at lex time; this is a raw bit-pattern move
     * with no sign-extension. */
    ir_emitf("                LDA     #$%04X\n", hi & 0xFFFFu);
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
    ir_emitf("                LDA     #$%04X\n", lo & 0xFFFFu);
    g_expr_type = LT_FLOAT;
}

/* G53: the 65816 stack-relative `n,S` displacement is 8-bit (0..255).  A
 * function frame larger than 255 bytes (e.g. several local arrays) pushes
 * later locals' slot offsets past 255, so `LDA/STA n,S` is un-assemblable.
 * For a LOCAL whose offset is known >255 at emit time, address the slot via
 * a bank-0 long pointer instead: A = SP + offset, then [_fcc_fp].  Params
 * carry the late-bound `+FRAMESIZE` and are handled separately (stay on the
 * `n,S` path until the param-far cycle).  emit_slot_lda16 leaves A = the
 * 16-bit word at the slot; emit_slot_sta16 stores A and preserves A/X/Y. */
int
slot_needs_far(Local *lc, int extra)
{
    return lc->kind == LK_LOCAL && (local_offset(lc) + extra) > 255;
}

/* P3-3 3.1b: the byte-neutral stack-check annotation for an n,S slot access
 * (tools/stack_check.py).  b = the delta-free, framesize-free base
 * displacement (the compiler's slot intent).  The checker asserts operand ==
 * b + g_s_delta (+FRAMESIZE for a param) AND g_s_delta == its independently
 * tracked push depth — catching a g_s_delta maintenance bug even when the
 * stack stays balanced (the class the exit-code oracle waves through).
 * Non-static: the argc/argv slot bindings in parse_stmt.c annotate too. */
const char *
slot_annot(Local *lc, int off)
{
    static char buf[48];
    if (lc->kind == LK_LOCAL)
        snprintf(buf, sizeof buf, "   ; fccstk d=%d b=%d",
                 g_s_delta, 2 * lc->slot_first + 1 + off);
    else
        snprintf(buf, sizeof buf, "   ; fccstk d=%d b=%d fs",
                 g_s_delta, 3 + 1 + 2 + g_param_byte_offsets[lc->slot_first] + off);
    return buf;
}

/* P3-3 3.1b: emit `<mnem> <slot>` addressing a local/param on the bank-0
 * HARDWARE stack, with the near (n,S) / far (_fcc_fp) displacement gate.
 *   LOCAL — offset is a compile-time constant: branch in C on slot_needs_far
 *           (>255).  The near arm carries the stack-check annotation.
 *   PARAM — offset is symbolic (base+FRAMESIZE, resolved at assembly time):
 *           a Merlin `DO expr/256` selects the far path when the 8-bit n,S
 *           displacement would overflow (Merlin has no `<` and no precedence,
 *           so `base+FRAMESIZE/256` == (base+FRAMESIZE)/256 = 0 near / >=1 far).
 * a_live=1 for mnemonics whose A must survive the (A-clobbering) TSC address
 * calc in the far arm (STA/ORA and friends): PHA before it, +2 offset to
 * compensate the PHA, PLA before the op.  a_live=0 for LDA (the load
 * overwrites A anyway).  slot_addr_str and slot_annot use distinct static
 * buffers, so both may appear in one ir_emitf. */
/* P3-3 3.1b: leave the bank-0 ADDRESS of a local/param slot in _fcc_fp — the
 * >255 far path, since the 8-bit n,S displacement can't reach it.  Callers
 * then use `[_fcc_fp]` (LDA/STA/ORA/ALU/byte/long).  a_live=1 wraps the
 * A-clobbering TSC calc in PHA/PLA and shifts the offset +2 to compensate the
 * PHA, for callers whose A must survive (stores, ALU ops); a_live=0 when the
 * caller has already stashed A (or the op reloads it).  slot_addr_str is
 * numeric for a LOCAL, symbolic (base+FRAMESIZE) for a PARAM. */
static void
emit_far_slot_fp(Local *lc, int off, int a_live)
{
    if (a_live) ir_record_raw(IR_PUSH_A, 0, 0, NULL);
    ir_emitf("                TSC\n");
    ir_emitf("                CLC\n");
    ir_emitf("                ADC     #%s\n", slot_addr_str(lc, a_live ? off + 2 : off));
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_fp"));
    ir_emitf("                STZ     _fcc_fp+2\n");
    if (a_live) ir_record_raw(IR_POP_A, 0, 0, NULL);
}

/* Stage the CURRENT FRAME's bank byte into an 8-bit destination cell: 0 for a
 * hardware frame, DBR (the task's data bank) for a soft one.
 *
 * This is a funnel on purpose.  "The frame is bank 0" was open-coded at six
 * sites, and campaign 1.3 falsified it at every one of them.  The first audit
 * found three and missed three, which shipped codegen that wrote a soft array
 * with one bank and read it back with another -- and the fixture could not see
 * it, because a wrong-but-consistent base still computes the right answer.
 * The seventh site someone adds gets it right only if there is one place to
 * call.  See apple/fgx#12. */
void
emit_frame_bank_a(void)
{
    if (g_fn_is_soft) {
        /* The soft frame lives in the task's DEDICATED soft-stack bank, whose
         * number is the third byte of the pointer itself.  This was PHB/PLA
         * (= DBR) while the soft stack shared the DATA bank; when the stack
         * moved to its own bank, DBR became the wrong answer everywhere a frame
         * address is minted -- and the failure is silent, because the offset
         * stays right and only the bank is wrong. */
        ir_emitf("                LDA     _fcc_sfp+2\n");
    } else {
        ir_emitf("                LDA     #0\n");   /* frame = bank 0 */
    }
}

/* Same, staged into `cell` with its own 8-bit window.  Two entry points because
 * some callers are already inside one (parse_stmt's byte element store). */
void
emit_stage_frame_bank(const char *cell)
{
    emit_m8();
    emit_frame_bank_a();
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(cell));
    emit_m16();
}

static void
emit_slot_op(const char *mnem, Local *lc, int off, int a_live)
{
    if (lc->kind == LK_LOCAL && g_fn_is_soft) {
        /* Bank-0 stack campaign 1.3: this function is a recursion-cycle
         * member, so its locals live in the soft stack's OWN bank.  A slot is
         * `[_fcc_sfp],Y` -- the long form, because that bank is neither DBR nor
         * bank 0.  It was `(_fcc_sfp),Y` into the DATA bank until that bank
         * turned out not to be private: bsh's stak arena claims ~50 KB of it
         * during parse and left the soft stack seven levels (apple/fgx#12).
         *
         * No `+1` bias and no g_s_delta: those are HARDWARE-stack artifacts.
         * _fcc_sfp is a data pointer that pushes on the bank-0 stack do not
         * move, so the offset is the raw frame offset.
         *
         * This CLOBBERS Y.  That is the defect that killed the 2026-07-05 soft
         * stack: `(q = ptr) == 0` held a pointer offset in Y across a slot
         * store and `LDY #idx` ate it, which spun sed's rline forever and was
         * invisible to 326 fixtures.  Callers must not hold a live value in Y
         * across a slot access; M31/ss_nullcmp_soft is the regression net.
         */
        ir_emitf("                LDY     #%d\n", 2 * lc->slot_first + off);
        ir_emitf("                %s     [_fcc_sfp],Y\n", mnem);
        return;
    }
    if (lc->kind == LK_LOCAL) {
        if (slot_needs_far(lc, off)) {
            emit_far_slot_fp(lc, off, a_live);
            ir_emitf("                %s     [_fcc_fp]\n", mnem);
        } else {
            ir_emitf("                %s     %s,S%s\n",
                     mnem, slot_addr_str(lc, off), slot_annot(lc, off));
        }
        return;
    }
    ir_emitf("                DO      %s/256\n", slot_addr_str(lc, off));
    emit_far_slot_fp(lc, off, a_live);
    ir_emitf("                %s     [_fcc_fp]\n", mnem);
    ir_emitf("                ELSE\n");
    ir_emitf("                %s     %s,S%s\n",
             mnem, slot_addr_str(lc, off), slot_annot(lc, off));
    ir_emitf("                FIN\n");
}

void
emit_slot_lda16(Local *lc, int extra)
{
    /* fcc2 P1.3-inc2: a raw `n,S` access during recording is invisible to the
     * promotion rewrite (which only retargets IR_LOAD_LOCAL/STORE_LOCAL), so
     * mark the local non-promotable.  Replay-time lower calls (g_recording==0)
     * are post-decision and must NOT mark. */
    if (ir_recording()) lc->raw_accessed = 1;
    emit_slot_op("LDA", lc, extra, 0);
}

void
emit_slot_sta16(Local *lc, int extra)
{
    if (ir_recording()) lc->raw_accessed = 1;   /* fcc2 P1.3-inc2: see emit_slot_lda16 */
    emit_slot_op("STA", lc, extra, 1);
}

/* emit_warn_uninit_locals -- the use-before-set diagnostic, passed once per
 * function body once every store in it has been seen.
 *
 * K&R 2nd ed 2.4, p.39, is the whole justification and the whole scope:
 *
 *     "External and static variables are initialized to zero by default.
 *      Automatic variables for which is no explicit initializer have undefined
 *      (i.e., garbage) values."
 *
 * So the sentence splits the world exactly where this warning does.  Statics
 * and externs need no diagnostic because the language guarantees their value;
 * an automatic gets whatever the stack held, and on this machine that is a cold
 * boot's RAM rather than an emulator's obliging zeros (apple/fgx#360).
 *
 * TWO VERDICTS, AND THE SECOND IS THE CAUTIOUS ONE.
 *
 *   NEVER SET   n_stores == 0 with a read: a definite bug on every path, and
 *               it cannot be anything else.  Reported always.
 *
 *   SET LATER   a read came before the first store IN SOURCE ORDER.  True for
 *               straight-line code, and NOT true in general: a loop body reads
 *               on iteration two what iteration one stored, so a read recorded
 *               at g_loop_depth > 0 is dropped rather than reported.  A
 *               backwards goto over a store can still slip through, which is
 *               why this arm names the line it saw rather than asserting the
 *               variable is unset.
 *
 * WHAT IS EXCLUDED, EACH FOR A REASON:
 *   - PARAMS.  The caller sets them; that is what a parameter is.
 *   - addr_taken.  `&x' hands the address to something that may fill it --
 *     scanf, a memset, an out-parameter -- and this pass cannot see through it.
 *   - raw_accessed.  A raw `n,S' touch the structured path never saw, so the
 *     store counts are not trustworthy for that local.
 *   - arrays and structs.  Their initialisation is piecemeal by nature and a
 *     partial fill is not a defect; the field/element stores mark them set.
 *   - anything with no read at all.  An unused variable is a different
 *     complaint, and not this one's business.
 */
void
emit_warn_uninit_locals(void)
{
    int i;

    for (i = 0; i < g_n_locals; i++) {
        Local *lc = &g_locals[i];
        if (lc->kind != LK_LOCAL)               continue;
        if (!lc->use_before_set)                continue;  /* a store preceded every read */
        if (lc->addr_taken || lc->raw_accessed) continue;
        if (lc->struct_id >= 0)                 continue;  /* struct: filled piecemeal */
        if (ISARY(lc->type))                    continue;  /* array: ditto */
        if (lc->n_stores == 0) {
            fprintf(stderr, "%s:%d:%d: warning: '%s' is used but never set "
                    "(K&R 2.4: an automatic with no initializer holds garbage)\n",
                    g_input_path, lc->decl_line, lc->decl_col, lc->name);
        } else if (!lc->ubs_in_loop) {
            fprintf(stderr, "%s:%d:%d: warning: '%s' is read before it is set "
                    "(K&R 2.4: an automatic with no initializer holds garbage)\n",
                    g_input_path, lc->decl_line, lc->decl_col, lc->name);
        }
    }
}

void
emit_load_local(Local *lc)
{
    if (g_loop_depth) lc->loop_accessed = 1;   /* fcc2 P1.3-inc2: gates param promotion */
    /* Use-before-set: remember the FIRST read that no store has preceded.  The
     * verdict waits for the end of the function (emit_warn_uninit_locals) --
     * a store may still be coming, and whether one ever arrives is the
     * difference between "never set" and "set later". */
    lc->n_loads++;
    if (lc->n_stores == 0 && !lc->use_before_set) {
        lc->use_before_set = 1;
        lc->ubs_in_loop    = g_loop_depth ? 1 : 0;
    }
    g_expr_unsigned = lc->is_unsigned;   /* A-1 */
    /* Pointer-typed local: 4-byte storage (offset @ +0, bank+pad @ +2).
     * Load bank to _fcc_ptr+2, leave A = offset.  Uses slot_addr_str
     * so param accesses include FRAMESIZE symbolically. */
    if (ISPTR(lc->type)) {   /* B-3: pointer of any depth — 4-byte storage */
        /* fcc2 P1.4 (B1a): structured so promotion can retarget to a DP-IMG pair.
         * g_expr_* are parser-visible -> set at record time; emission defers to
         * emit_load_ptr_local_lower (byte-identical). */
        g_expr_type      = lc->type;
        g_expr_struct_id = lc->struct_id;
        /* Gap-3b: a fn-ptr value carries its signature index so a following
         * `(*fp)(args)` deref-call can find the callee shape.  Reset to -1 on
         * any other pointer load so no stale sig leaks into the call test. */
        g_expr_fn_sig    = (lc->type == LT_FN_PTR) ? lc->fn_sig_id : -1;
        ir_record_op_ptr1(IR_LOAD_PTR_LOCAL, lc, (unsigned)g_s_delta);
        return;
    }
    if (IS_QUAD(lc->type)) {
        g_expr_type      = lc->type;
        g_expr_struct_id = -1;
        ir_record_op_ptr1(IR_LOAD_LLONG_LOCAL, lc, (unsigned)g_s_delta);
        return;
    }
    if (lc->type == LT_LONG || lc->type == LT_FLOAT) {  /* B-6: 4-byte load */
        /* RTL-ABI: structured so the right-to-left arg reversal can adjust the
         * g_s_delta snapshot for a PARAM operand (elvis passes a MARK=long param
         * as a variadic-call arg).  g_expr_* are parser-visible → set now; the
         * emission defers to emit_load_long_local_lower (byte-identical). */
        g_expr_type      = lc->type;
        g_expr_struct_id = -1;
        ir_record_op_ptr1(IR_LOAD_LONG_LOCAL, lc, (unsigned)g_s_delta);
        return;
    }
    /* int/char scalar: structured op.  The g_expr_* side effects below are
     * read by the parser immediately, so they stay at record time; the emission
     * (slot load + char mask) defers to emit_load_local_lower at replay.  The
     * `n,S` offset is g_s_delta-dependent (local_offset adds it), so snapshot
     * g_s_delta and restore it around the lower call. */
    g_expr_type      = lc->type;
    g_expr_struct_id = lc->struct_id;
    /* u1 = loop-access flag (P1.3-inc3): the promotion tally weights loop-body
     * accesses so a loop-bound var with a low STATIC count still promotes. */
    ir_record_op_ptr2(IR_LOAD_LOCAL, lc, (unsigned)g_s_delta, g_loop_depth ? 1u : 0u);
}

static void
emit_load_local_lower(Local *lc, int s_delta)
{
    int saved = g_s_delta;
    g_s_delta = s_delta;
    emit_slot_lda16(lc, 0);
    if (lc->type == LT_CHAR)
        ir_emitf("                AND     #$00FF\n");
    g_s_delta = saved;
}

/* RTL-ABI: lower IR_LOAD_LONG_LOCAL — a 4-byte long/float value load, using the
 * u0 g_s_delta snapshot (so PARAM n,S offsets track the arg reversal).  Byte-
 * identical to the raw emit_slot_lda16(lc,2)/STA _fcc_long_hi/emit_slot_lda16
 * (lc,0) it replaces. */
static void
emit_load_long_local_lower(Local *lc, int s_delta)
{
    int saved = g_s_delta;
    g_s_delta = s_delta;
    emit_slot_lda16(lc, 2);
    ir_emitf("                STA     _fcc_long_hi\n");
    emit_slot_lda16(lc, 0);
    g_s_delta = saved;
}

/* long long: a long with two more words.  w3 and w2 go through A into the
 * data-bank cells first, then w1 into _fcc_long_hi, and w0 is left in A. */
static void
emit_load_llong_local_lower(Local *lc, int s_delta)
{
    int saved = g_s_delta;
    g_s_delta = s_delta;
    emit_slot_lda16(lc, 6);
    ir_emitf("                STA     _fcc_q3\n");
    emit_slot_lda16(lc, 4);
    ir_emitf("                STA     _fcc_q2\n");
    emit_slot_lda16(lc, 2);
    ir_emitf("                STA     _fcc_long_hi\n");
    emit_slot_lda16(lc, 0);
    g_s_delta = saved;
}

/* The store keeps w0 in Y and hands it back in A: a store is an expression
 * and leaves its value. */
static void
emit_store_llong_local_lower(Local *lc, int s_delta)
{
    int saved = g_s_delta;
    g_s_delta = s_delta;
    emit_slot_sta16(lc, 0);
    ir_emitf("                TAY\n");
    ir_emitf("                LDA     _fcc_long_hi\n");
    emit_slot_sta16(lc, 2);
    ir_emitf("                LDA     _fcc_q2\n");
    emit_slot_sta16(lc, 4);
    ir_emitf("                LDA     _fcc_q3\n");
    emit_slot_sta16(lc, 6);
    ir_emitf("                TYA\n");
    g_s_delta = saved;
}

/* The 4-byte store, unpromoted.  Byte-identical to the raw sequence it
 * replaces; the widen arm is u1 because the types it depended on are gone by
 * replay.  ir_record_raw / emit_jsr_rt fall through to emission when
 * !g_recording, which is what makes them safe to call from a lowering. */
static void
emit_store_long_local_lower(Local *lc, int s_delta, unsigned widen)
{
    int saved = g_s_delta;
    g_s_delta = s_delta;
    emit_slot_sta16(lc, 0);
    ir_record_raw(IR_TAY, 0, 0, NULL);          /* keep the low word */
    if (widen == 1u) {
        ir_emitf("                LDA     #0\n");
    } else {
        /* A still holds the low word: _fcc_long_from_int preserves it while
         * setting _fcc_long_hi. */
        if (widen == 2u) emit_jsr_rt("_fcc_long_from_int");
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
    }
    emit_slot_sta16(lc, 2);
    ir_record_raw(IR_TYA, 0, 0, NULL);          /* restore it: the store is an
                                                 * expression and leaves a value */
    g_s_delta = saved;
}

/* PROMOTED: the long lives in img{slot} (low) and img{slot+1} (high).
 *
 * A long value travels in A + _fcc_long_hi, so the load fills both and the
 * store drains both.  No n,S at all -- that is the whole point, and it is why
 * these do not need the g_s_delta dance the stack forms do. */
static void
emit_load_long_local_img_lower(unsigned slot)
{
    ir_emitf("                LDA     _fcc_img%u\n", slot + 1);
    ir_emitf("                STA     _fcc_long_hi\n");
    ir_emitf("                LDA     _fcc_img%u\n", slot);
}

static void
emit_store_long_local_img_lower(unsigned slot, unsigned widen)
{
    ir_emitf("                STA     _fcc_img%u\n", slot);
    ir_record_raw(IR_TAY, 0, 0, NULL);
    if (widen == 1u) {
        ir_emitf("                LDA     #0\n");
    } else {
        if (widen == 2u) emit_jsr_rt("_fcc_long_from_int");
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
    }
    ir_emitf("                STA     _fcc_img%u\n", slot + 1);
    ir_record_raw(IR_TYA, 0, 0, NULL);
}

/* K&R A.7.17 assignment conversions layout alone cannot do: the 4-byte
 * kinds crossing (long<->float) and a float RHS narrowing to int/char
 * (ftoi).  Without these a store copied the RAW IEEE BITS -- frotz
 * longfloat's `w = f` put 0x47C00000 in a long, and dumb_input's
 * `elapsed = (...) * speed` put a float's low word in an int.  The
 * int/char-RHS widening arms stay at the store sites, which fold them
 * into the store op itself.  (long -> int is free: the low word already
 * rides A.)  Wired at the local/global/deref-store sites; member and
 * array-element stores still raw-copy a crossing 4-byte RHS. */
/* A pointer stored into a long: K&R A.7.17 lists what simple assignment
 * accepts -- "both operands have arithmetic type", two structures of the same
 * type, a pointer and a pointer to void, a pointer and a constant 0, or two
 * pointers -- and a long on the left with a pointer on the right is none of
 * them.  A.6.6: such a conversion "must be specified by an explicit
 * type-conversion operator, or cast".  Accepting it stored the offset with a
 * stale high word (apple/fgx#543).  Initialization (A.8.7) and return (A.9.6)
 * convert "as if by assignment" and are held to the same rule.  Called with
 * the RHS walked, so g_expr_type is its type. */
void
require_long_from_ptr_cast(LocalType dst)
{
    if ((dst == LT_LONG || dst == LT_LLONG) &&
        (ISPTR(g_expr_type) || ISARY(g_expr_type)))
        die(g_stmt_line, g_stmt_col,
            "a pointer converts to a long only by a cast (K&R A.6.6, A.7.17)");
}

void
emit_assign_conv(LocalType dst)
{
    require_long_from_ptr_cast(dst);
    if (g_expr_type == LT_DOUBLE && dst != LT_DOUBLE)
        emit_from_double(dst);
    if (dst == LT_DOUBLE && g_expr_type != LT_DOUBLE)
        emit_to_quad(LT_DOUBLE);
    if (dst == LT_FLOAT) {
        if (g_expr_type == LT_LONG) {
            emit_long_to_float();
        }
    } else if (dst == LT_LONG) {
        if (g_expr_type == LT_FLOAT) {
            emit_jsr_rt("_fcc_ftol");
            g_expr_type = LT_LONG;
        }
    } else {
        if (g_expr_type == LT_FLOAT) {
            emit_jsr_rt("_fcc_ftoi");
            g_expr_type = LT_INT;
        }
    }
}

void
emit_store_local(Local *lc)
{
    if (g_expr_type == LT_DOUBLE && lc->type != LT_DOUBLE)
        emit_from_double(lc->type);
    if (g_loop_depth) lc->loop_accessed = 1;   /* fcc2 P1.3-inc2: gates param promotion */
    lc->n_stores++;                            /* use-before-set: see emit_load_local */
    if (ISPTR(lc->type)) {   /* B-3: pointer of any depth — 4-byte storage */
        /* fcc2 P1.4 (B1a): structured so promotion can retarget to a DP-IMG pair.
         * emit_load_value_bank's #0-vs-_fcc_ptr+2 choice depends on the RHS
         * g_expr_type, which is gone at replay -> capture it now into u1. */
        /* #12: 1 = constant int (bank 0), 2 = RUNTIME int (data bank),
         * 3 = a long (its high word), 0 = a real pointer rvalue (its own
         * bank, from _fcc_ptr+2). */
        unsigned bank_zero = (g_expr_type == LT_LONG) ? 3u
                           : (g_expr_type == LT_INT || g_expr_type == LT_CHAR)
                             ? (g_expr_const_int ? 1u : 2u) : 0u;
        ir_record_op_ptr2(IR_STORE_PTR_LOCAL, lc, (unsigned)g_s_delta, bank_zero);
        return;
    }
    if (IS_QUAD(lc->type)) {
        emit_to_quad(lc->type);
        ir_record_op_ptr1(IR_STORE_LLONG_LOCAL, lc, (unsigned)g_s_delta);
        return;
    }
    if (lc->type == LT_LONG || lc->type == LT_FLOAT) {
        /* B-6: an int/char RHS into a float lvalue needs a runtime
         * int->float conversion (Phase 2 _fcc_itof).  Fail closed until then
         * rather than store the raw integer bits as if they were IEEE-754. */
        if (lc->type == LT_FLOAT &&
            (g_expr_type == LT_INT || g_expr_type == LT_CHAR)) {
            /* B-6: implicit int->float conversion on store. */
            emit_itof_rt();
            g_expr_type = LT_FLOAT;
        }
        emit_assign_conv(lc->type);      /* long<->float crossing */
        /* How the RHS reaches the high word.  If it was an int/char,
         * _fcc_long_hi was not produced by the expression — widen rather than
         * pick up a stale high word from a previous long op.  (`long i = 0`
         * after `long a = 65536L`: the for-init inherited a:hi=1 and the loop
         * saw i = 65536 from the start.)  A SIGNED RHS sign-extends, an
         * UNSIGNED one zero-extends: an unconditional LDA #0 stored
         * `long x = -1` as 0x0000FFFF, and compress's `m1 = -1` became 65535,
         * so every htab sentinel read > 0 and the probe looped forever.
         *
         * Captured HERE because g_expr_type and g_expr_unsigned are gone by
         * replay — the same reason IR_STORE_PTR_LOCAL captures bank_zero. */
        unsigned widen = (g_expr_type == LT_INT || g_expr_type == LT_CHAR)
                         ? (g_expr_unsigned ? 1u : 2u) : 0u;
        ir_record_op_ptr2(IR_STORE_LONG_LOCAL, lc, (unsigned)g_s_delta, widen);
        return;
    }
    /* int/char scalar: structured op (lowering reproduces slot_sta16).  The
     * `n,S` offset is g_s_delta-dependent, so snapshot/restore it (see
     * emit_load_local). */
    emit_assign_conv(LT_INT);            /* float RHS narrows via ftoi */
    ir_record_op_ptr2(IR_STORE_LOCAL, lc, (unsigned)g_s_delta, g_loop_depth ? 1u : 0u);
}

static void
emit_store_local_lower(Local *lc, int s_delta)
{
    int saved = g_s_delta;
    g_s_delta = s_delta;
    emit_slot_sta16(lc, 0);
    g_s_delta = saved;
}

/* fcc2 P1.3-inc2: store A back to a scalar local after an in-place ++/--.
 * int/char route through the structured IR_STORE_LOCAL so the promotion pass
 * can retarget the access to a DP-IMG slot (and so the slot can't diverge from
 * the matching emit_load_local); pointers/longs keep the raw 2-byte offset
 * store (their ++/-- intentionally rewrites only the offset word).  When the
 * local isn't promoted, the structured store lowers to the same emit_slot_sta16
 * bytes, so this is byte-identical to the prior direct call. */
void
emit_incdec_store_local(Local *lc)
{
    lc->n_stores++;         /* use-before-set: ++/-- writes the local too */
    if (lc->type == LT_INT || lc->type == LT_CHAR)
        emit_store_local(lc);
    else if (ISPTR(lc->type))
        /* fcc2 P1.4 (B1a): structured offset-word store-back so a `p++` walk
         * pointer stays promotable (raw emit_slot_sta16 sets raw_accessed).
         * Lowers via emit_store_local_lower = the same emit_slot_sta16(lc,0). */
        ir_record_op_ptr1(IR_STORE_PTR_OFFSET, lc, (unsigned)g_s_delta);
    else
        emit_slot_sta16(lc, 0);   /* long: low word only (unchanged) */
}

/* fcc2 P1.4: a value-DISCARDED ++/-- on an int/char scalar local (stride 1).
 * Records a single structured IR_INCDEC_LOCAL instead of the load + CLC/ADC
 * text + store trio, so (a) the promotion pass can retarget it to `INC/DEC
 * _fcc_img{k}` (2 bytes) and (b) the removed text barrier widens clean-BB
 * coverage.  Caller guarantees the result is unused (statement context only)
 * and lc is int/char.  u0 snapshots g_s_delta for the n,S fallback offset;
 * u1 bit0 = is_inc, bit1 = loop-hot (promotion tally weight).  Sets
 * loop_accessed so a loop-bound PARAM stays promotion-eligible (mirrors
 * emit_store_local). */
void
emit_incdec_local(Local *lc, int is_inc)
{
    unsigned u1;
    if (g_loop_depth) lc->loop_accessed = 1;
    u1 = (is_inc ? 1u : 0u) | (g_loop_depth ? 2u : 0u);
    ir_record_op_ptr2(IR_INCDEC_LOCAL, lc, (unsigned)g_s_delta, u1);
}

/* fcc2 P1.3-inc2: lowers for a promoted int/char scalar local living in a
 * DP-IMG slot (_fcc_img{k} @ $C0+2k).  DP-relative => 2-byte STA/LDA, no n,S
 * (g_s_delta-independent), so unlike the n,S local lowers these take no
 * s_delta.  char keeps the load-side mask (matches emit_load_local_lower). */
static void
emit_load_local_img_lower(Local *lc, unsigned k)
{
    ir_emitf("                LDA     _fcc_img%u\n", k);
    if (lc->type == LT_CHAR)
        ir_emitf("                AND     #$00FF\n");
}

static void
emit_store_local_img_lower(unsigned k)
{
    ir_emitf("                STA     _fcc_img%u\n", k);
}

/* fcc2 P1.4: NON-promoted lowering of IR_INCDEC_LOCAL.  Reuses the exact
 * load/store lowering helpers so this is BYTE-IDENTICAL to the prior inline
 * `emit_load_local; CLC; ADC #1; emit_incdec_store_local` (and to v0.14.0 under
 * FCC_NO_REGALLOC).  Stride is always 1 for an int/char scalar. */
static void
emit_incdec_local_lower(Local *lc, int s_delta, int is_inc)
{
    emit_load_local_lower(lc, s_delta);   /* LDA n,S [+ AND #$00FF for char] */
    if (is_inc) {
        ir_emitf("                CLC\n");
        ir_emitf("                ADC     #1\n");
    } else {
        ir_emitf("                SEC\n");
        ir_emitf("                SBC     #1\n");
    }
    emit_store_local_lower(lc, s_delta);  /* STA n,S */
}

/* fcc2 P1.4: PROMOTED lowering — a discarded ++/-- on a DP-IMG slot is a single
 * read-modify-write `INC/DEC _fcc_img{k}` (2 bytes).  No char mask: the slot may
 * hold high bits but every reader masks (see emit_load_local_img_lower). */
static void
emit_incdec_local_img_lower(unsigned k, int is_inc)
{
    ir_emitf("                %s     _fcc_img%u\n", is_inc ? "INC" : "DEC", k);
}

/* fcc2 P1.4 (B1a): lowerings for the structured pointer-local value load/store.
 * BYTE-IDENTICAL to the prior inline ISPTR paths of emit_load_local/store_local.
 * g_s_delta is restored around the n,S slot accesses (as the scalar lowers do). */
static void
emit_load_ptr_local_lower(Local *lc, int s_delta)
{
    int saved = g_s_delta;
    g_s_delta = s_delta;
    emit_slot_lda16(lc, 2);                          /* bank word */
    ir_emitf("                STA     _fcc_ptr+2\n");
    emit_slot_lda16(lc, 0);                          /* A = offset word */
    g_s_delta = saved;
}

static void
emit_store_ptr_local_lower(Local *lc, int s_delta, int bank_is_zero)
{
    int saved = g_s_delta;
    g_s_delta = s_delta;
    emit_slot_sta16(lc, 0);                          /* offset word */
    /* bank: bare NULL/0 int/char RHS under FGX2 -> #0, else the RHS bank in
     * _fcc_ptr+2 (decision captured at record time; see emit_load_value_bank). */
    if (bank_is_zero == 1)
        ir_emitf("                LDA     #0\n");     /* constant int RHS */
    else if (bank_is_zero == 2)
        /* #12: A still holds the offset here, so the helper can keep a
         * RUNTIME zero as the NULL pointer (bank 0) instead of DBR:0000.
         * Raw ir_emitf, not emit_jsr_rt: this IS the replay lowering. */
        ir_emitf("                JSR     _fcc_bank_for_int\n");
    else if (bank_is_zero == 3)
        emit_long_hi_bank();
    else
        ir_emitf("                LDA     _fcc_ptr+2\n");
    emit_slot_sta16(lc, 2);                          /* bank word */
    /* Leave A = the value's low word (the assignment expression's value).  A
     * TAY/TYA round-trip can't preserve it across the bank store: the soft-stack
     * slot store is `LDY #idx / STA [_fcc_fb],Y`, so it clobbers Y and TYA would
     * restore the slot index, not the offset (the `(q = ptr) == 0` miscompare).
     * Reload the offset from the slot we just wrote -- clobbers no live register
     * in either stack model. */
    emit_slot_lda16(lc, 0);                          /* A = offset word (reloaded) */
    g_s_delta = saved;
}

/* fcc2 P1.4 (B1b): lowerings for a pointer local promoted to the img PAIR
 * {k = offset @ _fcc_img{k}, k+1 = bank @ _fcc_img{k+1}} — contiguous, so it is
 * a valid 24-bit far pointer at _fcc_img{k}.  DP-addressed -> SP-independent,
 * no g_s_delta. */
static void
emit_deref_local_img_lower(unsigned k, tword result)
{
    /* THE WIN: a deref is one DP-indirect-long load (vs the 5-instr _fcc_ptr
     * round-trip). char/void pointee keeps the load-side mask. */
    ir_emitf("                LDA     [_fcc_img%u]\n", k);
    if (BTYPE(result) == BT_CHAR || BTYPE(result) == BT_VOID)
        ir_emitf("                AND     #$00FF\n");
}

static void
emit_load_ptr_local_img_lower(unsigned k)
{
    ir_emitf("                LDA     _fcc_img%u\n", k + 1);   /* bank */
    ir_emitf("                STA     _fcc_ptr+2\n");
    ir_emitf("                LDA     _fcc_img%u\n", k);       /* A = offset */
}

/* P3-2.5a: FPR-NATIVE ptr-local value load/store — the pointer-model walker's
 * funnels record these instead of the carrier ops.
 * RECORD side sets the parser-visible g_expr_* (mirrors
 * emit_load_local's ptr branch); LOWER side moves the 4-byte value straight
 * between the slot (or img pair, once promoted) and FPR k — no carrier hop.
 * The load ends with A = the offset word (fpr_load_sym contract: the kd
 * statement arms consume it for offset arithmetic). */
void
emit_fpr_load_ptr_local(int k, Local *lc)
{
    fpr_sym_flush(k);
    if (g_loop_depth) lc->loop_accessed = 1;
    g_expr_type      = lc->type;
    g_expr_struct_id = lc->struct_id;
    g_expr_unsigned  = lc->is_unsigned;
    g_expr_fn_sig    = (lc->type == LT_FN_PTR) ? lc->fn_sig_id : -1;
    ir_record_op_ptr2(IR_FPR_LOAD_PTR_LOCAL, lc, (unsigned)g_s_delta,
                      (unsigned)k);
}

void
emit_fpr_store_ptr_local(int k, Local *lc)
{
    fpr_sym_flush(k);
    lc->n_stores++;         /* use-before-set: the POINTER store path -- N_STORE_VAR breaks here before
       emit_store_local, so a `p = q` never reached the counter */
    if (g_loop_depth) lc->loop_accessed = 1;
    ir_record_op_ptr2(IR_FPR_STORE_PTR_LOCAL, lc, (unsigned)g_s_delta,
                      (unsigned)k);
}

static void
emit_fpr_load_ptr_local_lower(Local *lc, int s_delta, int k)
{
    int saved = g_s_delta;
    g_s_delta = s_delta;
    emit_slot_lda16(lc, 2);                          /* bank word */
    ir_emitf("                STA     %s+2\n", fpr_name(k));
    emit_slot_lda16(lc, 0);
    ir_emitf("                STA     %s\n", fpr_name(k));   /* A = offset */
    g_s_delta = saved;
}

static void
emit_fpr_store_ptr_local_lower(Local *lc, int s_delta, int k)
{
    int saved = g_s_delta;
    g_s_delta = s_delta;
    ir_emitf("                LDA     %s+2\n", fpr_name(k));
    emit_slot_sta16(lc, 2);
    ir_emitf("                LDA     %s\n", fpr_name(k));
    emit_slot_sta16(lc, 0);
    g_s_delta = saved;
}

static void
emit_fpr_load_ptr_local_img_lower(unsigned img, int k)
{
    ir_emitf("                LDA     _fcc_img%u\n", img + 1);
    ir_emitf("                STA     %s+2\n", fpr_name(k));
    ir_emitf("                LDA     _fcc_img%u\n", img);
    ir_emitf("                STA     %s\n", fpr_name(k));   /* A = offset */
}

static void
emit_fpr_store_ptr_local_img_lower(unsigned img, int k)
{
    ir_emitf("                LDA     %s+2\n", fpr_name(k));
    ir_emitf("                STA     _fcc_img%u\n", img + 1);
    ir_emitf("                LDA     %s\n", fpr_name(k));
    ir_emitf("                STA     _fcc_img%u\n", img);
}

static void
emit_store_ptr_local_img_lower(unsigned k, int bank_is_zero)
{
    ir_emitf("                STA     _fcc_img%u\n", k);       /* offset */
    ir_emitf("                TAY\n");                          /* preserve A */
    if (bank_is_zero == 1)
        ir_emitf("                LDA     #0\n");     /* constant int RHS */
    else if (bank_is_zero == 2)
        /* #12: A still holds the offset here, so the helper can keep a
         * RUNTIME zero as the NULL pointer (bank 0) instead of DBR:0000.
         * Raw ir_emitf, not emit_jsr_rt: this IS the replay lowering. */
        ir_emitf("                JSR     _fcc_bank_for_int\n");
    else if (bank_is_zero == 3)
        emit_long_hi_bank();
    else
        ir_emitf("                LDA     _fcc_ptr+2\n");
    ir_emitf("                STA     _fcc_img%u\n", k + 1);   /* bank */
    ir_emitf("                TYA\n");
}

static void
emit_store_ptr_offset_img_lower(unsigned k)
{
    ir_emitf("                STA     _fcc_img%u\n", k);       /* offset word only (p++) */
}

/* fcc2 P1.4 (B1c): the `*p++` / `*p--` rvalue WALK IDIOM (record stub).  Records
 * ONE IR_DEREF_POSTINC_LOCAL whose un-promoted lowering reproduces the old hand-
 * emitted dance byte-for-byte, and whose promoted lowering collapses to a direct
 * img deref.  Sets the parser-visible result type at RECORD time (faithful
 * pointee width via deref_result_expr_type — lever 3), and loop_accessed so a
 * loop-bound PARAM stays promotion-eligible.  u0 = g_s_delta; u1 = (stride << 1)
 * | is_inc. */
void
emit_deref_postinc_local(Local *lc, int is_inc, int stride)
{
    tword result = DECREF(lc->type);    /* type of *p */
    if (g_loop_depth) lc->loop_accessed = 1;
    /* Lever 3: faithful pointee WIDTH/type — mirror emit_deref_fast so *p++ on
     * a long, float or pointer pointee reports the full value (the old path forced
     * LT_INT, which truncated the deref to the low 16 bits / dropped the bank
     * byte).  For int/char/void pointees deref_result_expr_type yields the same
     * LT_INT/LT_CHAR, so the int/char/void byte stream is unchanged. */
    g_expr_type     = deref_result_expr_type(result);
    g_expr_unsigned = lc->is_unsigned;  /* match plain *p (emit_deref_fast); was 0 */
    g_expr_struct_id = lc->struct_id;   /* faithful to emit_load_local(lc)
                                         * side effect (== -1 for char/int/void ptrs) */
    ir_record_op_ptr2(IR_DEREF_POSTINC_LOCAL, lc, (unsigned)g_s_delta,
                      ((unsigned)stride << 1) | (is_inc ? 1u : 0u));
}

/* Un-promoted lowering: load the 4-byte pointer (offset @ A, bank @ _fcc_ptr+2),
 * stash the pre-value, bump it by the stride, store the offset word back, then
 * rebuild _fcc_ptr from the stashed pre-value and deref at the FAITHFUL pointee
 * width.  emit_load_ptr_local_lower / emit_store_local_lower ARE the exact
 * lowerings IR_LOAD_PTR_LOCAL / IR_STORE_PTR_OFFSET used.  Byte-identical to the
 * prior `LDA [_fcc_ptr]` (+mask) emission for int/char/void pointees; for
 * a long, float or pointer pointee it now reads the full value (lever 3). */
static void
emit_deref_postinc_local_lower(Local *lc, int s_delta, int is_inc, int stride)
{
    emit_load_ptr_local_lower(lc, s_delta);
    ir_emitf("                STA     _fcc_tmp_b\n");
    if (is_inc) {
        ir_emitf("                CLC\n");
        ir_emitf("                ADC     #%d\n", stride);
    } else {
        ir_emitf("                SEC\n");
        ir_emitf("                SBC     #%d\n", stride);
    }
    emit_store_local_lower(lc, s_delta);                /* offset word store-back */
    ir_emitf("                LDA     _fcc_tmp_b\n");
    ir_emitf("                STA     _fcc_ptr\n");
    /* Lever 3: faithful pointee WIDTH — the same tail as emit_deref_local_lower.
     * _fcc_ptr (offset+bank) is now set up to the OLD (un-bumped) pointer, so this
     * reads the full long/float (high word via LDA [_fcc_ptr],Y) or the full
     * 4-byte pointer (the ptr arm of emit_deref_result_via_fcc_ptr), not just LDA [_fcc_ptr].
     * Byte-identical to the old single LDA [_fcc_ptr] (+#$00FF mask) for
     * int/char/void.  Its replay-time g_expr_type write is harmless — the parser
     * already consumed the record-time value (as emit_deref_local_lower notes). */
    emit_deref_result_via_fcc_ptr(DECREF(lc->type));
}

/* fcc2 P1.4 (B1c): PROMOTED lowering — p is a contiguous img pair, so deref via
 * [_fcc_img{k}] (true bank from img{k+1}) BEFORE bumping the offset (the post-inc
 * reads old p = the un-bumped slot).  stride 1 (char/void): one A-preserving
 * INC/DEC of the slot.  stride>1 (int): PHA / add stride to the offset slot / PLA
 * so the deref result in A survives the offset add.  No _fcc_ptr rebuild. */
static void
emit_deref_postinc_local_img_lower(Local *lc, unsigned k, int is_inc, int stride)
{
    int is_byte = (lc->type == LT_CHAR_PTR || lc->type == LT_VOID_PTR);
    /* Invariant: only {char,int,void}-pointee pointers promote (ir_ptr_promotable),
     * so stride-1 <=> byte-pointee.  The bump shape keys on stride and the mask
     * keys on is_byte; guard their coupling so a future widening of the promotable
     * set trips loudly here instead of silently miscompiling (a stride-1 non-byte
     * pointee would take the INC bump but skip the #$00FF mask). */
    if ((stride == 1) != is_byte) {
        fprintf(stderr, "fcc: B1c invariant: stride-1 postinc deref must be a byte pointee\n");
        exit(1);
    }
    ir_emitf("                LDA     [_fcc_img%u]\n", k);
    if (stride == 1) {
        /* stride-1 (char/void): A-preserving INC/DEC of the offset slot.  The
         * char mask comes LAST so terminal N/Z reflect the dereferenced VALUE in
         * A (matching the un-promoted and stride>1 lowerings — an INC/DEC last
         * would leave N/Z reflecting the bumped offset instead). */
        ir_emitf("                %s     _fcc_img%u\n", is_inc ? "INC" : "DEC", k);
        if (is_byte)
            ir_emitf("                AND     #$00FF\n");
    } else {
        /* stride>1 (int): preserve the deref result in A across the offset add;
         * the terminal PLA leaves N/Z reflecting the value (no mask for int). */
        ir_emitf("                PHA\n");                        /* save *p */
        ir_emitf("                LDA     _fcc_img%u\n", k);
        if (is_inc) {
            ir_emitf("                CLC\n");
        ir_emitf("                ADC     #%d\n", stride);
        } else {
            ir_emitf("                SEC\n");
        ir_emitf("                SBC     #%d\n", stride);
        }
        ir_emitf("                STA     _fcc_img%u\n", k);
        ir_emitf("                PLA\n");                        /* restore *p */
    }
}

/* fcc2 P1.4 (B1c-2b): un-promoted lowering of IR_INDEX_DEREF_LOCAL.  BYTE-IDENTICAL
 * to emit_array_index_read's scalar-pointer tail: A holds the scaled element index,
 * the 2-byte base offset is @ 1,S, the base bank is in _fcc_ptr+2.  s_delta is the
 * g_s_delta snapshot after the PLA, where a `called' index re-reads the bank. */
static void
emit_index_deref_local_lower(Local *lc, int s_delta, int is_byte, int called)
{
    ir_emitf("                CLC\n");
    ir_emitf("                ADC     1,S\n");      /* + base offset */
    ir_emitf("                STA     _fcc_ptr\n");
    ir_emitf("                PLA\n");              /* drop the 2-byte pushed base */
    if (called) {                                  /* emit_restage_base_bank */
        int saved = g_s_delta;
        g_s_delta = s_delta;
        emit_slot_lda16(lc, 2);
        ir_emitf("                STA     _fcc_ptr+2\n");
        g_s_delta = saved;
    }
    ir_emitf("                LDA     [_fcc_ptr]\n");
    if (is_byte)
        ir_emitf("                AND     #$00FF\n");
}

/* fcc2 P1.4 (B1c-2b): PROMOTED lowering — p is a contiguous img pair {k,k+1}.
 *
 * THIS USED TO DEREF VIA `[_fcc_img{k}],Y' AND THAT IS WRONG FOR A NEGATIVE
 * INDEX (apple/fgx#190).  The 65816 adds Y to the 24-bit base as an UNSIGNED
 * 16-bit displacement with carry into the bank, so a scaled index of -2 arrives
 * as $FFFE and the effective address is base + 65534 -- the RIGHT OFFSET IN THE
 * NEXT BANK UP.  `p[-1]' therefore read a plausible-looking value from
 * somewhere else entirely, silently, and `*(p - 1)' spelling the same thing
 * was correct because it folds the displacement into the pointer instead.
 * K&R A.7.3.1 leaves no room for the two to differ: "E1[E2] is identical (by
 * definition) to *((E1)+(E2))", and A.7.7 converts the integer "by multiplying
 * it by the size of the object to which the pointer points" -- neither
 * paragraph makes the sign special.
 *
 * So it folds, exactly as the un-promoted lowering above does, and for the same
 * reason that one is written that way: a 16-bit two's-complement add into the
 * offset is correct for either sign.  The base bank is already in _fcc_ptr+2
 * and the base offset is already at 1,S when this runs -- the record site puts
 * them there for BOTH lowerings -- so this is now byte-identical to
 * emit_index_deref_local_lower and the two could merge; they are kept apart
 * because the promoted/un-promoted choice is still meaningful to the caller.
 *
 * IT COSTS TWO INSTRUCTIONS on every promoted indexed read.  The alternative
 * that keeps `[dp],Y' is a runtime test of the index's sign, which is bigger
 * than what it saves, and restricting the fast path to provably non-negative
 * CONSTANT indices would leave every variable index -- the loop case, and the
 * one that matters -- on the folding path anyway. */
static void
emit_index_deref_local_img_lower(unsigned k, int is_byte)
{
    (void)k;
    ir_emitf("                CLC\n");
    ir_emitf("                ADC     1,S\n");      /* + base offset */
    ir_emitf("                STA     _fcc_ptr\n");
    ir_emitf("                PLA\n");              /* drop the 2-byte pushed base */
    ir_emitf("                LDA     [_fcc_ptr]\n");
    if (is_byte)
        ir_emitf("                AND     #$00FF\n");
}

void
emit_load_global(Global *g)
{
    refuse_block_static(g, "emit_load_global");
    g_expr_unsigned = g->is_unsigned;   /* A-1 */
    /* Pointer-typed global: 4-byte storage at gname (offset + bank + pad).
     *
     * Single-bank FGX1: the link-baked bank byte (^gname / ^_Sx) is the
     * link ORG bank ($0B), NOT the runtime bank Bank_Alloc picked.  No
     * loader reloc rewrites it.  Sidestep with PHK — crt0 sets DBR = PB
     * = own bank, so PHK gives the right bank for own-bank pointers.
     *
     * Multi-bank FGX2 (g_data_out != NULL): the loader DOES patch
     * gname+2 — fcc emits FGX2_LONG_PTR for initialised pointer globals
     * and the store path stamps the assigned RHS bank for runtime-
     * assigned ones.  PHK here would yield PB (code bank); the value
     * may actually live in DBR (data bank) or any heap bank.  Read the
     * stored byte instead.  This matches emit_load_local's shape. */
    if (ISPTR(g->type)) {   /* B-3: pointer of any depth — 4-byte storage */
        emit_m8();
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp2(gname(g)));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
        emit_m16();
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp(gname(g)));
        g_expr_type      = g->type;
        g_expr_struct_id = g->struct_id;
        /* Gap-3b: propagate a fn-ptr global's signature (see emit_load_local). */
        g_expr_fn_sig    = (g->type == LT_FN_PTR) ? g->fn_sig_id : -1;
        return;
    }
    if (IS_QUAD(g->type)) {
        ir_emitf("                LDA     %s+6\n", gname(g));
        ir_emitf("                STA     _fcc_q3\n");
        ir_emitf("                LDA     %s+4\n", gname(g));
        ir_emitf("                STA     _fcc_q2\n");
        ir_emitf("                LDA     %s+2\n", gname(g));
        ir_emitf("                STA     _fcc_long_hi\n");
        ir_emitf("                LDA     %s\n", gname(g));
        g_expr_type      = g->type;
        g_expr_struct_id = -1;
        return;
    }
    if (g->type == LT_LONG || g->type == LT_FLOAT) {
        /* M20/B-6: load 4-byte long/float global; high word from gname+2. */
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp2(gname(g)));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp(gname(g)));
        g_expr_type      = g->type;
        g_expr_struct_id = -1;
        return;
    }
    /* int/char scalar global: structured op (absolute, not SP-dependent). */
    g_expr_type      = g->type;
    g_expr_struct_id = g->struct_id;
    ir_record_op_ptr(IR_LOAD_GLOBAL, g);
}

static void
emit_load_global_lower(Global *g)
{
    refuse_block_static(g, "emit_load_global_lower");
    ir_emitf("                LDA     %s\n", gname(g));
    if (g->type == LT_CHAR)
        ir_emitf("                AND     #$00FF\n");
}

void
emit_store_global_int(Global *g)
{
    refuse_block_static(g, "emit_store_global_int");
    if (g_expr_type == LT_DOUBLE && g->type != LT_DOUBLE)
        emit_from_double(g->type);
    /* Pointer-typed global: 4-byte storage.  Mirror emit_store_local
     * pattern: store offset, stash A in Y, store bank, restore A. */
    if (ISPTR(g->type)) {   /* B-3: pointer of any depth — 4-byte storage */
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(gname(g)));
        ir_record_raw(IR_TAY, 0, 0, NULL);
        emit_load_value_bank();   /* bare NULL/0 RHS -> bank 0, else RHS bank */
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(gname(g)));
        ir_record_raw(IR_TYA, 0, 0, NULL);
        return;
    }
    if (IS_QUAD(g->type)) {
        emit_to_quad(g->type);
        ir_emitf("                STA     %s\n", gname(g));
        ir_emitf("                TAY\n");
        ir_emitf("                LDA     _fcc_long_hi\n");
        ir_emitf("                STA     %s+2\n", gname(g));
        ir_emitf("                LDA     _fcc_q2\n");
        ir_emitf("                STA     %s+4\n", gname(g));
        ir_emitf("                LDA     _fcc_q3\n");
        ir_emitf("                STA     %s+6\n", gname(g));
        ir_emitf("                TYA\n");
        return;
    }
    if (g->type == LT_LONG || g->type == LT_FLOAT) {
        /* M20/B-6: 4-byte long or float global store.  For LONG, an int/char
         * RHS zero-extends the high word (else `long g = 0;` leaves a stale
         * _fcc_long_hi in g+2).  For FLOAT, an int/char RHS instead needs a
         * runtime int->float conversion (Phase 2 _fcc_itof) -- fail closed
         * until then rather than store raw integer bits as IEEE-754. */
        if (g->type == LT_FLOAT &&
            (g_expr_type == LT_INT || g_expr_type == LT_CHAR)) {
            /* B-6: implicit int->float conversion on store. */
            emit_itof_rt();
            g_expr_type = LT_FLOAT;
        }
        emit_assign_conv(g->type);       /* long<->float crossing */
        /* LONG <- int/char RHS must WIDEN to 32 bits: a SIGNED int sign-
         * extends (negative -> high word $FFFF), an unsigned int zero-extends.
         * The high word was previously hardcoded 0, which corrupted a negative
         * int stored to a long global (`long x = -1;` -> 0x0000FFFF).  A
         * long/float RHS already carries its high word in _fcc_long_hi. */
        {
            int int_rhs = (g_expr_type == LT_INT || g_expr_type == LT_CHAR);
            if (g->type == LT_LONG && int_rhs && !g_expr_unsigned)
                emit_jsr_rt("_fcc_long_from_int");
            ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(gname(g)));
            ir_record_raw(IR_TAY, 0, 0, NULL);
            if (int_rhs && (g->type != LT_LONG || g_expr_unsigned))
                ir_emitf("                LDA     #0\n");
            else
                ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
            ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(gname(g)));
            ir_record_raw(IR_TYA, 0, 0, NULL);
        }
        return;
    }
    /* int scalar global store: structured op. */
    emit_assign_conv(LT_INT);            /* float RHS narrows via ftoi */
    ir_record_op_ptr(IR_STORE_GLOBAL_INT, g);
}

static void
emit_store_global_int_lower(Global *g)
{
    refuse_block_static(g, "emit_store_global_int_lower");
    ir_emitf("                STA     %s\n", gname(g));
}

/* Long-global ++/-- : 32-bit load-modify-store on a LT_LONG global.  The
 * 16-bit inc paths (N_POSTINC_GLOBAL / N_PREINC_GLOBAL) reject long; this
 * reuses the long ABI (A = low, _fcc_long_hi = high) + the _fcc_long_add
 * runtime.  is_inc: 1 = ++, 0 = --.  return_old: postinc value (OLD, preserved
 * across the store via _fcc_tmp_b + one PHA/PLA — both untouched by
 * _fcc_long_add / the store; PHA/PLA is 16-bit under the ambient M16); else
 * preinc / discarded (NEW, left in the accumulator).  Delta is ±1 widened to a
 * long by _fcc_long_from_int (sign-extends #$FFFF -> long -1). */
void
emit_long_incdec_global(Global *g, int is_inc, int return_old)
{
    refuse_block_static(g, "emit_long_incdec_global");
    if (is_inc) ir_emitf("                LDA     #1\n");
    else        ir_emitf("                LDA     #$FFFF\n");
    emit_jsr_rt("_fcc_long_from_int");          /* A/_fcc_long_hi = long(±1) */
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_b_lo"));
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_b_hi"));
    emit_load_global(g);                        /* A = old_lo, _fcc_long_hi = old_hi */
    if (return_old) {
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* save old_lo */
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi")); /* A = old_hi */
        ir_emitf("                PHA\n");                               /* save old_hi */
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* A = old_lo -> acc = old */
    }
    emit_jsr_rt("_fcc_long_add");               /* acc = old ± 1 */
    g_expr_type = LT_LONG;
    emit_store_global_int(g);                   /* store NEW; acc preserved = NEW */
    if (return_old) {
        ir_emitf("                PLA\n");                               /* A = old_hi */
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi")); /* _fcc_long_hi = old_hi */
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* A = old_lo -> acc = OLD */
    }
    g_expr_type = LT_LONG;
}

/* Statement-context (value-discarded) ++/-- on a LONG local.  The generic
 * scalar-local ++/-- path (emit_load_local; ADD/SUB_CONST; emit_incdec_store_
 * local) only touched the LOW word — emit_incdec_store_local stores "long: low
 * word only" — so `long c; c--` from 0 gave 0x0000FFFF (=65535) not -1.  That
 * spun compress(1) decompress()'s `for(code=255; code>=0; code--)` table-init
 * loop forever (0-byte uncompress output).  Do the full 32-bit ±1 via the
 * runtime long ABI (mirrors emit_long_incdec_global) and store both words. */
void
emit_long_incdec_local(Local *lc, int is_inc, int return_old)
{
    if (is_inc) ir_emitf("                LDA     #1\n");
    else        ir_emitf("                LDA     #$FFFF\n");
    emit_jsr_rt("_fcc_long_from_int");          /* A/_fcc_long_hi = long(±1) */
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_b_lo"));
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_b_hi"));
    emit_load_local(lc);                        /* acc = old (A=lo, _fcc_long_hi=hi) */
    emit_jsr_rt("_fcc_long_add");               /* acc = old ± 1 (32-bit, carries) */
    g_expr_type = LT_LONG;
    emit_store_local(lc);                        /* store NEW (both words); acc = NEW */
    /* rvalue use: emit_store_local leaves acc = NEW (A=lo via TYA, _fcc_long_hi=hi),
     * so a PREFIX ++/-- yields NEW with no extra work.  A POSTFIX ++/-- must yield
     * the OLD contents: recover it as NEW - increment (two's-complement exact
     * inverse) by reloading NEW from the just-updated slot and adding the inverse
     * unit.  No PHA/PLA — a stray push would desync g_s_delta for the n,S slot
     * (unlike emit_long_incdec_global, whose store is absolute). */
    if (return_old) {
        if (is_inc) ir_emitf("                LDA     #$FFFF\n");
        else        ir_emitf("                LDA     #1\n");
        emit_jsr_rt("_fcc_long_from_int");
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_b_lo"));
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_b_hi"));
        emit_load_local(lc);                    /* acc = NEW (slot now holds NEW) */
        emit_jsr_rt("_fcc_long_add");           /* acc = NEW + (∓1) = OLD */
    }
    g_expr_type = LT_LONG;
}

void
emit_store_global_char(Global *g)
{
    refuse_block_static(g, "emit_store_global_char");
    emit_assign_conv(LT_CHAR);               /* A.7.17: a float truncates */
    ir_record_op_ptr(IR_STORE_GLOBAL_CHAR, g);
}

static void
emit_store_global_char_lower(Global *g)
{
    refuse_block_static(g, "emit_store_global_char_lower");
    ir_emitf("                SEP     #$20\n");
        ir_emitf("                MX      %%10\n");
    ir_emitf("                STA     %s\n", gname(g));
    ir_emitf("                REP     #$20\n");
        ir_emitf("                MX      %%00\n");
}

void
emit_addr_of_global(Global *g)
{
    refuse_block_static(g, "emit_addr_of_global");
    /* Long-pointer carrying convention: A = offset, _fcc_ptr+2 = bank.
     *
     * Globals live in the DATA bank.  In single-bank FGX1, crt0 sets
     * PBR = DBR = own bank, so PHK == PHB.  In multi-bank FGX2,
     * globals are emitted into the data segment and DBR != PBR — we
     * must use PHB (the runtime data bank) so cross-bank derefs read
     * from the right bank.
     *
     * Link-time ^gname won't work either way: Bank_Alloc places tasks
     * at runtime-chosen banks ($0A/$0B/…), while link ORG is just a
     * fixup target.  PHB (= DBR) is the runtime data bank. */
    emit_m8();
    ir_emitf("                PHB\n");
    ir_record_raw(IR_POP_A, 0, 0, NULL);
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
    emit_m16();
    ir_emitf("                LDA     #%s\n", gname(g));
    /* B-3: &x increments pointer depth.  &arr decays to a pointer-to-
     * element (peel the ARY, push a PTR) — preserving the existing
     * array-address behavior; &scalar / &pointer push a PTR onto the
     * operand type (so &(char*) is char**, not the old int*). */
    if (ISARY(g->type))
        g_expr_type = INCREF(DECREF(g->type), DERIV_PTR);
    else
        g_expr_type = INCREF(g->type, DERIV_PTR);
    g_expr_struct_id = g->struct_id;
}

/* Every &function data cell goes through here, so a site added later cannot
 * silently take the FGX2 path in a kernel-bank build. */
#define EMIT_FA_PTR(fn)                                                       \
    do {                                                                      \
        if (g_module_bank)                                                    \
            emit_mac_modfnptr("_Fa", "%s", fname(fn));                        \
        else if (g_kernel_bank)                                               \
            emit_mac_kfarptr("_Fa", "%s", fname(fn));                         \
        else                                                                  \
            emit_mac_longptr("_Fa", 0, "%s", fname(fn));                      \
    } while (0)

void
emit_addr_of_func(Func *fn)
{
    {
        /* Runtime address-of-function (elvis `tputs(faddch,…)`,
         * `signal(SIGINT, trapint)`, vi motion dispatch `m_fch`…): the target may
         * live in ANOTHER code bank, so PHK (this bank) is the wrong bank AND
         * `LDA #fn` (fn's in-bank offset) is unresolved across segments.
         * Materialize fn's FAR address as a hidden data-segment FGX2_LONG_PTR —
         * fgx_ld resolves the offset globally and relocs the bank byte, exactly
         * like a static fn-ptr table entry (Part 1) — then load offset + bank
         * from it (DBR-relative: the constant lives in the data bank). */
        int lab = new_label();
        fprintf(g_data_out, "%s_FA%d       ", g_tu_prefix, lab);
        EMIT_FA_PTR(fn);
        emit_m8();
        ir_emitf("                LDA     %s_FA%d+2\n", g_tu_prefix, lab);  /* fn bank */
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
        emit_m16();
        ir_emitf("                LDA     %s_FA%d\n", g_tu_prefix, lab);    /* fn offset */
        g_expr_type      = LT_FN_PTR;
        g_expr_struct_id = -1;
    }
}

/* Field-word access for a struct/array LOCAL or struct PARAM.  P3-3 3.1b:
 * routed through emit_slot_op — LOCAL near arm is `<mnem> <2*slot+1+off>+d,S`
 * (was `LDY #k / <mnem> [_fcc_fb],Y`), with the far (_fcc_fp) fallback for a
 * >255 offset that the old 16-bit Y handled implicitly (a functional
 * regression otherwise: a >255 B local struct with a high-offset field).  The
 * PARAM arm gains the same DO/256 far-gate (byte-inert when <256; closes the
 * pre-existing bare-n,S >255 param-field gap).  No more Y clobber — callers
 * that preserved A via _fcc_tmp_b across a two-word store still work; Y is now
 * simply left untouched. */
static void
emit_field_lda(Local *lc, int off) { emit_slot_op("LDA", lc, off, 0); }
static void
emit_field_sta(Local *lc, int off) { emit_slot_op("STA", lc, off, 1); }
static void
emit_field_ora(Local *lc, int off) { emit_slot_op("ORA", lc, off, 1); }

void
emit_load_local_field(Local *lc, Field *f)
{
    g_expr_unsigned = f->is_unsigned;   /* A-1 */
    /* slot_addr_str applies the FRAMESIZE shift symbolically for params,
     * so field accesses on a struct param land in the param area (not
     * the local/RTS area).  Bare %d,S with raw local_offset was the
     * same bug class as strlen_test's emit_deref_fast for params.
     * slot_addr_str returns a static buffer — each call must be
     * inside its own fprintf, never cached across calls. */
    /* M18: 4-byte fn-pointer field — load offset to A and bank to
     * _fcc_ptr+2 so the caller can either store it back, push it as
     * 4-byte ptr arg, or call indirectly. */
    if (f->type == LT_FN_PTR) {
        emit_field_lda(lc, f->byte_offset + 2);
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
        emit_field_lda(lc, f->byte_offset);
        g_expr_type = f->type;
        return;
    }
    if (f->type == LT_LONG || f->type == LT_FLOAT) {   /* B-4/B-6: 4-byte field */
        emit_field_lda(lc, f->byte_offset + 2);
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
        emit_field_lda(lc, f->byte_offset);
        g_expr_type = f->type;
        return;
    }
    if (IS_QUAD(f->type)) {                             /* 8-byte field */
        emit_field_lda(lc, f->byte_offset + 6);
        ir_emitf("                STA     _fcc_q3\n");
        emit_field_lda(lc, f->byte_offset + 4);
        ir_emitf("                STA     _fcc_q2\n");
        emit_field_lda(lc, f->byte_offset + 2);
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
        emit_field_lda(lc, f->byte_offset);
        g_expr_type = f->type;
        return;
    }
    if (ISPTR(f->type)) {   /* load full 4-byte ptr (offset → A,
                             * loader-patched bank → _fcc_ptr+2).  SINGLE-BANK falls through to
                             * the bare offset load; the bank is recovered via PHK at deref (the
                             * FGX1 convention — the deref-postinc ptr arm).  FN_PTR above. */
        emit_field_lda(lc, f->byte_offset + 2);
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
        emit_field_lda(lc, f->byte_offset);
        g_expr_type = f->type;
        return;
    }
    emit_field_lda(lc, f->byte_offset);
    if (f->is_bit_field) {
        for (int i = 0; i < f->bit_offset; i++)
            ir_emitf("                LSR\n");
        int mask = (1 << f->bit_width) - 1;
        ir_emitf("                AND     #$%04X\n", mask & 0xFFFF);
        g_expr_type = LT_INT;
        return;
    }
    if (f->type == LT_CHAR)
        ir_emitf("                AND     #$00FF\n");
    g_expr_type = f->type;
}

void
emit_load_global_field(Global *g, Field *f)
{
    refuse_block_static(g, "emit_load_global_field");
    g_expr_unsigned = f->is_unsigned;   /* A-1 */
    /* M18: 4-byte fn-pointer field — load offset to A, bank to _fcc_ptr+2. */
    if (f->type == LT_FN_PTR) {
        {
            /* The &function initializer emitted a relocatable FGX2_LONG_PTR,
             * so the bank at gname+off+2 is loader-patched to the target's
             * code bank — read it (like the other multi-bank pointers
             * below).  PHK would give THIS code bank, wrong when the target
             * lives in another. */
            ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset + 2));
            ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
        }
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset));
        g_expr_type = f->type;
        return;
    }
    if (f->type == LT_LONG || f->type == LT_FLOAT) {   /* B-4/B-6: 4-byte field */
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset + 2));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset));
        g_expr_type = f->type;
        return;
    }
    if (IS_QUAD(f->type)) {                             /* 8-byte field */
        ir_emitf("                LDA     %s+%d\n", gname(g), f->byte_offset + 6);
        ir_emitf("                STA     _fcc_q3\n");
        ir_emitf("                LDA     %s+%d\n", gname(g), f->byte_offset + 4);
        ir_emitf("                STA     _fcc_q2\n");
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset + 2));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset));
        g_expr_type = f->type;
        return;
    }
    if (ISPTR(f->type)) {   /* read the loader-patched stored bank
                             * from gname+byte_offset+2.  SINGLE-BANK falls through to the bare
                             * offset load; bank via PHK at deref (FGX1 convention). */
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset + 2));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset));
        g_expr_type = f->type;
        return;
    }
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset));
    if (f->is_bit_field) {
        for (int i = 0; i < f->bit_offset; i++)
            ir_emitf("                LSR\n");
        int mask = (1 << f->bit_width) - 1;
        ir_emitf("                AND     #$%04X\n", mask & 0xFFFF);
        g_expr_type = LT_INT;
        return;
    }
    if (f->type == LT_CHAR)
        ir_emitf("                AND     #$00FF\n");
    g_expr_type = f->type;
}

/* The bank word of a 4-byte pointer field store, into A (A = the offset on
 * entry, which the caller has saved).  A long right operand carries its own
 * high word; an int one is a null pointer constant (bank 0, K&R A.6.6) or, at
 * run time, an integer-to-pointer conversion, which takes the data bank as
 * the scalar store arms do (#12); a pointer's bank is in _fcc_ptr+2. */
static void
emit_field_ptr_bank(void)
{
    if (g_expr_type == LT_LONG)
        emit_long_hi_bank();
    else if (g_expr_type == LT_INT || g_expr_type == LT_CHAR) {
        if (g_expr_const_int)
            ir_emitf("                LDA     #0\n");
        else
            emit_jsr_rt("_fcc_bank_for_int");   /* A=offset -> A=bank */
    } else
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2")); /* pointer RHS bank */
}

void
emit_store_local_field(Local *lc, Field *f)
{
    if (g_expr_type == LT_DOUBLE && f->type != LT_DOUBLE)
        emit_from_double(f->type);
    lc->n_stores++;         /* use-before-set: a filled field/element counts */
    /* slot_addr_str(lc, byte_offset) returns "%d+FRAMESIZE,S" for params
     * and "%d,S" for locals — keeps the param-area accesses correct when
     * FRAMESIZE > 0.  Each call clobbers slot_addr_str's static buffer;
     * use one call per fprintf, never cache the pointer. */
    /* M18: 4-byte fn-pointer field store: A = offset, _fcc_ptr+2 = bank
     * (set by upstream addr-of-func / load).  Write both halves.
     * P3-3 3.1b review: the param arms of the three 4-byte stores below were
     * bare `STA n,S` (no DO far-gate, no fccstk annotation) — the same latent
     * >255 param-field gap family (b) closed for the word arms.  emit_field_sta
     * is already unified (gated + annotated, A preserved), so BOTH kinds route
     * through it. */
    if (f->type == LT_FN_PTR) {
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* save A=offset (Y is the addr reg) */
        emit_field_sta(lc, f->byte_offset);
        emit_field_ptr_bank();
        emit_field_sta(lc, f->byte_offset + 2);
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* restore A=offset */
        return;
    }
    if (IS_QUAD(f->type)) {                             /* 8-byte field */
        emit_to_quad(f->type);
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* save A=w0 */
        emit_field_sta(lc, f->byte_offset);
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
        emit_field_sta(lc, f->byte_offset + 2);
        ir_emitf("                LDA     _fcc_q2\n");
        emit_field_sta(lc, f->byte_offset + 4);
        ir_emitf("                LDA     _fcc_q3\n");
        emit_field_sta(lc, f->byte_offset + 6);
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* restore A=w0 */
        return;
    }
    /* A.7.17: an arithmetic field takes the right operand converted to its
     * own type -- the long<->float crossing and a float's truncation. */
    if (f->type == LT_LONG || f->type == LT_FLOAT ||
        f->type == LT_INT  || f->type == LT_CHAR)
        emit_assign_conv(f->type);
    if (f->type == LT_LONG || f->type == LT_FLOAT) {   /* B-4/B-6: 4-byte field */
        if (f->type == LT_FLOAT &&
            (g_expr_type == LT_INT || g_expr_type == LT_CHAR)) {
            emit_itof_rt();  /* int -> float */
            g_expr_type = LT_FLOAT;
        }
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* save A=low word */
        emit_field_sta(lc, f->byte_offset);
        if (g_expr_type == LT_INT || g_expr_type == LT_CHAR) {
            if (g_expr_unsigned) {
                ir_emitf("                LDA     #0\n");        /* zero-extend unsigned */
            } else {
                /* sign-extend the low word (saved in _fcc_tmp_b) into the high
                 * word — was an unconditional LDA #0 (see emit_store_local). */
                ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
                emit_jsr_rt("_fcc_long_from_int");
                ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
            }
        } else {
            ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
        }
        emit_field_sta(lc, f->byte_offset + 2);
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* restore A=low word */
        return;
    }
    if (ISPTR(f->type)) {   /* uniform 4-byte in-struct ptr store: offset+bank, preserve A=lo.
                             * Widen a non-pointer RHS (p=0 / p=NULL / local-struct zero-fill)
                             * to a 4-byte zero — mirrors the LT_LONG widen. */
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* save A=offset */
        emit_field_sta(lc, f->byte_offset);
        emit_field_ptr_bank();
        emit_field_sta(lc, f->byte_offset + 2);
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* restore A=offset */
        return;
    }
    if (f->is_bit_field) {
        int field_mask  = (1 << f->bit_width) - 1;
        int clear_mask  = (~(field_mask << f->bit_offset)) & 0xFFFF;
        /* Stash RHS, clear field bits in container, OR shifted RHS back. */
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
        emit_field_lda(lc, f->byte_offset);
        ir_emitf("                AND     #$%04X\n", clear_mask);
        emit_field_sta(lc, f->byte_offset);
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
        ir_emitf("                AND     #$%04X\n", field_mask & 0xFFFF);
        for (int i = 0; i < f->bit_offset; i++)
            ir_emitf("                ASL\n");
        emit_field_ora(lc, f->byte_offset);
        emit_field_sta(lc, f->byte_offset);
        return;
    }
    if (f->type == LT_CHAR) {
        emit_m8();
        emit_field_sta(lc, f->byte_offset);
        emit_m16();
    } else {
        emit_field_sta(lc, f->byte_offset);
    }
}

/* P3-2.7b: 4-byte pointer store from FPR k into a local aggregate slot
 * (decl-init: struct ptr / fn-ptr fields and ptr-array elements).  off is
 * the byte offset within the local's slots; emit_field_sta supplies the
 * soft-stack ([_fcc_fb],Y) vs hw-stack (n,S) addressing. */
void
emit_fpr_store_local_4(Local *lc, int off, int k)
{
    fpr_sym_flush(k);
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
    emit_field_sta(lc, off);
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp2(fpr_name(k)));
    emit_field_sta(lc, off + 2);
}

void
emit_store_global_field(Global *g, Field *f)
{
    refuse_block_static(g, "emit_store_global_field");
    if (g_expr_type == LT_DOUBLE && f->type != LT_DOUBLE)
        emit_from_double(f->type);
    /* M18: 4-byte fn-pointer field store. */
    if (f->type == LT_FN_PTR) {
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset));
        ir_record_raw(IR_TAY, 0, 0, NULL);
        emit_field_ptr_bank();
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset + 2));
        ir_record_raw(IR_TYA, 0, 0, NULL);
        return;
    }
    if (IS_QUAD(f->type)) {                             /* 8-byte field */
        emit_to_quad(f->type);
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset));
        ir_record_raw(IR_TAY, 0, 0, NULL);
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset + 2));
        ir_emitf("                LDA     _fcc_q2\n");
        ir_emitf("                STA     %s+%d\n", gname(g), f->byte_offset + 4);
        ir_emitf("                LDA     _fcc_q3\n");
        ir_emitf("                STA     %s+%d\n", gname(g), f->byte_offset + 6);
        ir_record_raw(IR_TYA, 0, 0, NULL);
        return;
    }
    /* A.7.17: an arithmetic field takes the right operand converted to its
     * own type -- the long<->float crossing and a float's truncation. */
    if (f->type == LT_LONG || f->type == LT_FLOAT ||
        f->type == LT_INT  || f->type == LT_CHAR)
        emit_assign_conv(f->type);
    if (f->type == LT_LONG || f->type == LT_FLOAT) {   /* B-4/B-6: 4-byte field */
        if (f->type == LT_FLOAT &&
            (g_expr_type == LT_INT || g_expr_type == LT_CHAR)) {
            emit_itof_rt();  /* int -> float */
            g_expr_type = LT_FLOAT;
        }
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset));
        ir_record_raw(IR_TAY, 0, 0, NULL);
        if (g_expr_type == LT_INT || g_expr_type == LT_CHAR) {
            if (g_expr_unsigned) {
                ir_emitf("                LDA     #0\n");        /* zero-extend unsigned */
            } else {
                /* A still holds the low word (TAY preserved it); sign-extend
                 * it into the high word — was an unconditional LDA #0. */
                emit_jsr_rt("_fcc_long_from_int");
                ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
            }
        } else {
            ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
        }
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset + 2));
        ir_record_raw(IR_TYA, 0, 0, NULL);
        return;
    }
    if (ISPTR(f->type)) {   /* uniform 4-byte in-struct ptr store; widen int RHS to 0-bank */
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset));
        ir_record_raw(IR_TAY, 0, 0, NULL);
        emit_field_ptr_bank();
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset + 2));
        ir_record_raw(IR_TYA, 0, 0, NULL);
        return;
    }
    if (f->is_bit_field) {
        int field_mask  = (1 << f->bit_width) - 1;
        int clear_mask  = (~(field_mask << f->bit_offset)) & 0xFFFF;
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset));
        ir_emitf("                AND     #$%04X\n", clear_mask);
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset));
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
        ir_emitf("                AND     #$%04X\n", field_mask & 0xFFFF);
        for (int i = 0; i < f->bit_offset; i++)
            ir_emitf("                ASL\n");
        ir_emitf("                ORA     %s+%d\n", gname(g), f->byte_offset);
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset));
        return;
    }
    if (f->type == LT_CHAR) {
        emit_m8();
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset));
        emit_m16();
    } else {
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset));
    }
}

/* P3-3 3.1b family (c): store A to a struct/array element (constant offset
 * `off`) of a local/param on the bank-0 hardware stack.  es = element size
 * (1 byte / 2 word / 4 long).  n,S near arm + _fcc_fp far arm (>255) + the
 * stack-check annotation, unified for LOCAL and PARAM (slot_addr_str renders
 * each correctly).  A holds the value on entry and MUST survive on return (the
 * word/long callers chain further stores).  The far byte/long paths build the
 * slot address once in _fcc_fp (16-bit calc, before any SEP) and reach the
 * high word via `[_fcc_fp],Y`. */
void
emit_store_local_elem(Local *lc, int off, int es, LocalType vtype)
{
    lc->n_stores++;         /* use-before-set: a filled field/element counts */
    /* Campaign 1.3: a soft LOCAL's element lives in the soft-frame bank, so
     * BOTH hardware-stack arms below are wrong for it -- the n,S near arm and
     * the _fcc_fp far arm alike.  This test MUST precede slot_needs_far.
     * Converting only the near `else` would leave an offset past 255 going
     * through TSC/ADC, minting a BANK-0 far pointer for data-bank storage:
     * silent corruption, and only on the big frames.  [_fcc_sfp],Y has no
     * 255-byte cliff of its own -- it is already a LONG pointer and X/Y stay
     * 16-bit through emit_m8, which touches only the M bit -- so the far arm
     * has no soft counterpart by construction.  es == 2 falls through to the emit_slot_op tail, which
     * carries its own soft arm. */
    if (lc->kind == LK_LOCAL && g_fn_is_soft) {
        int base = 2 * lc->slot_first + off;   /* no +1: that bias is an n,S artifact */
        if (es == 1) {                                  /* byte */
            emit_m8();
            ir_emitf("                LDY     #%d\n", base);
            ir_emitf("                STA     [_fcc_sfp],Y\n");
            emit_m16();
            return;
        }
        if (es == 4) {                          /* long: low @ off, high @ off+2 */
            /* A must survive (the word/long callers chain further stores) and Y
             * is the index register here, so the hard arm's TAY park is not
             * available.  _fcc_tmp_b is the shelf the far arm already uses. */
            ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
            ir_emitf("                LDY     #%d\n", base);
            ir_emitf("                STA     [_fcc_sfp],Y\n");     /* low @ off */
            if (vtype == LT_INT || vtype == LT_CHAR)
                ir_emitf("                LDA     #0\n");
            else
                ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
            ir_emitf("                LDY     #%d\n", base + 2);
            ir_emitf("                STA     [_fcc_sfp],Y\n");     /* high @ off+2 */
            ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
            return;
        }
    }
    int far = slot_needs_far(lc, off);
    if (es == 1) {                                  /* byte: 8-bit store */
        if (far) {
            emit_far_slot_fp(lc, off, 1);           /* A(byte) preserved */
            emit_m8();
            ir_record_raw(IR_STA_DEREF, 0, 0, (void *)cellp("_fcc_fp"));
            emit_m16();
        } else {
            emit_m8();
            ir_emitf("                STA     %s,S%s\n",
                     slot_addr_str(lc, off), slot_annot(lc, off));
            emit_m16();
        }
        return;
    }
    if (es == 4) {                                  /* long: low @ off, high @ off+2 */
        if (far) {
            ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* save low (calc clobbers A) */
            emit_far_slot_fp(lc, off, 0);
            ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
            ir_record_raw(IR_STA_DEREF, 0, 0, (void *)cellp("_fcc_fp"));     /* low @ off */
            if (vtype == LT_INT || vtype == LT_CHAR)
                ir_emitf("                LDA     #0\n");
            else
                ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
            ir_emitf("                LDY     #2\n");
            ir_record_raw(IR_STA_DEREF, 1, 0, (void *)cellp("_fcc_fp"));   /* high @ off+2 */
            ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));     /* restore A = low */
        } else {
            ir_emitf("                STA     %s,S%s\n",
                     slot_addr_str(lc, off), slot_annot(lc, off));
            ir_record_raw(IR_TAY, 0, 0, NULL);
            if (vtype == LT_INT || vtype == LT_CHAR)
                ir_emitf("                LDA     #0\n");
            else
                ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
            ir_emitf("                STA     %s,S%s\n",
                     slot_addr_str(lc, off + 2), slot_annot(lc, off + 2));
            ir_record_raw(IR_TYA, 0, 0, NULL);
        }
        return;
    }
    emit_slot_op("STA", lc, off, 1);                /* es == 2: word */
}

void
emit_deref_ptr_field(LocalType field_type, int field_offset)
{
    g_expr_unsigned = 0;   /* A-1: ptr->field unsigned not tracked yet (default signed) */
    if (field_offset > 0) {
        ir_record_raw(IR_ADD_CONST, (unsigned)(field_offset), 0, NULL);
    }
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
    if (field_type == LT_LONG || field_type == LT_FLOAT) {  /* B-4/B-6: 4-byte field */
        ir_emitf("                LDY     #2\n");
        ir_record_raw(IR_LDA_DEREF, 1, 0, (void *)cellp("_fcc_ptr"));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
        ir_record_raw(IR_LDA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));
        g_expr_type = field_type;
        return;
    }
    if (field_type == LT_CHAR_PTR || field_type == LT_INT_PTR ||
        field_type == LT_VOID_PTR || field_type == LT_LONG_PTR ||
        field_type == LT_STRUCT_PTR || field_type == LT_FN_PTR) {
                                         /* MULTI-BANK: fetch the field's stored offset+bank
                                          * (loader-patched).  SINGLE-BANK falls through to the
                                          * bare load + G22 PHK refresh below (FGX1 convention).
                                          * FN_PTR joins ONLY under --far-calls (Part 2): the
                                          * &function initializer is an FGX2_LONG_PTR reloc there,
                                          * so gname+off+2 holds the real target code bank.  Plain
                                          * --data-segment keeps the own-bank PHK path (all code in
                                          * one bank; fn-ptrs aren't reloc'd).
                                          * Read both halves via _fcc_ptr (still the BASE bank)
                                          * BEFORE committing the loaded bank to _fcc_ptr+2
                                          * (X is transient scratch; no foreign JSR between). */
        ir_emitf("                LDY     #2\n");
        ir_record_raw(IR_LDA_DEREF, 1, 0, (void *)cellp("_fcc_ptr"));   /* stored bank (read in base bank) */
        ir_record_raw(IR_TAX, 0, 0, NULL);
        ir_record_raw(IR_LDA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));     /* stored offset (read in base bank) */
        ir_emitf("                STX     _fcc_ptr+2\n");     /* commit bank AFTER both reads */
        g_expr_type = field_type;
        return;
    }
    ir_record_raw(IR_LDA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));
    if (field_type == LT_CHAR) {
        ir_emitf("                AND     #$00FF\n");
        g_expr_type = LT_CHAR;
    } else {
        if (field_type == LT_CHAR_PTR || field_type == LT_INT_PTR ||
            field_type == LT_VOID_PTR || field_type == LT_FN_PTR ||
            field_type == LT_STRUCT_PTR) {   /* G22: refresh bank so chained
                                              * '->' derefs the loaded
                                              * struct-pointer correctly. */
            ir_record_raw(IR_TAY, 0, 0, NULL);
            emit_m8();
            ir_emitf("                PHK\n");
            ir_record_raw(IR_POP_A, 0, 0, NULL);
            ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
            emit_m16();
            ir_record_raw(IR_TYA, 0, 0, NULL);
        }
        g_expr_type = field_type;
    }
}

void
emit_deref_ptr_field_store(LocalType field_type, int field_offset)
{
    if (field_type == LT_CHAR_PTR || field_type == LT_INT_PTR ||
        field_type == LT_VOID_PTR || field_type == LT_LONG_PTR ||
        field_type == LT_STRUCT_PTR) {
        /* Uniform 4-byte in-struct ptr store via `base->field = rhs`.
         * On entry: A = RHS offset, _fcc_ptr+2 = RHS bank (from RHS eval);
         * base long-ptr at 1,S/3,S.  Store offset+bank at base+field_offset
         * — mirrors emit_deref_store_ptr with the added field offset.  Widen
         * a non-pointer RHS (NULL / 0) to a zero bank.  FN_PTR keeps the
         * legacy path below (own-bank, unchanged). */
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* RHS offset */
        if (g_expr_type == LT_INT || g_expr_type == LT_CHAR)
            ir_emitf("                LDA     #0\n");        /* NULL / int 0 → zero bank */
        else
            ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2")); /* RHS bank */
        ir_record_raw(IR_PUSH_A, 0, 0, NULL);                  /* save bank (base now @ 3,S/5,S) */
        ir_emitf("                LDA     3,S\n");          /* base offset */
        if (field_offset > 0) {
            ir_record_raw(IR_ADD_CONST, (unsigned)(field_offset), 0, NULL);
        }
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
        ir_emitf("                LDA     5,S\n");          /* base bank */
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* RHS offset */
        ir_record_raw(IR_STA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));   /* store offset word */
        ir_record_raw(IR_POP_A, 0, 0, NULL);                  /* RHS bank (base back @ 1,S/3,S) */
        ir_emitf("                LDY     #2\n");
        emit_m8();
        ir_record_raw(IR_STA_DEREF, 1, 0, (void *)cellp("_fcc_ptr")); /* store bank byte */
        emit_m16();
        ir_record_raw(IR_POP_A, 0, 0, NULL);                  /* drop base offset */
        ir_record_raw(IR_POP_A, 0, 0, NULL);                  /* drop base bank */
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* result = RHS offset */
        g_s_delta -= 4;
        return;
    }
    if (field_type == LT_FLOAT &&
        (g_expr_type == LT_INT || g_expr_type == LT_CHAR)) {
        emit_itof_rt();  /* B-6: int -> float */
        g_expr_type = LT_FLOAT;
    }
    ir_record_raw(IR_TAY, 0, 0, NULL);           /* stash rhs */
    ir_emitf("                LDA     1,S\n");
    if (field_offset > 0) {
        ir_record_raw(IR_ADD_CONST, (unsigned)(field_offset), 0, NULL);
    }
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
    ir_emitf("                LDA     3,S\n");
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
    ir_record_raw(IR_TYA, 0, 0, NULL);
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* chained-assign: preserve stored value across base pop */
    if (field_type == LT_CHAR) {
        emit_m8();
        ir_record_raw(IR_STA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));
        emit_m16();
    } else if (field_type == LT_LONG || field_type == LT_FLOAT) {  /* B-4/B-6: 4-byte */
        ir_record_raw(IR_STA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));      /* lo */
        if (g_expr_type == LT_INT || g_expr_type == LT_CHAR) {
            if (g_expr_unsigned) {
                ir_emitf("                LDA     #0\n");        /* zero-extend unsigned */
            } else {
                /* sign-extend the low word (saved in _fcc_tmp_b) into the high
                 * word — was an unconditional LDA #0. */
                ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
                emit_jsr_rt("_fcc_long_from_int");
                ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
            }
        } else {
            ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
        }
        ir_emitf("                LDY     #2\n");
        ir_record_raw(IR_STA_DEREF, 1, 0, (void *)cellp("_fcc_ptr"));    /* hi */
    } else {
        ir_record_raw(IR_STA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));
    }
    ir_record_raw(IR_POP_A, 0, 0, NULL);
    ir_record_raw(IR_POP_A, 0, 0, NULL);
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* result = stored value (A-preserving for chains) */
    g_s_delta -= 4;
}

/* Group 2: prefix/postfix '++'/'--' on a single-hop scalar/pointer
 * '->'member used as an RVALUE — tr(1)'s next()/nextc():
 *   s->last++   postfix int   -> yields OLD value           (line 126)
 *   *s->p++     postfix char* -> '++' yields OLD p, '*' derefs it (151,160)
 *   *--s->p=0   prefix  char* -> '--' yields NEW p, then deref-store (162)
 * (Statement-context `s->p++;` / `s->p--;` is handled by G31 in
 * parse_stmt.c; this is the rvalue twin.)  Read-modify-write the member's
 * offset/value word IN PLACE via _fcc_ptr -> &member (a pointer member's
 * stored bank byte is preserved across the offset bump), then leave the
 * chosen value in A (postfix = old, prefix = new).  For a pointer member
 * the result is a far pointer (A = offset, _fcc_ptr+2 = pointee bank:
 * multi-bank reads the member's stored bank; single-bank uses the program
 * bank via PHK) — matching emit_deref_ptr_field so a following '*' derefs
 * in the correct bank.  No stack slot is used (g_s_delta unchanged).
 * Single-hop; int and char/int/void/long pointer members only. */
/* RMW the offset/value word AT [_fcc_ptr] in place by +/-stride, leaving the
 * chosen value in A (postfix = OLD, prefix = NEW).  _fcc_ptr must already hold
 * the lvalue's far ADDRESS; the stored bank byte is preserved and, for a
 * pointer leaf, re-read into _fcc_ptr+2 so the result is a correct far pointer
 * (A = offset, _fcc_ptr+2 = the value's stored bank).  Shared by member incdec
 * and deref-lvalue incdec.
 *
 * A CHAR LEAF TAKES THE 8-BIT ARM, and it is not optional (apple/fgx#215,
 * #216).  The word RMW below reads and writes TWO bytes, so on a one-byte
 * object it yields `(neighbour << 8) | value', writes the neighbour back from
 * a copy read three instructions earlier, and at 0xFF carries INTO it.  This
 * function used to document that as a precondition -- "never a char scalar" --
 * while three build sites handed it char leaves anyway, so the contract was
 * enforced nowhere.  It is a branch now rather than a comment.
 *
 * THE POST-ADD MASK ON THE PREFIX RESULT IS LOAD-BEARING.  SEP #$20 truncates
 * A for the store but preserves the hidden high byte, so after REP #$20 a
 * wrapped `0xFF + 1' is back in A as 0x0100.  The stored byte is correct and
 * the neighbour is untouched, so ONLY the yielded value is wrong -- which is
 * why `c.b = 0xFF; if (++c.b == 0)' is the fixture case that catches its
 * absence and nothing else is.  Postfix needs no mask: its result comes from
 * _fcc_tmp_b, which was saved already masked. */
/* emit_incdec_at_fcc_ptr's word at offset y: through _fcc_ptr, through the
 * register emit_incdec_at_fpr named, or at the absolute cell
 * emit_incdec_at_sym set. */
static const char *g_rmw_cell;
static const char *g_rmw_ptr;

static void
rmw_lda(int y)
{
    if (g_rmw_cell) {
        ir_record_raw(IR_LDA_CELL, 0, 0,
                      (void *)(y ? cellpf("%s+%d", g_rmw_cell, y) : g_rmw_cell));
        return;
    }
    if (y) {
        ir_emitf("                LDY     #%d\n", y);
        ir_record_raw(IR_LDA_DEREF, 1, 0,
                      (void *)(g_rmw_ptr ? g_rmw_ptr : cellp("_fcc_ptr")));
    } else {
        ir_record_raw(IR_LDA_DEREF, 0, 0,
                      (void *)(g_rmw_ptr ? g_rmw_ptr : cellp("_fcc_ptr")));
    }
}

static void
rmw_sta(void)
{
    if (g_rmw_cell) ir_record_raw(IR_STA_CELL, 0, 0, (void *)g_rmw_cell);
    else            ir_record_raw(IR_STA_DEREF, 0, 0,
                                  (void *)(g_rmw_ptr ? g_rmw_ptr : cellp("_fcc_ptr")));
}

void
emit_incdec_at_fcc_ptr(int stride, int is_inc, int is_prefix, int is_ptr,
                       tword rt, int rt_sid)
{
    /* rt == LT_CHAR is the BARE char leaf, exactly.  BTYPE() alone would
     * also match `char *' and `char[]', whose RMW really is a word. */
    if (!is_ptr && rt == LT_CHAR) {
        /* 8-bit RMW: mask the load, byte-store the result, mask the prefix
         * value.  The neighbouring byte is never read into the result and
         * never written back. */
        rmw_lda(0);
        ir_emitf("                AND     #$00FF\n");        /* old value, 0..255 */
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
        if (is_inc) {
            ir_record_raw(IR_ADD_CONST, (unsigned)(stride), 0, NULL);
        } else {
            ir_record_raw(IR_SUB_CONST, (unsigned)(stride), 0, NULL);
        }
        emit_m8();
        rmw_sta();
        emit_m16();
        if (is_prefix) {
            ir_emitf("                AND     #$00FF\n");    /* NEW, wrap folded */
        } else {
            ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
        }
        g_expr_type      = rt;
        g_expr_struct_id = rt_sid;
        g_expr_unsigned  = 0;
        return;
    }
    rmw_lda(0);  /* old offset/value word */
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));  /* save old */
    if (is_inc) {
        ir_record_raw(IR_ADD_CONST, (unsigned)(stride), 0, NULL);
    } else {
        ir_record_raw(IR_SUB_CONST, (unsigned)(stride), 0, NULL);
    }
    rmw_sta();  /* write new word (ptr bank byte untouched) */
    if (is_ptr) {
        if (is_prefix)
            ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b")); /* wanted = NEW offset */
        /* else wanted = OLD offset, already in _fcc_tmp_b */
        {                                  /* pointee bank = member's stored bank */
            rmw_lda(2);
            ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
        }
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b")); /* A = wanted offset */
    } else {
        if (!is_prefix)
            ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b")); /* postfix int -> OLD value */
        /* prefix int: A already = NEW value */
    }
    g_expr_type      = rt;
    g_expr_struct_id = rt_sid;
    g_expr_unsigned  = 0;
}

void
emit_member_incdec(Local *lc, Global *gv, Field *f, int is_inc, int is_prefix)
{
    refuse_block_static(gv, "emit_member_incdec");
    if (f->type == LT_DOUBLE)
        die(0, 0, "internal: a double member's ++/-- reached the word "
                  "path");
    /* elem_size_for, not ptr_stride: the latter returns 0 for a STRUCT
     * pointer (the size needs the struct id) and the `stride = 1' fallback
     * that used to sit here made `s.next++' advance ONE BYTE (apple/fgx#154).
     * A Field carries its struct_id, so the size is right here. */
    int stride = ISPTR(f->type) ? elem_size_for(f->type, f->struct_id) : 1;

    /* A STRUCT-VARIABLE BASE NEEDS ITS ADDRESS, NOT ITS VALUE (apple/fgx#217).
     * Only a POINTER base carries the address as its value.  For `gv.m++' this
     * loaded the first word OF THE STRUCT and used it as the member's address,
     * so the RMW landed wherever the struct's first member happened to point --
     * for telnet's `clocks.x = clocks.system++' that is low memory, addressed
     * by a timer count.  emit_addr_of_* leave exactly what emit_load_* leave,
     * A = offset and _fcc_ptr+2 = bank, so this is a base swap and nothing
     * below changes.
     *
     * The PREFIX dot spelling never had the bug: it builds an N_LV_INCDEC_E and
     * goes through emit_lvalue_addr, which computes addresses properly.  Only
     * the fixed-shape member node arrives here. */
    if (lc ? (BTYPE(lc->type) == BT_STRUCT && !ISPTR(lc->type))
           : (BTYPE(gv->type) == BT_STRUCT && !ISPTR(gv->type))) {
        if (lc) emit_addr_of_local(lc);
        else    emit_addr_of_global(gv);   /* A = &base, _fcc_ptr+2 = its bank */
    } else {
        if (lc) emit_load_local(lc);
        else    emit_load_global(gv);      /* A = base off, _fcc_ptr+2 = base bank */
    }
    if (f->byte_offset > 0) {
        ir_record_raw(IR_ADD_CONST, (unsigned)(f->byte_offset), 0, NULL);
    }
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));    /* _fcc_ptr -> &member (base bank) */
    emit_incdec_at_fcc_ptr(stride, is_inc, is_prefix, ISPTR(f->type),
                           f->type, f->struct_id);
}

/* 32-bit ++/-- on a LONG pointee reached through a pointer: a struct member
 * (`p->longfield++`, off = the member's byte offset) or a bare deref
 * (`--*lp` where lp is `long *`, off = 0 — novi's buffer.c pops a byte with
 * `--*len` on an `off_t *`).  emit_member_incdec above touches only the low
 * word; a long pointee needs the full 32-bit ±1 with carry.  Reuses the long
 * ABI (acc = A:_fcc_long_hi) + _fcc_long_add, mirroring emit_long_incdec_local
 * but load/storing through fprK (deref-field long / deref-store-long).
 * is_inc: 1=++, 0=--.  return_old (postfix) recovers OLD = NEW ∓ 1 by
 * reloading NEW and adding the inverse unit; else (prefix/discarded) leaves
 * NEW in the accumulator.  Result long lives in A:_fcc_long_hi. */
/* _fcc_long_b = long(+1) for ++, long(-1) for --. */
void
emit_long_unit_to_b(int is_inc)
{
    if (is_inc) ir_emitf("                LDA     #1\n");
    else        ir_emitf("                LDA     #$FFFF\n");
    emit_jsr_rt("_fcc_long_from_int");          /* A/_fcc_long_hi = long(±1) */
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_b_lo"));
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_b_hi"));
}

/* The 32-bit ±1 at fprK+off, with the unit already in _fcc_long_b.  Leaves the
 * result long in A:_fcc_long_hi -- NEW, or OLD when return_old -- and kd live
 * for the caller to drop.  Shared by the symbol-based member form below and
 * the lvalue walker's N_LV_INCDEC_E, which computes kd itself. */
void
emit_long_incdec_at_fpr(int kd, int off, int is_inc, int return_old)
{
    emit_fpr_deref_field(kd, LT_LONG, off);     /* acc = OLD (A=lo, _fcc_long_hi=hi) */
    emit_jsr_rt("_fcc_long_add");               /* acc = OLD ± 1 = NEW */
    g_expr_type = LT_LONG;
    emit_fpr_deref_store_long(kd, off);         /* store NEW (both words) */
    if (return_old) {
        /* recover OLD = NEW ∓ 1 (two's-complement exact inverse): reload NEW
         * from the just-updated member and add the inverse unit. */
        emit_long_unit_to_b(!is_inc);
        emit_fpr_deref_field(kd, LT_LONG, off); /* acc = NEW */
        emit_jsr_rt("_fcc_long_add");           /* acc = NEW ∓ 1 = OLD */
    }
    g_expr_type      = LT_LONG;
    g_expr_struct_id = -1;
    g_expr_unsigned  = 0;
}

/* ++/-- on a LONG, LONG LONG or FLOAT object at fprK+off: the whole object,
 * never the low word alone.  Result in A:_fcc_long_hi -- NEW, or OLD when return_old --
 * and kd left live for the caller to drop.
 *
 * A FLOAT CANNOT RECOVER OLD the way a long does (NEW minus the unit):
 * floating addition does not invert, so `0.1f + 1 - 1' is not 0.1f.  A
 * postfix keeps OLD on the stack across the add instead. */
void
emit_wide_incdec_at_fpr(int kd, int off, LocalType lt, int is_inc,
                        int return_old)
{
    fpr_sym_flush(kd);
    if (lt == LT_DOUBLE) {
        emit_fpr_deref_field(kd, LT_DOUBLE, off);    /* acc = OLD */
        if (return_old)
            emit_push_llong();
        emit_double_add_unit(is_inc);
        emit_fpr_deref_store_llong(kd, off);
        if (return_old)
            emit_pop_llong();
        g_expr_type      = LT_DOUBLE;
        g_expr_struct_id = -1;
        g_expr_unsigned  = 0;
        return;
    }
    if (lt == LT_LONG) {
        emit_long_unit_to_b(is_inc);
        emit_long_incdec_at_fpr(kd, off, is_inc, return_old);
        return;
    }
    if (lt == LT_LLONG) {
        emit_fpr_deref_field(kd, LT_LLONG, off);     /* acc = OLD */
        if (return_old)
            emit_push_llong();
        emit_llong_add_unit(is_inc);
        emit_fpr_deref_store_llong(kd, off);
        if (return_old)
            emit_pop_llong();
        g_expr_type      = LT_LLONG;
        g_expr_struct_id = -1;
        g_expr_unsigned  = 0;
        return;
    }
    ir_emitf("                LDA     #1\n");
    emit_jsr_rt("_fcc_itof");                    /* A:_fcc_long_hi = 1.0 */
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_b_lo"));
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_b_hi"));
    emit_fpr_deref_field(kd, LT_FLOAT, off);     /* acc = OLD */
    if (return_old)
        emit_push_long();
    emit_jsr_rt(is_inc ? "_fcc_fadd" : "_fcc_fsub");   /* acc = OLD ± 1.0 */
    g_expr_type = LT_FLOAT;
    emit_fpr_deref_store_long(kd, off);          /* store NEW, both words */
    if (return_old)
        emit_pop_long();                         /* acc = OLD */
    g_expr_type      = LT_FLOAT;
    g_expr_struct_id = -1;
    g_expr_unsigned  = 0;
}

/* ++/-- on a LONG or FLOAT member of a named base, full width.  The base is
 * the distinction emit_member_incdec draws (apple/fgx#217): a pointer carries
 * the address as its VALUE, a struct variable has to contribute its ADDRESS.
 * Loading a struct variable's value used its first word as the base pointer
 * -- `x = s.lv++' wrote through whatever `s' happened to begin with. */
void
emit_wide_member_incdec(Local *lc, Global *gv, int off, LocalType lt,
                        int is_inc, int return_old)
{
    refuse_block_static(gv, "emit_wide_member_incdec");
    int by_addr = lc ? (BTYPE(lc->type) == BT_STRUCT && !ISPTR(lc->type))
                     : (BTYPE(gv->type) == BT_STRUCT && !ISPTR(gv->type));
    if (lt == LT_LONG)
        emit_long_unit_to_b(is_inc);
    int kd = by_addr ? fpr_addr_sym(lc, gv) : fpr_load_sym(lc, gv);
    if (lt == LT_LONG)
        emit_long_incdec_at_fpr(kd, off, is_inc, return_old);
    else
        emit_wide_incdec_at_fpr(kd, off, lt, is_inc, return_old);
    fpr_drop(kd);
}

/* ++/-- on a FLOAT variable, through its address and full width; the
 * scalar-variable paths are all 16-bit or pointer-stride RMWs.  Result in
 * A:_fcc_long_hi. */
/* ++/-- on a long long variable: load it, keep the old value when the
 * expression is a postfix one, add or subtract 1 with the carry through all
 * four words, store it back.  The value left is the new one, or the old one
 * for a postfix -- A.7.4.1 and A.7.3.4. */
void
emit_llong_incdec(Local *lc, Global *gv, int is_inc, int return_old)
{
    refuse_block_static(gv, "emit_llong_incdec");
    LocalType t = lc ? lc->type : gv->type;       /* long long or long double */
    if (lc != NULL) emit_load_local(lc);
    else            emit_load_global(gv);
    if (return_old)
        emit_push_llong();
    if (t == LT_DOUBLE) emit_double_add_unit(is_inc);
    else                emit_llong_add_unit(is_inc);
    g_expr_type = t;
    if (lc != NULL) emit_store_local(lc);
    else            emit_store_global_int(gv);
    if (return_old)
        emit_pop_llong();
    g_expr_type = t;
    g_expr_unsigned = lc ? lc->is_unsigned : gv->is_unsigned;
}

/* The carrier plus or minus one, the carry run through all four words. */
void
emit_llong_add_unit(int is_inc)
{
    ir_emitf(is_inc ? "                CLC\n" : "                SEC\n");
    ir_emitf(is_inc ? "                ADC     #1\n" : "                SBC     #1\n");
    ir_emitf("                TAY\n");
    ir_emitf("                LDA     _fcc_long_hi\n");
    ir_emitf(is_inc ? "                ADC     #0\n" : "                SBC     #0\n");
    ir_emitf("                STA     _fcc_long_hi\n");
    ir_emitf("                LDA     _fcc_q2\n");
    ir_emitf(is_inc ? "                ADC     #0\n" : "                SBC     #0\n");
    ir_emitf("                STA     _fcc_q2\n");
    ir_emitf("                LDA     _fcc_q3\n");
    ir_emitf(is_inc ? "                ADC     #0\n" : "                SBC     #0\n");
    ir_emitf("                STA     _fcc_q3\n");
    ir_emitf("                TYA\n");
}

void
emit_float_var_incdec(Local *lc, Global *gv, int is_inc, int return_old)
{
    refuse_block_static(gv, "emit_float_var_incdec");
    int kd = fpr_addr_sym(lc, gv);
    emit_wide_incdec_at_fpr(kd, 0, LT_FLOAT, is_inc, return_old);
    fpr_drop(kd);
}

void
emit_long_member_incdec(Local *lc, Global *gv, int off, int is_inc,
                        int return_old)
{
    refuse_block_static(gv, "emit_long_member_incdec");
    emit_wide_member_incdec(lc, gv, off, LT_LONG, is_inc, return_old);
}

void
emit_prologue_unconditional(void)
{
    /* P3-3: allocate the frame on the bank-0 HARDWARE stack and seed _fcc_fb at
     * its base (S+1, bank invariantly 0).  Locals are addressed n,S; _fcc_fb is
     * the frame base for &local address computation.  The caller's _fcc_fb
     * (offset word) is saved with PEI and restored in the epilogue.  &local
     * yields bank 0 for free.  Params sit above the frame + the saved-FP word,
     * so slot_addr_str adds FRAMESIZE+2 to their n,S displacement. */
    ir_emitf("                PEI     _fcc_fb\n");         /* save caller frame ptr */
    ir_tag_last(IRF_PRO_FB, 0);              /* ...and the band (ir_band_frame) */
    ir_emitf("                TSC\n");
    ir_emitf("                SEC\n");
    ir_emitf("                SBC     #%s_FRAMESIZE\n", g_func_name);
    ir_tag_last(IRF_FRAME_SBC, 0);
    /* P3-3 3.2b hardware-stack overflow guard.  DO-gated by %s_STKGUARD (an
     * EQU emitted at function end = 1 iff this fn recurses, calls indirectly,
     * or has a >=128 B frame — small leaf frames stay lean, byte-identical to
     * pre-3.2b).  A = would-be new S (post-SBC, PRE-TCS: S is still the
     * caller's valid stack, so the trap can safely JSL).  BCC after SBC = the
     * subtract borrowed (frame > S, wrapped past 0); CMP _fcc_stkfloor / BCC =
     * new S below the kernel-seeded floor.  Either -> JMP _fcc_stkoflow (clean
     * distinct-exit abort).  Labels/JMP carry no bytes when the DO is false.
     * NEAR JMP (not JML): fcc_runtime.s is duplicated into every code segment,
     * so _fcc_stkoflow lives in the guarded fn's OWN bank — a same-bank JMP
     * (like JSR _fcc_mul16) needs no FGX2 bank reloc, which a plain JML operand
     * would NOT get (cross-bank reloc is macro-only: FGX2_FARCALL/XREF). */
    ir_emitf("                DO      %s_STKGUARD\n", g_func_name);
    ir_emitf("                BCC     %s_stkovf\n", g_func_name);
    ir_emitf("                CMP     _fcc_stkfloor\n");
    ir_emitf("                BCS     %s_stkok\n", g_func_name);
    ir_emitf("%s_stkovf       JMP     _fcc_stkoflow\n", g_func_name);
    ir_emitf("                FIN\n");
    ir_emitf("%s_stkok        TCS\n", g_func_name);         /* allocate the frame */
    /* _fcc_fb = S+1 (the frame base, for &local address computation).  Store S
     * then INC the DP cell: the memory INC is peephole-stable (pat_clcadc only
     * folds CLC/ADC into implied-A INC) and is itself a read of _fcc_fb, so
     * pat_dead_store never drops the store feeding it. */
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_fb"));
    ir_emitf("                INC     _fcc_fb\n");
    /* Bank-0 stack campaign 1.3: allocate this activation's SOFT frame in the
     * data bank.  MUST come AFTER the _fcc_fb seed above, which consumes the
     * post-TCS A: putting it before (the first draft did) makes _fcc_fb the
     * SOFT pointer, so every &local and the whole frame chain point into the
     * wrong bank.  Caught by reading the emitted assembly, not by a test.
     *
     * The guard is the reason this is not just an SBC.  The soft stack owns its
     * bank outright and grows DOWN from $FFFE, so the only floor is the bottom
     * of the bank -- FCC_SOFT_BOTTOM ($0100, include/loader.s), page 0 left
     * unused so a runaway trips here instead of wrapping into an offset that
     * still looks valid.  BCC after the SBC catches the borrow.
     *
     * This compared against the LIVE sbrk break at dataBank:$FFFE while the
     * soft stack shared the data bank.  That arrangement is retired: bsh's stak
     * arena claims ~50 KB of that bank during parse and left the soft stack
     * seven sourced commands, and capping the break to make room corrupted the
     * shell instead of bounding it, because 2.11BSD's setbrk never checks its
     * return (apple/fgx#12).  Without SOME guard here a deep recursion marches
     * soft frames off the bottom of the bank: #4/#9/#11's failure class rebuilt
     * in a bank nothing watches. */
    if (g_fn_is_soft) {
        ir_emitf("                LDA     _fcc_sfp\n");
        ir_emitf("                SEC\n");
        ir_emitf("                SBC     #%s_SOFTSIZE\n", g_func_name);
        ir_emitf("                BCC     %s_sfovf\n", g_func_name);
        ir_emitf("                CMP     #$0100\n");   /* FCC_SOFT_BOTTOM */
        ir_emitf("                BCS     %s_sfok\n", g_func_name);
        ir_emitf("%s_sfovf        JMP     _fcc_sfoflow\n", g_func_name);
        ir_emitf("%s_sfok         STA     _fcc_sfp\n", g_func_name);
    }
    /* P3-3 3.3: no bank-byte seed — the frame is invariantly bank 0 (HW
     * stack), so carrier arms stage a constant 0 bank ($BE freed). */
}

void
emit_epilogue_return(void)
{
    /* P3-3 FP-repoint: deallocate the hardware-stack frame and restore the
     * caller's _fcc_fb.  The return value (A low word) is staged in Y across
     * the TSC (which clobbers A); long-hi / ptr-bank / FPR0 live in DP and
     * survive untouched.  Nothing reads frame memory after TCS raises S
     * (IRQ-above-S discipline).  C3: user fns are JSL-reached, return via RTL. */
    ir_record_raw(IR_TAY, 0, 0, NULL);                       /* stage return low word */
    /* Release the soft frame first, while A is still free -- the return value
     * is parked in Y by the TAY above.  Symmetric with the prologue; a longjmp
     * that skips this is why jmp_buf carries _fcc_sfp (increment 1.1). */
    if (g_fn_is_soft) {
        ir_emitf("                LDA     _fcc_sfp\n");
        ir_emitf("                CLC\n");
        ir_emitf("                ADC     #%s_SOFTSIZE\n", g_func_name);
        ir_emitf("                STA     _fcc_sfp\n");
    }
    ir_emitf("                TSC\n");
    ir_emitf("                CLC\n");
    ir_emitf("                ADC     #%s_FRAMESIZE\n", g_func_name);
    ir_tag_last(IRF_FRAME_ADC, 0);
    ir_emitf("                TCS\n");                        /* free the frame */
    ir_tag_last(IRF_EPI_TCS, 0);             /* ...then pull the band back */
    ir_record_raw(IR_POP_A, 0, 0, NULL);                        /* restore caller frame ptr */
    ir_tag_last(IRF_EPI_TAIL, 0);
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_fb"));
    ir_tag_last(IRF_EPI_TAIL, 0);
    ir_record_raw(IR_TYA, 0, 0, NULL);                         /* restore return value */
    ir_tag_last(IRF_EPI_TAIL, 0);
    ir_emitf("                RTL\n");
    ir_tag_last(IRF_EPI_TAIL, 0);
}

static void
emit_push_a_lower(void)
{
    ir_emitf("                PHA\n");
}

void
emit_push_a(void)
{
    if (g_expr_type == LT_DOUBLE)
        refuse_double("in a 16-bit position");
    ir_record_op(IR_PUSH_A);
    g_s_delta += 2;
}

static void
emit_pop_a_lower(void)
{
    ir_emitf("                PLA\n");
}

void
emit_pop_a(void)
{
    ir_record_op(IR_POP_A);
    g_s_delta -= 2;
}

/* Emit the 4-byte pointer push WITHOUT the g_s_delta bump, so the walk-store
 * SETUP lowerings can reproduce it at replay (mirrors emit_push_a_lower). */
static void
emit_push_ptr_lower(void)
{
    ir_emitf("                TAY\n");               /* stash offset */
    ir_emitf("                LDA     _fcc_ptr+2\n");
    ir_emitf("                PHA\n");               /* bank+pad */
    ir_emitf("                TYA\n");               /* restore offset */
    ir_emitf("                PHA\n");               /* offset on top */
}

void
emit_push_ptr(void)
{
    emit_push_ptr_lower();
    g_s_delta += 4;
}

/* fcc2 P1.4 (B1c-2a-step-2): `*p++ = RHS` / `*p-- = RHS` walk-WRITE push-elision.
 * Record stubs: emit_walk_store_setup brackets the RHS open (folding the
 * emit_load_local + stash + bump + offset store-back + emit_push_ptr that the
 * statement-context simple-assign used to emit inline), emit_walk_store brackets
 * it closed (folding emit_deref_store_dispatch).  Only int/char/void-pointee
 * pointers are routed here (the deref-store-deferral-safe set; see ir.h).
 * g_s_delta is bumped exactly as the folded ops did so the RHS's n,S offsets are
 * recorded unchanged.  u1 = (stride << 1) | is_inc. */
void
emit_walk_store_setup(Local *lc, int stride, int is_inc)
{
    if (g_loop_depth) lc->loop_accessed = 1;
    ir_record_op_ptr2(IR_WALK_STORE_SETUP, lc, (unsigned)g_s_delta,
                      ((unsigned)stride << 1) | (is_inc ? 1u : 0u));
    g_s_delta += 4;          /* the folded emit_push_ptr */
}

void
emit_walk_store(Local *lc, int stride, int is_inc)
{
    ir_record_op_ptr2(IR_WALK_STORE, lc, 0u,
                      ((unsigned)stride << 1) | (is_inc ? 1u : 0u));
    g_s_delta -= 4;          /* the folded deref-store pop */
}

/* UN-PROMOTED SETUP lowering: byte-identical to the old emit_load_local (ISPTR ->
 * IR_LOAD_PTR_LOCAL) + STA tmp_b + bump + emit_incdec_store_local (ISPTR ->
 * IR_STORE_PTR_OFFSET) + LDA tmp_b + emit_push_ptr.  s_delta is the PRE-push
 * snapshot (the n,S home of p), as the load/store-back used. */
static void
emit_walk_store_setup_lower(Local *lc, int s_delta, int is_inc, int stride)
{
    emit_load_ptr_local_lower(lc, s_delta);             /* IR_LOAD_PTR_LOCAL bytes */
    ir_emitf("                STA     _fcc_tmp_b\n");
    if (is_inc) {
        ir_emitf("                CLC\n");
        ir_emitf("                ADC     #%d\n", stride);
    } else {
        ir_emitf("                SEC\n");
        ir_emitf("                SBC     #%d\n", stride);
    }
    emit_store_local_lower(lc, s_delta);                /* IR_STORE_PTR_OFFSET bytes (offset word) */
    ir_emitf("                LDA     _fcc_tmp_b\n");
    emit_push_ptr_lower();
}

/* PROMOTED-not-collapsed SETUP lowering: byte-identical to today's promoted
 * `*p++=` (the img load + img offset store-back the promotion pass produced) plus
 * the retained push.  No _fcc_ptr rebuild — img{k+1} holds the bank. */
static void
emit_walk_store_setup_img_lower(Local *lc, unsigned k, int is_inc, int stride)
{
    (void)lc;
    emit_load_ptr_local_img_lower(k);                   /* IR_LOAD_PTR_LOCAL_IMG bytes */
    ir_emitf("                STA     _fcc_tmp_b\n");
    if (is_inc) {
        ir_emitf("                CLC\n");
        ir_emitf("                ADC     #%d\n", stride);
    } else {
        ir_emitf("                SEC\n");
        ir_emitf("                SBC     #%d\n", stride);
    }
    emit_store_ptr_offset_img_lower(k);                 /* IR_STORE_PTR_OFFSET_IMG bytes (STA img{k}) */
    ir_emitf("                LDA     _fcc_tmp_b\n");
    emit_push_ptr_lower();
}

/* UN-COLLAPSED STORE lowering: the old depth-aware deref-store (pops the 4-byte
 * dest pushed by the SETUP).  emit_deref_store_dispatch mutates g_s_delta (-4);
 * save/restore so a replay-time drift never reaches a later n,S lowering. */
static void
emit_walk_store_lower(Local *lc)
{
    int saved = g_s_delta;
    emit_deref_store_dispatch(lc->type);
    g_s_delta = saved;
}

/* COLLAPSED STORE lowering: img{k} still holds OLD p (SETUP_NONE emitted nothing),
 * so store the RHS (in A) through it, THEN bump img{k} by stride.  A holds the
 * statement result, discarded in this (statement) context — the only context
 * routed to the walk-store ops — so the int path's bump may clobber A. */
static void
emit_walk_store_img_lower(Local *lc, unsigned k, int is_inc, int stride)
{
    int is_byte = (lc->type == LT_CHAR_PTR || lc->type == LT_VOID_PTR);
    /* The same stride<->pointee invariant as emit_deref_postinc_local_img_lower:
     * only int/char/void pointees promote, so stride-1 <=> byte-pointee.  Trip
     * loudly if a future widening of the promotable set breaks the coupling. */
    if ((stride == 1) != is_byte) {
        fprintf(stderr, "fcc: walk-store invariant: stride-1 store must be a byte pointee\n");
        exit(1);
    }
    if (is_byte) {
        ir_emitf("                SEP     #$20\n");
        ir_emitf("                MX      %%10\n");
        ir_emitf("                STA     [_fcc_img%u]\n", k);   /* store byte at old p */
        ir_emitf("                REP     #$20\n");
        ir_emitf("                MX      %%00\n");
        ir_emitf("                %s     _fcc_img%u\n", is_inc ? "INC" : "DEC", k);
    } else {
        ir_emitf("                STA     [_fcc_img%u]\n", k);   /* store word at old p */
        ir_emitf("                LDA     _fcc_img%u\n", k);
        if (is_inc) {
            ir_emitf("                CLC\n");
        ir_emitf("                ADC     #%d\n", stride);
        } else {
            ir_emitf("                SEC\n");
        ir_emitf("                SBC     #%d\n", stride);
        }
        ir_emitf("                STA     _fcc_img%u\n", k);
    }
}

/* Whole-struct copy for `*pd = *ps`.  On entry the DEST long-ptr is at
 * 1,S(offset)/3,S(bank) (pushed by emit_push_ptr) and the SRC long-ptr is in
 * A(offset)+_fcc_ptr+2(bank) (left by parse_unary of the RHS).  Copies nbytes
 * (always even — struct total_size is padded) src->dest via a 16-bit word
 * DEY-loop through _fcc_ptr (src) and _fcc_ptr2 (dest), then pops the 4-byte
 * DEST base.  Without this, struct assignment fell through the scalar
 * deref-store and copied only the low 2 bytes — leaving the rest of the
 * struct (e.g. an LPtr's pointer-bank byte + index) stale.  Caller MX %00. */
void
emit_struct_copy(int nbytes)
{
    int lab = new_label();
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));      /* src offset (bank already in _fcc_ptr+2) */
    ir_emitf("                LDA     1,S\n");           /* dest offset */
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr2"));
    ir_emitf("                LDA     3,S\n");           /* dest bank */
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr2+2"));
    ir_emitf("                LDY     #%d\n", nbytes - 2);
    ir_emitf("%s_L%d\n", g_tu_prefix, lab);
    ir_record_raw(IR_LDA_DEREF, 1, 0, (void *)cellp("_fcc_ptr"));
    ir_record_raw(IR_STA_DEREF, 1, 0, (void *)cellp("_fcc_ptr2"));
    ir_emitf("                DEY\n");
    ir_emitf("                DEY\n");
    emit_bcond(IRC_BPL, lab, 0);
    ir_record_raw(IR_POP_A, 0, 0, NULL);                   /* pop dest base offset */
    ir_record_raw(IR_POP_A, 0, 0, NULL);                   /* pop dest base bank */
    g_s_delta -= 4;
}


static void
emit_push_long_lower(void)
{
    ir_emitf("                TAY\n");                /* stash low */
    ir_emitf("                LDA     _fcc_long_hi\n");
    ir_emitf("                PHA\n");                /* push high */
    ir_emitf("                TYA\n");
    ir_emitf("                PHA\n");                /* push low on top */
}

void
emit_push_long(void)
{
    if (g_expr_type == LT_DOUBLE)
        refuse_double("in a 32-bit position");
    ir_record_op(IR_PUSH_LONG);
    g_s_delta += 4;
}

static void
emit_pop_long_lower(void)
{
    ir_emitf("                PLA\n");                /* low */
    ir_emitf("                TAY\n");                /* stash low in Y */
    ir_emitf("                PLA\n");                /* high */
    ir_emitf("                STA     _fcc_long_hi\n");
    ir_emitf("                TYA\n");                /* restore low to A */
}

void
emit_pop_long(void)
{
    ir_record_op(IR_POP_LONG);
    g_s_delta -= 4;
}

/* The long long in the accumulator becomes the second operand. */
void
emit_stash_llong_to_b(void)
{
    ir_emitf("                STA     _fcc_long_b_lo\n");
    ir_emitf("                LDX     _fcc_long_hi\n");
    ir_emitf("                STX     _fcc_long_b_hi\n");
    ir_emitf("                LDX     _fcc_q2\n");
    ir_emitf("                STX     _fcc_qb2\n");
    ir_emitf("                LDX     _fcc_q3\n");
    ir_emitf("                STX     _fcc_qb3\n");
}

/* long long push and pop: four words, w3 deepest and w0 on top, so the value
 * sits in memory little-endian at 1,S -- the layout a parameter slot reads.
 * Raw text, which the IR treats as a barrier of unknown stack effect: no
 * push-lifting or argument reordering reaches across it. */
void
emit_push_llong(void)
{
    ir_emitf("                TAY\n");
    ir_emitf("                LDA     _fcc_q3\n");
    ir_emitf("                PHA\n");
    ir_emitf("                LDA     _fcc_q2\n");
    ir_emitf("                PHA\n");
    ir_emitf("                LDA     _fcc_long_hi\n");
    ir_emitf("                PHA\n");
    ir_emitf("                TYA\n");
    ir_emitf("                PHA\n");
    g_s_delta += 8;
}

void
emit_pop_llong(void)
{
    ir_emitf("                PLA\n");
    ir_emitf("                TAY\n");
    ir_emitf("                PLA\n");
    ir_emitf("                STA     _fcc_long_hi\n");
    ir_emitf("                PLA\n");
    ir_emitf("                STA     _fcc_q2\n");
    ir_emitf("                PLA\n");
    ir_emitf("                STA     _fcc_q3\n");
    ir_emitf("                TYA\n");
    g_s_delta -= 8;
}

/* Forward decls: these int-ALU lowers are defined after emit_lower_op. */
static void emit_binop_lower(unsigned kind);
static void emit_mulconst_lower(unsigned k);
static void emit_shift_const_lower(unsigned is_lsr, unsigned k);
static void emit_binop_mem_local_lower(Local *lc, int s_delta, unsigned kind);
static void emit_binop_mem_global_lower(Global *g, unsigned kind);
static void emit_binop_mem_img_lower(unsigned slot, unsigned kind);
/* fcc2 P1.4 (B1a): defined next to emit_deref_fast (needs emit_deref_result_via_fcc_ptr). */
static void emit_deref_local_lower(Local *lc, int s_delta, tword result);

/* fcc 2.0 Track 2 Phase 1: lower a structured IR op to g_out (replay dispatch).
 * IR_TEXT is handled in ir.c; this sees only structured ops. */
static void emit_addr_param_lower(Local *lc, int s_delta);   /* RTL-ABI (defined below) */

void
emit_lower_op(const IrNode *n)
{
    switch (n->op) {
    /* T2-3 control-flow lowerings — byte-identical to the IR_TEXT they
     * replaced (same column discipline: label at col 0, mnemonic field
     * padded to 8).  ir_cond_mnem order matches IR_BCOND's u1 doc. */
    case IR_LABEL:
        ir_emitf("%s_L%d\n", g_tu_prefix, (int)n->u0);
        break;
    case IR_BR:
        ir_emitf("                %s     %s_L%d\n",
                 (n->u1 & 1) ? "BRL" : "BRA", g_tu_prefix, (int)n->u0);
        break;
    case IR_BCOND: {
        static const char *ir_cond_mnem[8] =
            { "BEQ", "BNE", "BCC", "BCS", "BMI", "BPL", "BVC", "BVS" };
        unsigned c = n->u1 & 7;
        if (n->u1 & 8) {
            /* FAR form: invert the condition, skip the BRL (the *+5 idiom). */
            ir_emitf("                %s     *+5\n", ir_cond_mnem[c ^ 1]);
            ir_emitf("                BRL     %s_L%d\n", g_tu_prefix, (int)n->u0);
        } else {
            ir_emitf("                %s     %s_L%d\n",
                     ir_cond_mnem[c], g_tu_prefix, (int)n->u0);
        }
        break;
    }
    case IR_JSR_RT:
        ir_emitf("                JSR     %s\n", (const char *)n->ptr);
        break;
    case IR_ADD_CONST:
        /* NOTE: raw ir_emitf on purpose — this IS the lowering (see IR_M8). */
        ir_emitf("                CLC\n");
        /* (pair, part 2) */
        ir_emitf("                ADC     #%d\n", (int)n->u0);
        break;
    case IR_SUB_CONST:
        ir_emitf("                SEC\n");
        /* (pair, part 2) */
        ir_emitf("                SBC     #%d\n", (int)n->u0);
        break;
    case IR_LDA_DEREF:
        ir_emitf((n->u0 & 1) ? "                LDA     [%s],Y\n"
                             : "                LDA     [%s]\n",
                 (const char *)n->ptr);
        break;
    case IR_STA_DEREF:
        ir_emitf((n->u0 & 1) ? "                STA     [%s],Y\n"
                             : "                STA     [%s]\n",
                 (const char *)n->ptr);
        break;
    case IR_LDA_CELL:
        ir_emitf("                LDA     %s\n", (const char *)n->ptr);
        break;
    case IR_STA_CELL:
        ir_emitf("                STA     %s\n", (const char *)n->ptr);
        break;
    case IR_M8:
        /* NOTE: raw ir_emitf on purpose — this IS the lowering.  (A batch
         * converter once rewrote these two lines into emit_m8() and made
         * the op lower by recording itself: infinite recursion.  The
         * interleaved comments keep any future pair-pattern from matching.) */
        ir_emitf("                SEP     #$20\n");
        /* (pair, part 2) */
        ir_emitf("                MX      %%10\n");
        break;
    case IR_M16:
        ir_emitf("                REP     #$20\n");
        /* (pair, part 2) */
        ir_emitf("                MX      %%00\n");
        break;
    case IR_PUSH_A:    emit_push_a_lower();    break;
    case IR_POP_A:     emit_pop_a_lower();     break;
    case IR_PUSH_LONG: emit_push_long_lower(); break;
    case IR_POP_LONG:  emit_pop_long_lower();  break;
    case IR_LOAD_LIT:  emit_load_lit_lower(n->u0); break;
    case IR_STASH_RHS_INT: ir_emitf("                STA     _fcc_tmp_b\n"); break;
    case IR_TAX:       ir_emitf("                TAX\n"); break;
    case IR_TXA:       ir_emitf("                TXA\n"); break;
    case IR_TAY:       ir_emitf("                TAY\n"); break;
    case IR_TYA:       ir_emitf("                TYA\n"); break;
    case IR_LOAD_LOCAL:  emit_load_local_lower((Local *)n->ptr,  (int)n->u0); break;
    case IR_LOAD_LONG_LOCAL: emit_load_long_local_lower((Local *)n->ptr, (int)n->u0); break;
    case IR_LOAD_LLONG_LOCAL:  emit_load_llong_local_lower((Local *)n->ptr, (int)n->u0); break;
    case IR_STORE_LLONG_LOCAL: emit_store_llong_local_lower((Local *)n->ptr, (int)n->u0); break;
    case IR_STORE_LONG_LOCAL:
        emit_store_long_local_lower((Local *)n->ptr, (int)n->u0, n->u1); break;
    case IR_LOAD_LONG_LOCAL_IMG:  emit_load_long_local_img_lower(n->u0); break;
    case IR_STORE_LONG_LOCAL_IMG: emit_store_long_local_img_lower(n->u0, n->u1); break;
    case IR_ADDR_PARAM:      emit_addr_param_lower((Local *)n->ptr, (int)n->u0); break;
    case IR_STORE_LOCAL: emit_store_local_lower((Local *)n->ptr, (int)n->u0); break;
    case IR_LOAD_LOCAL_IMG:  emit_load_local_img_lower((Local *)n->ptr, n->u0); break;
    case IR_STORE_LOCAL_IMG: emit_store_local_img_lower(n->u0); break;
    case IR_INCDEC_LOCAL:    emit_incdec_local_lower((Local *)n->ptr, (int)n->u0, (int)(n->u1 & 1u)); break;
    case IR_INCDEC_LOCAL_IMG: emit_incdec_local_img_lower(n->u0, (int)(n->u1 & 1u)); break;
    case IR_DEREF_LOCAL:     emit_deref_local_lower((Local *)n->ptr, (int)n->u0, (tword)n->u1); break;
    case IR_LOAD_PTR_LOCAL:  emit_load_ptr_local_lower((Local *)n->ptr, (int)n->u0); break;
    case IR_STORE_PTR_LOCAL: emit_store_ptr_local_lower((Local *)n->ptr, (int)n->u0, (int)n->u1); break;
    case IR_STORE_PTR_OFFSET: emit_store_local_lower((Local *)n->ptr, (int)n->u0); break;  /* offset word only */
    case IR_DEREF_LOCAL_IMG:      emit_deref_local_img_lower(n->u0, (tword)n->u1); break;
    case IR_LOAD_PTR_LOCAL_IMG:   emit_load_ptr_local_img_lower(n->u0); break;
    case IR_FPR_LOAD_PTR_LOCAL:
        emit_fpr_load_ptr_local_lower((Local *)n->ptr, (int)n->u0, (int)n->u1); break;
    case IR_FPR_STORE_PTR_LOCAL:
        emit_fpr_store_ptr_local_lower((Local *)n->ptr, (int)n->u0, (int)n->u1); break;
    case IR_FPR_LOAD_PTR_LOCAL_IMG:
        emit_fpr_load_ptr_local_img_lower(n->u0, (int)n->u1); break;
    case IR_FPR_STORE_PTR_LOCAL_IMG:
        emit_fpr_store_ptr_local_img_lower(n->u0, (int)n->u1); break;
    case IR_STORE_PTR_LOCAL_IMG:  emit_store_ptr_local_img_lower(n->u0, (int)n->u1); break;
    case IR_STORE_PTR_OFFSET_IMG: emit_store_ptr_offset_img_lower(n->u0); break;
    case IR_DEREF_POSTINC_LOCAL:
        emit_deref_postinc_local_lower((Local *)n->ptr, (int)n->u0,
                                       (int)(n->u1 & 1u), (int)(n->u1 >> 1)); break;
    case IR_DEREF_POSTINC_LOCAL_IMG:
        emit_deref_postinc_local_img_lower((Local *)n->ptr, n->u0,
                                           (int)(n->u1 & 1u), (int)(n->u1 >> 1)); break;
    case IR_INDEX_DEREF_LOCAL:
        emit_index_deref_local_lower((Local *)n->ptr, (int)n->u0, (int)(n->u1 & 1u),
                                     (int)((n->u1 >> 2) & 1u)); break;
    case IR_INDEX_DEREF_LOCAL_IMG:
        emit_index_deref_local_img_lower(n->u0, (int)(n->u1 & 1u)); break;
    case IR_WALK_STORE_SETUP:
        emit_walk_store_setup_lower((Local *)n->ptr, (int)n->u0,
                                    (int)(n->u1 & 1u), (int)(n->u1 >> 1)); break;
    case IR_WALK_STORE_SETUP_IMG:
        emit_walk_store_setup_img_lower((Local *)n->ptr, n->u0,
                                        (int)(n->u1 & 1u), (int)(n->u1 >> 1)); break;
    case IR_WALK_STORE_SETUP_NONE: break;   /* collapsed: emits nothing */
    case IR_WALK_STORE:
        emit_walk_store_lower((Local *)n->ptr); break;
    case IR_WALK_STORE_IMG:
        emit_walk_store_img_lower((Local *)n->ptr, n->u0,
                                  (int)(n->u1 & 1u), (int)(n->u1 >> 1)); break;
    case IR_SEED_MARK:       ir_emit_param_seeds(); break;
    case IR_LOOP_BEGIN:      ir_emit_loop_seeds(n->u0); break;
    case IR_LOOP_END:        ir_emit_loop_writeback(n->u0); break;
    case IR_BINOP:       emit_binop_lower(n->u0); break;
    case IR_BINOP_MEM_LOCAL:
        emit_binop_mem_local_lower((Local *)n->ptr, (int)n->u0, n->u1); break;
    case IR_BINOP_MEM_GLOBAL:
        emit_binop_mem_global_lower((Global *)n->ptr, n->u0); break;
    case IR_BINOP_MEM_IMG:
        emit_binop_mem_img_lower(n->u0, n->u1); break;
    case IR_MULCONST:    emit_mulconst_lower(n->u0); break;
    case IR_SHIFT_CONST: emit_shift_const_lower(n->u0, n->u1); break;
    case IR_LOAD_GLOBAL:       emit_load_global_lower((Global *)n->ptr);       break;
    case IR_STORE_GLOBAL_INT:  emit_store_global_int_lower((Global *)n->ptr);  break;
    case IR_STORE_GLOBAL_CHAR: emit_store_global_char_lower((Global *)n->ptr); break;
    default:
        fprintf(stderr, "fcc: emit_lower_op: unhandled IrOp %d\n", (int)n->op);
        exit(1);
    }
}

/* P3-0 shared libc: FGX2 links (single- OR multi-bank) reach the libc/shim
 * pile via FGX2_FARCALL (JSL entry, RTL exit — the pile assembles with
 * LIBC_FAR=1); FGX1 keeps near JSR/RTS.  --data-segment is the FGX2 tell
 * (every FGX2 build splits data; --far-calls implies it).  fcc_runtime.s
 * (_fcc_* helpers) stays per-bank and near — do NOT route it through this. */
int
fgx2_libc_far(void)
{
    /* one-mode: every build is FGX2-shaped (P3-2.6).  Inside the pile
     * (--pile) libc/shim calls are same-segment: near JSR (T5-C C3). */
    return !g_pile;
}

/* T5-C C4: same-bank call to a JSL-shaped (ENT/RTL) pile entry with ZERO
 * relocs — the far return frame is built with PHK (bank-independent) and
 * RTL transfers into the target's in-bank offset.  A near JSR misaligns
 * the JSL frame (params read one byte off, RTL pops a garbage byte):
 * c_atoi -> c_atol hung exactly this way.  Segments load bank-aligned,
 * so PEA target-1 (the 16-bit in-segment offset) is position-independent. */
static void
emit_pile_call(const char *tgt)
{
    int lab = new_label();
    ir_emitf("                PHK\n");
    ir_emitf("                PEA     %s_L%d-1\n", g_tu_prefix, lab);
    ir_emitf("                PHK\n");
    ir_emitf("                PEA     %s-1\n", tgt);
    ir_emitf("                RTL             ; PILECALL\n");  /* tag: loop call-clean check */
    ir_emitf("%s_L%d\n", g_tu_prefix, lab);
}

void
emit_libc_call(const char *asm_name)
{
    if (fgx2_libc_far() || g_pile_far_extern)
        emit_mac_farcall(asm_name); /* far-extern pile: libc lives in ANOTHER
                                     * segment (the canonical shared pile) */
    else
        emit_pile_call(asm_name);   /* pile entries are JSL-shaped, NEVER JSR'd */
}

/* --- forward-static-reference fix (call-before-definition) ---------------
 * A file-scope `static` function CALLED before its definition emits the bare
 * name at the call — the single-pass parser hasn't seen the `static` yet, so
 * the implicit forward-ref entry has is_static=0 — but the definition emits the
 * mangled `<tu>_name` (fname()), so the FARCALL never resolves (telnet's Dump).
 * Pre-scan the whole-TU token vector for file-scope static function names up
 * front so emit_call can mangle the forward call's label to match.  Consulted
 * ONLY when a call's g_funcs entry isn't yet marked static, so a TU with no
 * such pattern (every existing golden) sees byte-identical output. */
#define MAX_STATIC_FNS 512
static const char *g_static_fn[MAX_STATIC_FNS];
static int         g_static_fn_len[MAX_STATIC_FNS];
static int         g_n_static_fn = 0;

void
prescan_static_funcs(void)
{
    int depth = 0, i, j;

    g_n_static_fn = 0;
    for (i = 0; i < g_n_toks; i++) {
        TokKind k = g_toks[i].kind;
        if (k == TOK_LBRACE) { depth++; continue; }
        if (k == TOK_RBRACE) { if (depth > 0) depth--; continue; }
        if (depth != 0 || k != TOK_STATIC_KW) continue;
        /* First `IDENT (` = the declared name; stop at a declaration
         * terminator so `static T v;` / `static int x = f();` don't misfire. */
        for (j = i + 1; j < g_n_toks; j++) {
            TokKind kk = g_toks[j].kind;
            if (kk == TOK_SEMI || kk == TOK_LBRACE ||
                kk == TOK_EQ   || kk == TOK_COMMA) break;
            if (kk == TOK_IDENT && j + 1 < g_n_toks &&
                g_toks[j + 1].kind == TOK_LPAREN) {
                if (g_n_static_fn < MAX_STATIC_FNS) {
                    g_static_fn[g_n_static_fn]     = g_toks[j].id_ptr;
                    g_static_fn_len[g_n_static_fn] = g_toks[j].id_len;
                    g_n_static_fn++;
                }
                break;
            }
        }
    }
}

static int
is_file_scope_static_fn(const char *name, int name_len)
{
    int i;
    for (i = 0; i < g_n_static_fn; i++)
        if (g_static_fn_len[i] == name_len &&
            memcmp(g_static_fn[i], name, (size_t)name_len) == 0)
            return 1;
    return 0;
}

void
emit_call(const char *name, int name_len, int is_far)
{
    /* multi-TU: if the called name resolves to a file-scope static
     * function, emit the mangled label.  is_far (set by the caller only for
     * USER-function calls under --far-calls) → FGX2_FARCALL (cross-bank, RTL);
     * else JSR (near — same-bank user call, OR any libc/runtime shim, which
     * are duplicated per code bank and stay near). */
    int fn_idx = funcs_lookup(name, name_len);
    /* Resolve the target label once (mangled for file-scope statics) so we can
     * both emit it and test it for direct self-recursion (P3-3 3.2b: a
     * self-call makes this function eligible for the prologue stack guard). */
    char tgt[sizeof g_fname_buf];   /* mangled statics: prefix(27)+'_'+name(31) */
    if (fn_idx >= 0 && g_funcs[fn_idx].is_static)
        snprintf(tgt, sizeof tgt, "%s", fname(&g_funcs[fn_idx]));
    else if (is_file_scope_static_fn(name, name_len))
        /* forward ref: definition is static (mangled) but the parser hasn't
         * seen it yet — mangle to match (see prescan_static_funcs). */
        snprintf(tgt, sizeof tgt, "%s_%.*s", g_tu_prefix, name_len, name);
    else
        snprintf(tgt, sizeof tgt, "%.*s", name_len, name);
    if (is_far)
        emit_mac_farcall(tgt);
    else if (g_pile) {
        /* Far-extern pile (2026-07-17): a call to a function NOT defined in
         * this pile (extern decl / implicit / forward ref the single-pass
         * parse hasn't seen) crosses segments — FGX2_FARCALL.  Targets
         * DEFINED in the pile so far stay near pile calls, and STATICS stay
         * near unconditionally: file-scope means same-TU by definition, and
         * their mangled labels are never exported for far resolution. */
        if (g_pile_far_extern
            && !(fn_idx >= 0 && (!g_funcs[fn_idx].is_extern
                                 || g_funcs[fn_idx].is_static)))
            emit_mac_farcall(tgt);
        else
            emit_pile_call(tgt);    /* every pile-resident target is ENT/RTL */
    } else
        ir_emitf("                JSR     %s\n", tgt);
    if (g_func_name[0] && strcmp(tgt, g_func_name) == 0)
        ir_note_self_recursion();
    /* M20: set g_expr_type from the called function's return type.  For
     * long returns, the high word is already in _fcc_long_hi from the
     * callee's epilogue.  Falls back to LT_INT for unknown calls
     * (libc shims, multi-TU externs). */
    if (fn_idx >= 0) {
        g_expr_type = g_funcs[fn_idx].return_type;
    } else {
        g_expr_type = LT_INT;
    }
}

void
emit_call_indirect(int kc)
{
    /* The callee (offset,bank) rides FPR kc (P3-2.4 fn-ptr dispatch). */
    const char *po = fpr_name(kc);
    int lab_r = new_label();
    /* fcc2 P1.3-inc2: the computed-RTS trampoline below carries no JSR/JSL/
     * FARCALL token, so flag the indirect call directly — it disqualifies this
     * function from DP-IMG promotion (the callee may clobber $C0..$DF). */
    ir_note_indirect_call();
    {
        /* The callee lives in an arbitrary code bank
         * and returns via RTL (3-byte far), so we must build a far return frame
         * and transfer control to the FULL 24-bit target — offset + bank in
         * FPR kc (set up by the fn-ptr rvalue load).  No single
         * 65816 instruction indirects through a DBR-relative 24-bit pointer
         * (JML [abs] fetches from bank 0 only), so use the two-frame RTL idiom:
         *   1. push the far RETURN frame (PHK + PEA ret-1) — consumed by the
         *      callee's own RTL, lands back at ret in THIS code bank;
         *   2. push the far TARGET frame (bank + offset-1) and RTL into it.
         * On entry the callee sees [args][3-byte return frame] — byte-identical
         * to a direct FGX2_FARCALL (JSL) entry.  A/X stay 16-bit. */
        ir_emitf("                PHK\n");                     /* return bank = this code bank */
        ir_emitf("                PEA     %s_L%d-1\n", g_tu_prefix, lab_r); /* return offset-1 */
        if (g_module_bank || g_kernel_bank) {
            /* A SINGLE-BANK IMAGE -- an FGXM module (--module-bank) or a
             * statically linked kernel bank, far or tty (--kernel-bank).  In
             * both, DBR is the program bank: mod_init and every far- and
             * tty-bank entry do PHK/PLB.  And in both, every &function cell has
             * its bank byte written at image init -- _Mod_StampFnPtrs for
             * MOD_FN_PTR, Far_BankInit and Tty_BankInit for KFAR_FN_PTR -- so
             * the pointer names its bank and the call reads it.  PHK here named
             * the CALLER's bank, which is the wrong one whenever the pointer
             * came from another image: v_op stored by one module and dispatched
             * by another (apple/fgx#173), mp->mnt_op dispatched by the far bank.
             * K&R A.7.4.2: the value of &f is "a pointer to the ... function
             * referred to", which a bare offset stops being the moment a second
             * bank exists.
             *
             * apple/fgx#178.  The target's bank has to reach
             * DBR as well as the RTL frame, because fcc reads every global,
             * literal and runtime scratch DBR-relatively -- so a callee entered
             * with the CALLER's DBR reads its own data structures at the right
             * offsets in the wrong bank and returns plausible garbage.
             *
             * K&R A.7.3.2 (p.163) is what makes this the call's problem rather
             * than the caller's: "The postfix expression ... must be of type
             * `pointer to function returning T' ... and the value of the
             * function call has type T", and the ANSI rule it describes
             * "permit[s] the same syntax for calls to functions and to
             * functions specified by pointers".  The same syntax has to mean
             * the same call.  A DIRECT cross-module call gets the callee's DBR
             * -- ufs.mod's vfs_import.s shims do exactly this by hand, PHA/PLB
             * off the target bank -- so a call through &f must too.  #173 made
             * the pointer name the right function; without this, calling it
             * does not run it.
             *
             * PHA/PLB is net zero on the stack, so it can sit between the
             * return frame and the target frame, and the bank is then read a
             * SECOND time for the frame itself rather than recovered with PHB.
             * That keeps the recorded IR identical to the arm below -- exactly
             * one IR_PUSH_A -- so the optimizer sees the same shape it always
             * has; three bytes is a cheap price for not teaching it a new one.
             *
             * The restore at the return label is PHK/PLB rather than a saved
             * copy: a module's DBR IS its program bank, and there is nowhere on
             * this stack to park a byte the callee would not read as an
             * argument.  ufs.mod's vfs_import.s says the same thing about its
             * own hand-written shims. */
            emit_m8();
            ir_emitf("                LDA     %s+2\n", po);
            ir_emitf("                PHA\n");
            ir_emitf("                PLB\n");                 /* DBR = callee's */
            ir_emitf("                LDA     %s+2\n", po);    /* target bank */
            ir_record_raw(IR_PUSH_A, 0, 0, NULL);
            emit_m16();
        } else {
            emit_m8();
            ir_emitf("                LDA     %s+2\n", po);    /* target bank */
            ir_record_raw(IR_PUSH_A, 0, 0, NULL);
            emit_m16();
        }
        ir_emitf("                LDA     %s\n", po);          /* target offset */
        ir_emitf("                DEC\n");
        ir_record_raw(IR_PUSH_A, 0, 0, NULL);                     /* offset-1 on top */
        ir_emitf("                RTL\n");
    }
    ir_emitf("%s_L%d\n", g_tu_prefix, lab_r);
    if (g_module_bank || g_kernel_bank) {
        /* Our own DBR back, recovered from the program bank -- see above. */
        ir_emitf("                PHK\n");
        ir_emitf("                PLB\n");
    }
    /* g_expr_type set by caller from the fn-ptr's signature. */
}

void
emit_drop_args(int n_args)
{
    /* PLA reads the popped value into A, which would clobber the
     * callee's return value.  Stash A in Y across the cleanup.
     * (Y is dead at every call site: expression eval uses A only.) */
    if (n_args > 0) {
        ir_record_raw(IR_TAY, 0, 0, NULL);
        for (int i = 0; i < n_args; i++) {
            ir_record_raw(IR_POP_A, 0, 0, NULL);
        }
        ir_record_raw(IR_TYA, 0, 0, NULL);
    }
    g_s_delta -= 2 * n_args;
}

/* RTL-ABI: lower IR_ADDR_PARAM — the SP-relative address of a hardware-stack
 * PARAM, using the u0 g_s_delta snapshot so the arg reversal tracks.  Byte-
 * identical to the raw sequence emit_addr_of_local's param branch emitted.
 *
 * Campaign 1.3 audit: this needs NO soft arm, and that is structural rather
 * than a judgement call.  Its only two callers are emit_addr_of_local's
 * `else if (ir_recording())` / `else` arms, both of which sit behind
 * `if (lc->kind == LK_LOCAL)` -- so lc is a PARAM here by construction, and
 * params keep their hardware slot in 1.3.  The assert makes that a checked
 * invariant instead of a comment that rots the first time the dispatch moves. */
static void
emit_addr_param_lower(Local *lc, int s_delta)
{
    if (lc->kind == LK_LOCAL)
        die(g_cur.line, g_cur.col,
            "internal: emit_addr_param_lower reached with a LOCAL");
    int saved = g_s_delta;
    g_s_delta = s_delta;
    ir_emitf("                SEP     #$20\n");
        ir_emitf("                MX      %%10\n");
    ir_emitf("                LDA     #0\n");
    ir_emitf("                STA     _fcc_ptr+2\n");
    ir_emitf("                REP     #$20\n");
        ir_emitf("                MX      %%00\n");
    ir_emitf("                TSC\n");
    ir_emitf("                CLC\n");
    /* slot_addr_str returns "N+FRAMESIZE" for params (SP-relative). */
    ir_emitf("                ADC     #%s\n", slot_addr_str(lc, 0));
    g_s_delta = saved;
}

void
emit_addr_of_local(Local *lc)
{
    /* fcc2 P1.3-inc2: the local's address escapes -> its stack slot is its
     * identity; it cannot live in a DP-IMG register.  Disqualify promotion. */
    lc->addr_taken = 1;
    /* Long-pointer carrying convention: A = offset, _fcc_ptr+2 = bank. */
    if (lc->kind == LK_LOCAL) {
        /* &local: A = frame base + frame_off (2*slot_first), bank = whichever
         * bank the frame lives in.  Hardware frame -> _fcc_fb, bank 0 (P3-3
         * 3.3).  SOFT frame (campaign 1.3) -> _fcc_sfp, bank = DBR, the task's
         * data bank.
         *
         * This is the PRIMARY mint of a frame address: emit_load_base routes
         * EVERY array/struct access on a local through it.  The 1.3 core missed
         * it -- it staged a constant 0 bank, so &local inside a soft function
         * named bank 0 while the storage sat in the data bank.  M35/p33_recurse
         * could not see that: fib and fact take no addresses. */
        emit_stage_frame_bank("_fcc_ptr+2");
        ir_record_raw(IR_LDA_CELL, 0, 0,
                      (void *)cellp(g_fn_is_soft ? "_fcc_sfp" : "_fcc_fb"));
        ir_record_raw(IR_ADD_CONST, (unsigned)(2 * lc->slot_first), 0, NULL);
    } else if (ir_recording()) {
        /* Hardware stack (params): bank 0.  RTL-ABI: structured so the arg
         * reversal can adjust the g_s_delta snapshot (the ADC bakes the SP-
         * relative param address = retn+1+off+g_s_delta). */
        ir_record_op_ptr1(IR_ADDR_PARAM, lc, (unsigned)g_s_delta);
    } else {
        emit_addr_param_lower(lc, g_s_delta);   /* replay-time (never, but safe) */
    }
    /* B-3: &x increments pointer depth.  &arr decays to a pointer-to-
     * element (peel ARY, push PTR); &scalar / &pointer push a PTR onto
     * the operand type (so &(char*) is char**, not the old int*). */
    if (ISARY(lc->type))
        g_expr_type = INCREF(DECREF(lc->type), DERIV_PTR);
    else
        g_expr_type = INCREF(lc->type, DERIV_PTR);
    g_expr_struct_id = lc->struct_id;
}

/* Load the 4-byte far-pointer VALUE at [_fcc_ptr] into FPR k: offset word
 * + loader-patched bank byte (pad normalized to 0).  A = offset on return.
 * P3-2.7: the air/airg ptr-element loads hand the result to the walker in
 * an FPR — the old emit_load_ptr_value_via_fcc_ptr carrier handoff
 * (A + _fcc_ptr+2 bridged by fpr_in at the arm) is retired. */
void
emit_fpr_load_ptr_at_fcc_ptr(int k)
{
    ir_emitf("                LDY     #2\n");
    ir_record_raw(IR_LDA_DEREF, 1, 0, (void *)cellp("_fcc_ptr"));   /* bank byte (+stale pad) */
    ir_emitf("                AND     #$00FF\n");
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(fpr_name(k)));
    ir_record_raw(IR_LDA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));     /* A = offset word */
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
}

void
emit_deref_result_via_fcc_ptr(tword result)
{
    if (ISPTR(result)) {
        /* Faithful 4-byte pointer pointee (offset + loader-patched bank).
         * Self-contained deref-postinc lowering: the pointer result stays
         * on A+_fcc_ptr+2 within this one statement and the walker arm
         * bridges it into an FPR immediately (fpr_in).  Converts with the
         * postinc IR family at P3-3 (the soft-stack flip rewrites these
         * lowerings wholesale). */
        ir_record_raw(IR_LDA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));     /* offset word */
        ir_record_raw(IR_PUSH_A, 0, 0, NULL);
        emit_m8();
        ir_emitf("                LDY     #2\n");
        ir_record_raw(IR_LDA_DEREF, 1, 0, (void *)cellp("_fcc_ptr"));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));      /* runtime bank */
        emit_m16();
        ir_record_raw(IR_POP_A, 0, 0, NULL);                     /* A = offset */
        g_expr_type = result;
        return;
    }
    /* B-6: 4-byte scalar pointee (long* / float*).  Read the full 32 bits:
     * high word via [dp],Y (Y=2), low word via [dp].  Was a single 16-bit
     * [_fcc_ptr] read + int tag, which dropped the high word and broke
     * `*(long*)p` / `*(float*)p` (relevant to od/hd float dumps). */
    if (BTYPE(result) == BT_LONG || BTYPE(result) == BT_FLOAT) {
        ir_emitf("                LDY     #2\n");
        ir_record_raw(IR_LDA_DEREF, 1, 0, (void *)cellp("_fcc_ptr"));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
        ir_record_raw(IR_LDA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));
        g_expr_type = result;
        return;
    }
    ir_record_raw(IR_LDA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));
    if (BTYPE(result) == BT_CHAR || BTYPE(result) == BT_VOID) {
        ir_emitf("                AND     #$00FF\n");
        g_expr_type = LT_CHAR;
    } else {
        g_expr_type = LT_INT;             /* int / long-low; matches old behavior */
    }
}

/* fcc2 P1.4 (B1a): the g_expr_type a deref of pointee-type `result` yields —
 * MIRRORS the g_expr_type assignments in emit_deref_result_via_fcc_ptr so the
 * record-stub can set the parser-visible type WITHOUT emitting.  Keep in sync
 * with that function. */
tword
deref_result_expr_type(tword result)
{
    if (ISPTR(result))
        return result;
    if (BTYPE(result) == BT_LONG || BTYPE(result) == BT_FLOAT ||
        BT_IS_QUAD(BTYPE(result)))
        return result;
    if (BTYPE(result) == BT_CHAR || BTYPE(result) == BT_VOID)
        return LT_CHAR;
    return LT_INT;
}

/* fcc2 P1.4 (B1a): structured record-stub for `*<pointer local>`.  Sets the
 * parser-visible side effects (g_expr_type, g_expr_unsigned) at RECORD time,
 * then records ONE IR_DEREF_LOCAL whose lowering (emit_deref_local_lower) re-
 * emits the exact bytes.  Lifting the deref from IR_TEXT gives the promotion
 * pass an opcode to recognize/rewrite (B1b -> LDA [_fcc_img{k}]); for B1a it is
 * a BB barrier (see ir_is_bb_barrier) so the partition stays byte-identical.
 *
 * u0 = g_s_delta snapshot (the 4-byte pointer's n,S offsets, SP-dependent);
 * u1 = result tword (pointee type, drives the widen/mask). */
void
emit_deref_fast(Local *lc)
{
    tword result = DECREF(lc->type);     /* type of *lc */
    if (g_loop_depth) lc->loop_accessed = 1;   /* P1.4 B1b: gates pointer-PARAM promotion */
    /* A-1: a deref yields the pointee, whose signedness fcc records in the
     * pointer local's is_unsigned (the 'unsigned' qualifier from a decl like
     * `unsigned short *p`).  Propagate it so a following (long)/widening
     * zero-extends an unsigned pointee instead of sign-extending. */
    g_expr_type     = deref_result_expr_type(result);
    g_expr_unsigned = lc->is_unsigned;
    ir_record_op_ptr2(IR_DEREF_LOCAL, lc, (unsigned)g_s_delta, (unsigned)result);
}

/* Lowering of IR_DEREF_LOCAL.  BYTE-IDENTICAL to the prior inline emit_deref_fast
 * body: load the 4-byte pointer (offset @ slot+0, bank @ slot+2) to _fcc_ptr,
 * then deref.  slot_addr_str/emit_slot_lda16 use g_s_delta, so restore the
 * snapshot around them (as emit_load_local_lower does); emit_deref_result_via_
 * fcc_ptr reads only _fcc_ptr (no g_s_delta).  Its g_expr_type write at replay
 * is harmless (the parser already consumed the record-time value). */
static void
emit_deref_local_lower(Local *lc, int s_delta, tword result)
{
    int saved = g_s_delta;
    g_s_delta = s_delta;
    emit_slot_lda16(lc, 0);
    ir_emitf("                STA     _fcc_ptr\n");
    emit_slot_lda16(lc, 2);
    ir_emitf("                STA     _fcc_ptr+2\n");
    g_s_delta = saved;
    emit_deref_result_via_fcc_ptr(result);
}

void
emit_deref_general(void)
{
    /* Deref the pending pointer: A = offset, _fcc_ptr+2 = bank.
     * Store offset to _fcc_ptr+0, then deref (4-byte ptr or scalar). */
    tword result = DECREF(g_expr_type);
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
    emit_deref_result_via_fcc_ptr(result);
}

void
emit_deref_store(void)
{
    /* Caller pushed 4-byte long-pointer (offset @ 1,S, bank+pad @ 3,S);
     * A holds RHS.  Stash A, load 24-bit ptr to _fcc_ptr, store via
     * STA [_fcc_ptr], drop the 4-byte slot. */
    ir_record_raw(IR_TAY, 0, 0, NULL);
    ir_emitf("                LDA     1,S\n");
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
    ir_emitf("                LDA     3,S\n");
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
    ir_record_raw(IR_TYA, 0, 0, NULL);
    ir_record_raw(IR_STA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));
    ir_record_raw(IR_POP_A, 0, 0, NULL);
    ir_record_raw(IR_POP_A, 0, 0, NULL);
    ir_record_raw(IR_TYA, 0, 0, NULL);   /* A-preserving: stored value back in A (chained a[i]=b[i]=v) */
    g_s_delta -= 4;
}

void
emit_deref_store_long(tword target)
{
    /* B-6: store a 4-byte long/float through a pointer.  Caller pushed the
     * 4-byte dest long-ptr (offset @ 1,S, bank @ 3,S); A (+_fcc_long_hi for a
     * long/float RHS) holds the value.  Promote an int/char RHS first:
     * itof for a float target, zero-extend for a long target. */
    if (BTYPE(target) == BT_FLOAT &&
        (g_expr_type == LT_INT || g_expr_type == LT_CHAR)) {
        emit_itof_rt();
    } else if (g_expr_type == LT_INT || g_expr_type == LT_CHAR) {
        /* Promote int/char RHS to the long high word.  SIGNED sign-extends
         * (A holds the low word; _fcc_long_from_int preserves A); UNSIGNED
         * zero-extends.  Was an unconditional zero-extend, which stored
         * `*p = -1` as 0x0000FFFF. */
        if (g_expr_unsigned) {
            ir_emitf("                LDX     #0\n");
            ir_emitf("                STX     _fcc_long_hi\n");
        } else {
            emit_jsr_rt("_fcc_long_from_int");
        }
    }
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* RHS low word */
    ir_emitf("                LDA     1,S\n");
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
    ir_emitf("                LDA     3,S\n");
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
    ir_record_raw(IR_STA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));   /* low @ +0 */
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
    ir_emitf("                LDY     #2\n");
    ir_record_raw(IR_STA_DEREF, 1, 0, (void *)cellp("_fcc_ptr")); /* high @ +2 */
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* result = value low */
    ir_record_raw(IR_POP_A, 0, 0, NULL);
    ir_record_raw(IR_POP_A, 0, 0, NULL);
    g_s_delta -= 4;
}

void
emit_deref_store_byte(void)
{
    ir_record_raw(IR_TAY, 0, 0, NULL);
    ir_emitf("                LDA     1,S\n");
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
    ir_emitf("                LDA     3,S\n");
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
    ir_record_raw(IR_TYA, 0, 0, NULL);
    emit_m8();
    ir_record_raw(IR_STA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));
    emit_m16();
    ir_record_raw(IR_POP_A, 0, 0, NULL);
    ir_record_raw(IR_POP_A, 0, 0, NULL);
    ir_record_raw(IR_TYA, 0, 0, NULL);   /* A-preserving: stored value back in A (chained a[i]=b[i]=v) */
    g_s_delta -= 4;
}

void
emit_deref_store_ptr(void)
{
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* RHS offset */
    emit_load_value_bank();                                 /* RHS bank (bare NULL/0 -> 0) */
    ir_record_raw(IR_PUSH_A, 0, 0, NULL);                  /* save (dest now @ 3,S/5,S) */
    ir_emitf("                LDA     3,S\n");          /* dest offset */
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
    ir_emitf("                LDA     5,S\n");          /* dest bank */
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* RHS offset */
    ir_record_raw(IR_STA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));   /* store offset word */
    ir_record_raw(IR_POP_A, 0, 0, NULL);                  /* RHS bank (dest back @ 1,S/3,S) */
    ir_emitf("                LDY     #2\n");
    emit_m8();
    ir_record_raw(IR_STA_DEREF, 1, 0, (void *)cellp("_fcc_ptr")); /* store bank byte */
    emit_m16();
    ir_record_raw(IR_POP_A, 0, 0, NULL);                  /* drop dest offset */
    ir_record_raw(IR_POP_A, 0, 0, NULL);                  /* drop dest bank */
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));   /* result = RHS offset */
    g_s_delta -= 4;
}

void
emit_deref_store_dispatch(LocalType ptr_type)
{
    tword target = DECREF(ptr_type);
    if (ISPTR(target))
        emit_deref_store_ptr();
    else if (BTYPE(target) == BT_CHAR || BTYPE(target) == BT_VOID)
        emit_deref_store_byte();
    else if (BTYPE(target) == BT_LONG || BTYPE(target) == BT_FLOAT)
        emit_deref_store_long(target);     /* B-6: 4-byte store */
    else
        emit_deref_store();
}

void
emit_soft_local_store_ptr(void)
{
    /* value in A, element offset at 1,S (MX %00).  Stage {frame bank, offset}
     * in _fcc_ptr, re-staged here because parse_expr may have clobbered
     * _fcc_ptr+2 since emit_load_base.  The bank was a hardcoded 0 until
     * campaign 1.3 gave soft frames a data-bank home (apple/fgx#12). */
    ir_record_raw(IR_TAY, 0, 0, NULL);                 /* value -> Y */
    ir_emitf("                LDA     1,S\n");          /* element offset */
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
    emit_stage_frame_bank("_fcc_ptr+2");
    ir_record_raw(IR_TYA, 0, 0, NULL);                 /* value -> A */
}

void
emit_load_base(Local *lc)
{
    if (lc->type == LT_INT_ARRAY || lc->type == LT_CHAR_ARRAY ||
        lc->type == LT_LONG_ARRAY || lc->type == LT_FLOAT_ARRAY ||
        is_ptr_array(lc->type)) {
        /* D-1: long arrays were mistaken for ptrs.  FLOAT_ARRAY joined here so
         * its base is a real address with the bank staged in _fcc_ptr+2 (needed
         * for soft-stack element access — see emit_array_index_read soft_arr).
         * Ptr-element arrays (char *v[4]) joined at P3-2.6: the array is
         * in-frame like any other, its 4-byte elements read/store far-ptr
         * shaped (was mis-loaded as a scalar slot value — ptr_typedef). */
        emit_addr_of_local(lc);
    } else {
        emit_load_local(lc);
    }
}

/* Increment 3a split: the emission halves of emit_index_ptr_value, callable
 * from the AST walker with the index expression walked between them.  The
 * token-consuming wrapper below keeps the historical shape for the
 * parse-and-emit callers; emission is byte-identical. */
int
ipv_elem_size(LocalType pt)
{
    /* Element size = stride of one pointee.  ptr_stride handles char/void ptr
     * = 1, int ptr = 2, long ptr = 4, AND pointer-to-pointer (e.g. LINE**) = 4
     * -- the last of which the old `else: 2` got wrong, halving every T**
     * subscript stride (broke vi's LinePointers[]).
     *
     * A STRUCT POINTER DIES HERE RATHER THAN SUBSTITUTING (apple/fgx#166).
     * ptr_stride returns 0 for one BY DESIGN -- its own default arm says
     * "struct handled by elem_size_for" -- and this function does not have the
     * struct_id that would let it ask.  The old `if (es == 0) es = 2` is the
     * #154 shape: a sentinel meaning "I don't know" papered over at the
     * caller, which produces a pointer that is wrong by a factor of
     * sizeof(struct)/2 with no diagnostic at all.
     *
     * It is unreachable today -- every struct-pointer route into here is
     * parse-rejected -- and that is exactly why it is worth arming: the
     * defence is incidental, nothing states it, and a parser relaxation would
     * silently turn it into a wild pointer.  #163's two halves masked each
     * other for the same reason. */
    int es = ptr_stride(pt);
    if (es == 0)
        die(g_cur.line, g_cur.col,
            "internal: subscripting a struct pointer here has no known stride "
            "(apple/fgx#166) -- route it through elem_size_for");
    return es;
}

/* Increment 3a split: one dimension's index scale (walk-callable). */
void
emit_cio_scale(int stride)
{
    /* apple/fgx#166.  A zero stride is not "do not scale", it is "nobody knew":
     * the arms below would fall through to the multiply and emit `LDA #0`,
     * which zeroes the index so every element reads as element 0.  Catch it
     * where the value is used rather than at each of the places that compute
     * one. */
    if (stride == 0)
        die(g_cur.line, g_cur.col,
            "internal: index scale of 0 (apple/fgx#166)");
    emit_index_scale((unsigned)stride);
}

/* Increment 3a split: emit_array_index_read decomposes into the base-load
 * HEAD (returns the ir snapshot that brackets the index evaluation), the
 * index chain (the token wrapper uses emit_chained_index_offset; the AST
 * walker replays captured index subtrees), and the typed-element TAIL. */
int
air_row_stride(Local *lc)
{
    int row_stride = lc->row_stride;
    /* B-3: indexing a 1-D pointer (p[i]) — element size is the pointee
     * size, which for a depth->=2 pointer is 4 (the element is itself a
     * 4-byte pointer).  Guard on n_dims<=1 so multi-dim array params
     * (pointer-typed but with a real row_stride) keep their row stride. */
    if (ISPTR(lc->type) && lc->n_dims <= 1) row_stride = ptr_stride(lc->type);
    /* AND A STRUCT POINTER DIES (apple/fgx#166), for the reason ipv_elem_size
     * gives.  Here the substitute was not even a guess: ptr_stride's 0 would
     * reach emit_cio_scale, which emitted `LDA #0 / JSR _fcc_mul16` and ZEROED
     * the index -- every element of the array read as element 0.  symtab.c
     * records row_stride = 2 for a struct-pointer GLOBAL, which is the same
     * substitution one layer down and is why the two looked consistent. */
    if (row_stride == 0)
        die(g_cur.line, g_cur.col,
            "internal: indexing a struct pointer here has no known row stride "
            "(apple/fgx#166) -- route it through elem_size_for");
    return row_stride;
}

int
emit_air_head(Local *lc)
{
    emit_load_base(lc);
    emit_push_a();                          /* base @ 1,S */
    return ir_cur_n();                      /* B1c-2b: scan the index eval's ops */
}

/* A pointer base's bank waits in _fcc_ptr+2 while its index is evaluated
 * (emit_load_base, emit_load_global).  A call in the index may reuse
 * _fcc_ptr -- `digs[f(x)]', 4.3BSD-Reno doprnt.c's quad digits -- so the
 * bank is staged again from the pointer itself, local or global.  A is
 * kept. */
void
emit_restage_base_bank(Local *lc, Global *gv)
{
    ir_record_raw(IR_TAY, 0, 0, NULL);
    if (lc) {
        emit_slot_lda16(lc, 2);
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
    } else {
        emit_m8();
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp2(gname(gv)));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
        emit_m16();
    }
    ir_record_raw(IR_TYA, 0, 0, NULL);
}

int
emit_air_tail(Local *lc, int idx_snap, int consumed)
{
    int is_byte = (lc->type == LT_CHAR_ARRAY ||
                   lc->type == LT_CHAR_PTR  ||
                   lc->type == LT_VOID_PTR);
    int n_dims = lc->n_dims;
    if (consumed < n_dims) {
        /* Partial decay: 2D → row pointer.  3D+ partial unsupported. */
        if (n_dims != 2 || consumed != 1)
            die(g_cur.line, g_cur.col,
                "3D+ partial decay not supported (use full chain)");
        /* A = row offset; add base to get row addr, homed in an FPR
         * (P3-2.7).  The bank is RE-STAGED from its authoritative source
         * — the old carrier handoff trusted _fcc_ptr+2 to survive the
         * index walk since emit_load_base, which a call in the index
         * expression silently clobbered (same hazard class as the 2.6
         * ptr-array re-stage). */
        int k = fpr_alloc();
        ir_emitf("                CLC\n");
        ir_emitf("                ADC     1,S\n");
        ir_record_raw(IR_TAY, 0, 0, NULL);
        ir_record_raw(IR_POP_A, 0, 0, NULL);
        g_s_delta -= 2;
        ir_record_raw(IR_TYA, 0, 0, NULL);
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
        emit_m8();
        if (lc->kind == LK_LOCAL) {
            /* One of the three sites that MINT a frame address; all three now go
             * through emit_frame_bank_a, which is the only place that knows a
             * soft frame's bank is _fcc_sfp+2 rather than DBR or 0.  The `,S`
             * arm below is unreachable for a LOCAL, so this branch is the whole
             * of the local story. */
            emit_frame_bank_a();
        } else {
            /* ptr param bank.  Bare n,S (no DO far-gate) is fail-closed: a
             * >255 displacement is a LOUD merlin error (8-bit operand), never
             * silent corruption — g53 history proves it.  Annotated for the
             * stack-check d/b cross-check.  Params stay on the hardware stack
             * in 1.3, so there is nothing soft to branch on. */
            ir_emitf("                LDA     %s,S%s\n",
                     slot_addr_str(lc, 2), slot_annot(lc, 2));
        }
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(fpr_name(k)));
        ir_emitf("                STZ     %s+3\n", fpr_name(k));
        emit_m16();
        if (is_byte) g_expr_type = LT_CHAR_PTR;
        else         g_expr_type = LT_INT_PTR;
        return k;
    }
    /* fcc2 P1.4 (B1c-2b): scalar int/char/void pointer p[i] read -> lift to
     * IR_INDEX_DEREF_LOCAL so a promoted pointer can deref via [_fcc_img{k}],Y.
     * Excludes: long/float ptr + 2D partial-decay (returned earlier), ptr-to-ptr
     * element (ISPTR(elem)), multi-dim pointer params (n_dims>1), and local arrays
     * (the `else` LDAL arm).  base_mut: a STRUCTURED mutation of lc in the index
     * sub-expr disqualifies promotion (the promoted [img],Y would read the post-
     * mutation offset; C reads p's pre-index value).  A RAW mutation instead sets
     * lc->raw_accessed, which the promotion tally already excludes -> the two
     * together fully cover index-mutates-base.  Un-promoted lowering is byte-
     * identical to the tail below. */
    if (ISPTR(lc->type) && lc->n_dims <= 1 &&
        !ISPTR(DECREF(lc->type)) &&
        lc->type != LT_LONG_PTR && lc->type != LT_FLOAT_PTR) {
        int base_mut = ir_local_mutated_since(idx_snap, (void *)lc);
        int called   = ir_call_since(idx_snap);
        g_s_delta -= 2;                                  /* matches the PLA in the lowering */
        g_expr_type     = is_byte ? LT_CHAR : LT_INT;
        g_expr_unsigned = lc->is_unsigned;   /* A-1: elem inherits decl */
        if (called) lc->raw_accessed = 1;    /* the lowering reads its slot */
        ir_record_op_ptr2(IR_INDEX_DEREF_LOCAL, lc, (unsigned)g_s_delta,
                          (unsigned)((is_byte ? 1u : 0u) | (base_mut ? 2u : 0u) |
                                     (called ? 4u : 0u)));
        return -1;
    }
    ir_emitf("                CLC\n");
    ir_emitf("                ADC     1,S\n");
    /* M20: long-element arrays/pointers — load both 16-bit halves.
     * For LT_LONG_ARRAY local (bank-0 stack), LDAL pair.  For
     * LT_LONG_PTR (bank-aware), [_fcc_ptr] pair. */
    int soft_arr = lc->kind == LK_LOCAL &&
                   (lc->type == LT_LONG_ARRAY || lc->type == LT_FLOAT_ARRAY);
    if ((lc->type == LT_LONG_ARRAY || lc->type == LT_FLOAT_ARRAY) && !soft_arr) {
        /* hard-stack local long/float array (bank-0 stack): LDAL pair. */
        ir_record_raw(IR_TAX, 0, 0, NULL);
        ir_record_raw(IR_POP_A, 0, 0, NULL);
        g_s_delta -= 2;
        ir_emitf("                LDAL    $000002,X\n");
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
        ir_emitf("                LDAL    $000000,X\n");
        g_expr_type = (lc->type == LT_FLOAT_ARRAY) ? LT_FLOAT : LT_LONG;
        return -1;
    }
    if (soft_arr) {
        /* local long/float array: the element lives in the bank-0 frame.  Stage
         * bank = 0 explicitly (clobber-proof; emit_load_base stages it for LONG
         * but the re-stage keeps FLOAT correct too), then bank-aware [_fcc_ptr]
         * pair. */
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
        ir_record_raw(IR_POP_A, 0, 0, NULL);
        g_s_delta -= 2;
        emit_stage_frame_bank("_fcc_ptr+2");
        ir_record_raw(IR_LDA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_b_lo"));
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
        ir_emitf("                CLC\n");
        ir_emitf("                ADC     #2\n");
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
        ir_record_raw(IR_LDA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_b_lo"));
        g_expr_type = (lc->type == LT_FLOAT_ARRAY) ? LT_FLOAT : LT_LONG;
        return -1;
    }
    if (lc->type == LT_LONG_PTR || lc->type == LT_FLOAT_PTR) {
        /* B-6 bank-aware pair (bank from the loaded pointer value in _fcc_ptr+2). */
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
        ir_record_raw(IR_POP_A, 0, 0, NULL);
        g_s_delta -= 2;
        if (ir_call_since(idx_snap)) emit_restage_base_bank(lc, NULL);
        ir_record_raw(IR_LDA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_b_lo"));
        /* Re-load with +2 offset for high word. */
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
        ir_emitf("                CLC\n");
        ir_emitf("                ADC     #2\n");
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
        ir_record_raw(IR_LDA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_b_lo"));
        g_expr_type = (lc->type == LT_FLOAT_PTR) ? LT_FLOAT : LT_LONG;
        return -1;
    }
    /* For pointer-typed bases (incl. multi-dim array params), the
     * base points into own-bank or another bank, not bank-0.  Use
     * bank-aware [_fcc_ptr] indirect-long (bank already in
     * _fcc_ptr+2 from emit_load_base).  For LT_*_ARRAY locals
     * (1D-on-stack), bank-0 LDAL is correct (stack lives in bank 0). */
    if (ISPTR(lc->type)) {                  /* B-3: any-depth pointer base */
        tword elem = DECREF(lc->type);
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
        ir_record_raw(IR_POP_A, 0, 0, NULL);
        g_s_delta -= 2;
        if (ir_call_since(idx_snap)) emit_restage_base_bank(lc, NULL);
        if (ISPTR(elem)) {                  /* element is itself a pointer → 4-byte load */
            int k = fpr_alloc();
            emit_fpr_load_ptr_at_fcc_ptr(k);
            g_expr_type = elem;
            g_expr_unsigned = 0;
            return k;
        }
        ir_record_raw(IR_LDA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));
    } else if (lc->kind == LK_LOCAL) {
        /* local array: the element lives in the bank-0 frame (bank staged 0 in
         * _fcc_ptr+2 via emit_load_base -> emit_addr_of_local).  Deref bank-aware
         * via [_fcc_ptr], mirroring the pointer path above, rather than bank-0
         * LDAL $000000,X (the hard-stack arm below): the [_fcc_ptr] form stays
         * correct when the array is also touched via a far pointer (e.g. memcpy
         * into a local array). */
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
        ir_record_raw(IR_POP_A, 0, 0, NULL);
        g_s_delta -= 2;
        if (is_ptr_array(lc->type)) {
            /* Ptr-element local array (char *v[4]): the element is a 4-byte
             * far pointer — re-stage the soft-stack bank (the index expr may
             * have clobbered _fcc_ptr+2 since emit_load_base) and load the
             * full {offset, stored bank}.  P3-2.6 (ptr_typedef). */
            emit_stage_frame_bank("_fcc_ptr+2");
            int k = fpr_alloc();
            emit_fpr_load_ptr_at_fcc_ptr(k);
            g_expr_type      = DECREF(lc->type);
            g_expr_unsigned  = 0;
            g_expr_struct_id = -1;
            return k;
        }
        ir_record_raw(IR_LDA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));
    } else {
        ir_record_raw(IR_TAX, 0, 0, NULL);
        ir_record_raw(IR_POP_A, 0, 0, NULL);
        g_s_delta -= 2;
        ir_emitf("                LDAL    $000000,X\n");
    }
    if (is_byte) {
        ir_emitf("                AND     #$00FF\n");
        g_expr_type = LT_CHAR;
    } else {
        g_expr_type = LT_INT;
    }
    /* A-1: set AFTER the index parse (which may have flipped the flag for
     * an unsigned index); the element inherits the array/ptr decl's
     * signedness. */
    g_expr_unsigned = lc->is_unsigned;
    return -1;
}

int
emit_airg_tail(Global *gv, int consumed)
{
    refuse_block_static(gv, "emit_airg_tail");
    int is_byte = (gv->type == LT_CHAR_ARRAY);
    int n_dims = gv->n_dims;
    if (consumed < n_dims) {
        if (n_dims != 2 || consumed != 1)
            die(g_cur.line, g_cur.col,
                "3D+ partial decay not supported (use full chain)");
        /* Partial decay: return long-pointer to row.  Address = &gv
         * + A (offset).  The N-D array lives in the DATA segment, so the
         * row pointer's bank is the runtime DATA bank.  Single-bank FGX1
         * has PBR == DBR (PHK is fine); multi-bank FGX2 (g_data_out) must
         * use PHB (the runtime data bank) or the deref reads the wrong
         * 64K — the code bank — which silently dumps code as data (the
         * elvis `digtable[][4]` startup garble).  Mirrors
         * emit_addr_of_global. */
        int k = fpr_alloc();
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
        emit_m8();
        ir_emitf("                PHB\n");
        ir_record_raw(IR_POP_A, 0, 0, NULL);
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(fpr_name(k)));
        ir_emitf("                STZ     %s+3\n", fpr_name(k));
        emit_m16();
        ir_emitf("                LDA     #%s\n", gname(gv));
        ir_emitf("                CLC\n");
        ir_emitf("                ADC     _fcc_tmp_b\n");
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
        if (is_byte) g_expr_type = LT_CHAR_PTR;
        else         g_expr_type = LT_INT_PTR;
        return k;
    }
    ir_record_raw(IR_TAX, 0, 0, NULL);
    if (gv->type == LT_LONG_ARRAY || gv->type == LT_FLOAT_ARRAY) {  /* B-6 */
        /* M20/B-6: 4-byte indexed load — high first into _fcc_long_hi,
         * then low into A. */
        ir_emitf("                LDA:    %s+2,X\n", gname(gv));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
        ir_emitf("                LDA:    %s,X\n", gname(gv));
        g_expr_type = (gv->type == LT_FLOAT_ARRAY) ? LT_FLOAT : LT_LONG;
        return -1;
    }
    if (is_ptr_array(gv->type)) {
        /* M21/B-5: load element of T*[N] — 4-byte long pointer.
         *
         * Single-bank FGX1: the baked bank byte (DFB ^_Sn at link time)
         * is the link-ORG bank, NOT the runtime bank Bank_Alloc picked,
         * and there's no loader reloc.  Sidestep with PHK = runtime PB
         * (crt0 sets DBR = PB = own bank, so PHK matches any same-bank
         * pointer).
         *
         * Multi-bank FGX2 (g_data_out != NULL): each element's bank
         * byte is loader-patched via FGX2_LONG_PTR — read it directly
         * from gname+2,X.  PHK would give PB (code bank), but an
         * element can store a runtime-assigned pointer in any bank
         * (e.g. heap from malloc, args_input in DBR). */
        int k = fpr_alloc();
        emit_m8();
        ir_emitf("                LDA:    %s+2,X\n", gname(gv));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(fpr_name(k)));
        ir_emitf("                STZ     %s+3\n", fpr_name(k));
        emit_m16();
        ir_emitf("                LDA:    %s,X\n", gname(gv));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
        g_expr_type = DECREF(gv->type);   /* B-5: element ptr type (char ptr, int ptr) */
        g_expr_struct_id = -1;
        return k;
    }
    /* M21+: char *p (pointer global) — load pointer value then deref
     * with bank in _fcc_ptr+2.  Without this, gv->type LT_CHAR_PTR
     * fell into the array-style `LDA: gv,X` path which reads from the
     * pointer's storage instead of through the pointer. */
    if (gv->type == LT_CHAR_PTR || gv->type == LT_INT_PTR ||
        gv->type == LT_VOID_PTR) {
        int p_is_byte = (gv->type == LT_CHAR_PTR ||
                         gv->type == LT_VOID_PTR);
        /* X currently holds the index (from `TAX` above).  Save it to
         * _fcc_tmp_b, then compute (gv pointer value) + index. */
        ir_record_raw(IR_TXA, 0, 0, NULL);
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
        emit_m8();
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp2(gname(gv)));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
        emit_m16();
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp(gname(gv)));
        ir_emitf("                CLC\n");
        ir_emitf("                ADC     _fcc_tmp_b\n");
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
        ir_record_raw(IR_LDA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));
        if (p_is_byte) {
            ir_emitf("                AND     #$00FF\n");
            g_expr_type = LT_CHAR;
        } else {
            g_expr_type = LT_INT;
        }
        g_expr_unsigned = gv->is_unsigned;   /* A-1: elem inherits decl */
        return -1;
    }
    /* G52: pointer-to-pointer global indexed — e.g. `LINE **LinePointers`
     * (a malloc'd array of LINE*).  The is_ptr_array path above is for T*[N]
     * ARRAYS (inline storage); a real pointer-of-pointer must be DEREFERENCED
     * first: load gv's value (the array address), add i*4 (pointer element
     * size), then load the 4-byte element pointer.  Sets struct_id so a
     * following `->` chains (stevie's `LinePointers[idx]->next`).  Without
     * this fcc emitted `LDA: gv,X`, reading gv's own 4-byte storage as if it
     * were the array — wrong for any i. */
    if (ISPTR(gv->type) && ISPTR(DECREF(gv->type))) {
        tword elem = DECREF(gv->type);    /* element pointer type (e.g. LINE*) */
        /* The index in X was ALREADY scaled by row_stride (= 4, the ptr element
         * size) in emit_chained_index_offset, exactly like the char-ptr/int-ptr
         * paths above.  The old `ASL ASL` here re-scaled by 4 a second time ->
         * i*8 and broke every T** subscript (vi's LinePointers[]).  Just use it. */
        ir_record_raw(IR_TXA, 0, 0, NULL);          /* i * 4 (already scaled) */
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
        emit_m8();
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp2(gname(gv)));  /* gv value bank */
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
        emit_m16();
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp(gname(gv)));    /* gv value offset */
        ir_emitf("                CLC\n");
        ir_emitf("                ADC     _fcc_tmp_b\n");
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));         /* &gv[i] */
        int k = fpr_alloc();
        emit_fpr_load_ptr_at_fcc_ptr(k);     /* 4-byte element (offset+bank) */
        g_expr_type      = elem;
        g_expr_struct_id = (BTYPE(elem) == BT_STRUCT) ? gv->struct_id : -1;
        g_expr_unsigned  = 0;
        return k;
    }
    /* G59: long / float (4-byte scalar) POINTER global indexed, e.g.
     * `long *htab; htab[i]`.  Symmetric to the char/int/void pointer arm above
     * and the store-side is_ptr_target fix (parse_stmt.c): load gv's pointer
     * VALUE (offset+bank), add the pre-scaled index (i*4 already in X), then a
     * 4-byte deref.  Without this, gv->type LT_LONG_PTR fell to the `LDA: gv,X`
     * fallthrough which reads gv's OWN 4-byte storage as if it were the array,
     * off by i*4 bytes, scribbling the data seg / heap (compress's htab). */
    if (gv->type == LT_LONG_PTR || gv->type == LT_FLOAT_PTR) {
        ir_record_raw(IR_TXA, 0, 0, NULL);            /* i*4 (already scaled) */
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
        emit_m8();
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp2(gname(gv)));  /* ptr bank */
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
        emit_m16();
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp(gname(gv)));   /* ptr offset */
        ir_emitf("                CLC\n");
        ir_emitf("                ADC     _fcc_tmp_b\n");
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr")); /* &gv[i] */
        /* 4-byte deref, HIGH word first into _fcc_long_hi then LOW into A LAST
         * — mirrors the LT_LONG_ARRAY read (above) so the long-value consumer
         * pushes BOTH words.  Raw-emit the derefs (like the array path) so the
         * dead-store peephole can't drop the _fcc_long_hi feeder — an earlier
         * IR-op low-first form lost the high word (only the low was saved). */
        ir_emitf("                LDY     #2\n");
        ir_emitf("                LDA     [_fcc_ptr],Y\n");
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
        ir_emitf("                LDA     [_fcc_ptr]\n");
        g_expr_type = (gv->type == LT_FLOAT_PTR) ? LT_FLOAT : LT_LONG;
        g_expr_unsigned = 0;
        return -1;
    }
    ir_emitf("                LDA:    %s,X\n", gname(gv));
    if (is_byte) {
        ir_emitf("                AND     #$00FF\n");
        g_expr_type = LT_CHAR;
    } else {
        g_expr_type = LT_INT;
    }
    g_expr_unsigned = gv->is_unsigned;   /* A-1: elem inherits decl */
    return -1;
}

void
emit_stash_rhs(void)
{
    if (g_expr_type == LT_LONG || g_expr_type == LT_FLOAT) {  /* B-6: 4-byte */
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_b_lo"));
        ir_emitf("                LDX     _fcc_long_hi\n");
        ir_emitf("                STX     _fcc_long_b_hi\n");
        return;
    }
    ir_record_op(IR_STASH_RHS_INT);
}

void
emit_promote_a_to_long(void)
{
    if (g_expr_type == LT_DOUBLE) {
        emit_from_double(LT_LONG);
        return;
    }
    /* A-1: widen the 16-bit value in A to a 32-bit long.  A SIGNED int/char
     * sign-extends (high word $FFFF when negative); an UNSIGNED one zero-
     * extends (high word 0) — matching C integer-conversion rules.  This used
     * to sign-extend unconditionally, which corrupted (long)(unsigned short)
     * for values >= 0x8000 (od us_put hang).  The zero-extend mirrors the
     * inline form already used by emit_deref_store_long. */
    if (g_expr_unsigned) {
        ir_emitf("                LDX     #0\n");
        ir_emitf("                STX     _fcc_long_hi\n");
    } else {
        emit_jsr_rt("_fcc_long_from_int");
    }
    g_expr_type = LT_LONG;
    /* AND THE RESULT IS A SIGNED LONG.  K&R A.6.5 (p.160): an unsigned int
     * meeting a long "is converted to long int", a 32-bit long holding every
     * 16-bit value.  Leaving the flag set made `L /= U' an unsigned divide. */
    g_expr_unsigned = 0;
}

/* Bring the value just produced to long long form: A, _fcc_long_hi, _fcc_q2
 * and _fcc_q3 (docs/history/plans/2026-09-23-fcc-long-long-plan.md).  K&R
 * A.6.2's integral rule, applied to a type K&R does not have: a signed value
 * sign-extends and an unsigned one zero-fills.  A is preserved throughout --
 * it is already w0. */
/* Refuse what long double cannot do yet, rather than guess: a conversion
 * to or from long long, which the soft double has no routine for. */
void
refuse_double(const char *what)
{
    char m[160];
    snprintf(m, sizeof m, "double %s is not implemented yet "
             "(apple/fgx#447 increment 3)", what);
    die(0, 0, m);
}

/* Bring the value just produced to the form of an 8-byte target.  A long
 * long target widens it (emit_to_llong).  A long double target converts it
 * through the soft double (lib/libdouble/d_glue.s): an integer goes by value
 * (K&R A.6.3, "in the representable range"), first to a long of its own
 * signedness, and a float exactly (A.6.4: "the value is unchanged"). */
void
emit_to_quad(LocalType target)
{
    require_long_from_ptr_cast(target);
    if (target == LT_LLONG) {
        emit_to_llong();
        return;
    }
    if (g_expr_type == LT_DOUBLE)
        return;
    if (g_expr_type == LT_LLONG)
        refuse_double("conversion from long long");
    if (g_expr_type == LT_FLOAT) {
        emit_d_call("_fcc_dfromf");
    } else {
        if (g_expr_type != LT_LONG)             /* int, char: a long now holds */
            emit_promote_a_to_long();           /* it, signed, by its signedness */
        emit_d_call(g_expr_unsigned ? "_fcc_dfromul" : "_fcc_dfroml");
    }
    g_expr_type     = LT_DOUBLE;
    g_expr_unsigned = 0;
}

/* The long double just produced, converted to dst.  K&R A.6.3: "the
 * fractional part is discarded".  To a float the result "may be either the
 * next higher or the next lower representable value" (A.6.4); the soft
 * double's __truncdfsf2 takes the nearest, ties to even, as a static
 * initializer's constant does.  An
 * integral target takes _fcc_dtol's long, whose low word is an int. */
void
emit_from_double(LocalType dst)
{
    if (dst == LT_DOUBLE)
        return;
    if (dst == LT_LLONG)
        refuse_double("conversion to long long");
    if (ISPTR(dst) || dst == LT_STRUCT)
        die(0, 0, "a double cannot be converted to a pointer or a "
                  "struct");
    if (dst == LT_FLOAT) {
        emit_d_call("_fcc_dtof");
        g_expr_type = LT_FLOAT;
    } else {
        emit_d_call("_fcc_dtol");
        g_expr_type = LT_LONG;
    }
    g_expr_unsigned = 0;
}

void
emit_to_llong(void)
{
    if (g_expr_type == LT_LLONG)
        return;
    if (g_expr_type == LT_DOUBLE)
        refuse_double("conversion to long long");
    if (g_expr_type == LT_FLOAT)
        die(0, 0, "float to long long conversion is not implemented yet "
                  "(apple/fgx#447 increment 1d)");
    if (g_expr_type != LT_LONG) {               /* int, char: first to long */
        if (g_expr_unsigned) {
            ir_emitf("                LDX     #0\n");
            ir_emitf("                STX     _fcc_long_hi\n");
        } else {
            emit_jsr_rt("_fcc_long_from_int");
        }
    }
    if (g_expr_unsigned) {
        ir_emitf("                STZ     _fcc_q2\n");
        ir_emitf("                STZ     _fcc_q3\n");
    } else {
        /* w1's sign bit fills w2 and w3.  BIT sets N from bit 15 of the
         * 16-bit cell and leaves A alone. */
        ir_emitf("                LDX     #0\n");
        ir_emitf("                BIT     _fcc_long_hi\n");
        ir_emitf("                BPL     *+5\n");
        ir_emitf("                LDX     #$FFFF\n");
        ir_emitf("                STX     _fcc_q2\n");
        ir_emitf("                STX     _fcc_q3\n");
    }
    g_expr_type = LT_LLONG;
}

/* The int -> float and long -> float routine for the value just produced,
 * by ITS signedness (g_expr_unsigned).  K&R A.6.3 (p.159): an integral value
 * "in the representable range" converts by value, so an unsigned 40000 is
 * 40000.0 -- the signed routines read its top bit as a sign.  These emit the
 * call only; the store sites that use them keep their own g_expr_type. */
void
emit_itof_rt(void)
{
    if (g_expr_type == LT_DOUBLE) {
        emit_from_double(LT_FLOAT);
        return;
    }
    emit_jsr_rt(g_expr_unsigned ? "_fcc_utof" : "_fcc_itof");
}

void
emit_ltof_rt(void)
{
    emit_jsr_rt(g_expr_unsigned ? "_fcc_ultof" : "_fcc_ltof");
}

void
emit_int_to_float(void)
{
    if (g_expr_type == LT_DOUBLE) {
        emit_from_double(LT_FLOAT);
        return;
    }
    /* B-6: 16-bit int in A -> IEEE-754 single in (A:_fcc_long_hi). */
    emit_itof_rt();
    g_expr_type = LT_FLOAT;
    g_expr_unsigned = 0;
}

void
emit_float_to_int(void)
{
    /* B-6: IEEE-754 single in (A:_fcc_long_hi) -> signed 16-bit int in A. */
    emit_jsr_rt("_fcc_ftoi");
    g_expr_type = LT_INT;
}

void
emit_long_to_float(void)
{
    if (g_expr_type == LT_DOUBLE) {
        emit_from_double(LT_FLOAT);
        return;
    }
    /* B-6: 32-bit long in (A:_fcc_long_hi) -> IEEE-754 single. */
    emit_ltof_rt();
    g_expr_type = LT_FLOAT;
    g_expr_unsigned = 0;
}

void
emit_float_to_long(void)
{
    if (g_expr_type == LT_DOUBLE) {
        emit_from_double(LT_LONG);
        return;
    }
    /* B-6: IEEE-754 single in (A:_fcc_long_hi) -> signed 32-bit long. */
    emit_jsr_rt("_fcc_ftol");
    g_expr_type = LT_LONG;
}

void
emit_stash_long_to_b(void)
{
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_b_lo"));
    ir_emitf("                LDX     _fcc_long_hi\n");
    ir_emitf("                STX     _fcc_long_b_hi\n");
}

/* Is the usual-arithmetic-conversion result of (lt, lu) op (rt, ru)
 * unsigned?  K&R A.6.5 (p.160): a float operand makes it float, which is
 * signed.  "If one operand is long int and the other is unsigned int ... if
 * [a long can represent all values of an unsigned int], the unsigned int
 * operand is converted to long int" -- and a 32-bit long holds every 16-bit
 * value -- so with a long in play only an unsigned LONG makes it unsigned.
 * Otherwise "if either operand is unsigned int, the other is converted to
 * unsigned int". */
/* An operand's signedness after integral promotion.  K&R A.6.1 (p.159): "A
 * character ... either signed or not ... If an int can represent all the
 * values of the original type, then the value is converted to int" -- and an
 * int holds every unsigned char value, so an unsigned char operand is a
 * SIGNED int.  Its load still zero-extends: 200 is 200, and then an int. */
int
promoted_unsigned(LocalType t, int u)
{
    return u && t != LT_CHAR;
}

int
arith_unsigned(LocalType lt, int lu, LocalType rt, int ru)
{
    lu = promoted_unsigned(lt, lu);
    ru = promoted_unsigned(rt, ru);
    if (lt == LT_FLOAT || rt == LT_FLOAT)
        return 0;
    /* long long, the extension: one rung above long on the same ladder.  A
     * 64-bit long long holds every value of an unsigned long, so as with a
     * long above, only an unsigned LONG LONG makes the result unsigned. */
    if (lt == LT_LLONG || rt == LT_LLONG)
        return (lt == LT_LLONG && lu) || (rt == LT_LLONG && ru);
    if (lt == LT_LONG || rt == LT_LONG)
        return (lt == LT_LONG && lu) || (rt == LT_LONG && ru);
    return lu || ru;
}

void
emit_scalar_binop(LocalType lhs_type, LocalType rhs_type,
                  int lhs_unsigned, int rhs_unsigned, void (*fn)(void))
{
    /* LONG DOUBLE: A.6.5, "First, if either operand is long double, the
     * other is converted to long double."  The walker widened and pushed the left operand
     * already (a conversion calls the soft double, which uses the second-
     * operand cells, so it cannot run once the right operand is parked
     * there); the right one converts here, parks, and the left is popped. */
    if (lhs_type == LT_DOUBLE || rhs_type == LT_DOUBLE) {
        if (lhs_type != LT_DOUBLE)
            die(0, 0, "internal: a double operation's left operand was "
                      "not widened before it was pushed");
        g_expr_type = rhs_type;
        g_expr_unsigned = rhs_unsigned;
        emit_to_quad(LT_DOUBLE);
        emit_stash_llong_to_b();
        emit_pop_llong();
        g_expr_type = LT_DOUBLE;
        g_expr_unsigned = 0;
        g_binop_unsigned = 0;
        fn();
        return;
    }
    /* A-1: the usual arithmetic conversions decide whether the op is
     * unsigned (arith_unsigned).  The compare and divide-or-modulo emitters
     * read g_binop_unsigned to pick the unsigned runtime helper. */
    g_binop_unsigned = arith_unsigned(lhs_type, lhs_unsigned,
                                      rhs_type, rhs_unsigned);
    /* A SHIFT IS TYPED BY ITS PROMOTED LEFT OPERAND (A.7.8), not balanced:
     * `>>' is logical only when that operand is unsigned, and a count wider
     * than it is narrowed to its low word, which A already holds. */
    if (fn == emit_binop_shl || fn == emit_binop_shr) {
        g_binop_unsigned = promoted_unsigned(lhs_type, lhs_unsigned);
        if (lhs_type != LT_LONG && lhs_type != LT_LLONG &&
            (rhs_type == LT_LONG || rhs_type == LT_LLONG)) {
            rhs_type = LT_INT;
            rhs_unsigned = 0;
        }
    }
    /* long long.  A shift keeps its LEFT operand's type (A.7.8), so its
     * count is only narrowed: with a long long on the left the count's low
     * word goes to _fcc_long_b_lo; with a narrower left and a long long
     * count, the count's low word is already in A and the int/long shift
     * below runs as for an int count.  Everything else balances to long
     * long: the right operand widens in the accumulator and is stashed, the
     * left one is popped at its own width and widened. */
    if (lhs_type == LT_LLONG || rhs_type == LT_LLONG) {
        int is_shift = (fn == emit_binop_shl || fn == emit_binop_shr);
        if (lhs_type == LT_FLOAT || rhs_type == LT_FLOAT)
            die(0, 0, "long long meeting float is not implemented yet "
                      "(apple/fgx#447 increment 2)");
        if (is_shift) {
            ir_emitf("                STA     _fcc_long_b_lo\n");
            emit_pop_llong();
            g_expr_type = LT_LLONG;
            g_expr_unsigned = promoted_unsigned(LT_LLONG, lhs_unsigned);
            g_binop_unsigned = g_expr_unsigned;
            fn();
            return;
        } else {
            g_expr_type = rhs_type;
            g_expr_unsigned = promoted_unsigned(rhs_type, rhs_unsigned);
            emit_to_llong();
            emit_stash_llong_to_b();
            if (lhs_type == LT_LLONG) {
                emit_pop_llong();
            } else {
                if (lhs_type == LT_LONG) emit_pop_long();
                else                     emit_pop_a();
                g_expr_type = lhs_type;
                g_expr_unsigned = promoted_unsigned(lhs_type, lhs_unsigned);
                emit_to_llong();
            }
            g_expr_type = LT_LLONG;
            fn();
            if (g_expr_type == LT_LLONG)
                g_expr_unsigned = g_binop_unsigned;
            return;
        }
    }
    /* B-6: float arithmetic.  An int operand is promoted to float (itof);
     * the float is 4-byte so it reuses the long push/pop/stash plumbing
     * (value in A:_fcc_long_hi, RHS in _fcc_long_b_lo/hi). */
    if (lhs_type == LT_FLOAT || rhs_type == LT_FLOAT) {
        if (lhs_type == LT_FLOAT && rhs_type != LT_FLOAT) {
            /* RHS in A (int) or A:_fcc_long_hi (long) -> promote to float.
             * A LONG here took itof, which reads only A: the value
             * truncated to its low 16 bits (frotz's elapsed-time scale). */
            g_expr_unsigned = rhs_unsigned;
            if (rhs_type == LT_LONG) emit_long_to_float();
            else                     emit_int_to_float();
            rhs_type = LT_FLOAT;
        } else if (rhs_type == LT_FLOAT && lhs_type != LT_FLOAT) {
            /* LHS on stack is int (one word) or LONG (two): stash RHS, pop
             * the LHS at ITS OWN width, convert, push as float, restore
             * RHS.  The int-only pop here popped ONE word of a two-word
             * long: its high word stayed pushed forever -- the stack_check
             * "epilogue teardown at nonzero depth" on frotz dumb_input's
             * (time(0) - start_time) * 10 * speed -- and the itof read the
             * low half as the whole value.  (ltof/itof use _fcc_f_*
             * scratch, never _fcc_long_b_*, so the stash survives.) */
            emit_stash_long_to_b();
            g_expr_unsigned = lhs_unsigned;
            if (lhs_type == LT_LONG) {
                emit_pop_long();
                emit_long_to_float();
            } else {
                emit_pop_a();
                emit_int_to_float();
            }
            emit_push_long();
            ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_b_lo"));
            ir_emitf("                LDX     _fcc_long_b_hi\n");
            ir_emitf("                STX     _fcc_long_hi\n");
            lhs_type = LT_FLOAT;
        }
        g_expr_type = LT_FLOAT;
        emit_stash_rhs();        /* RHS float -> _fcc_long_b_lo/hi */
        emit_pop_long();         /* LHS float -> A:_fcc_long_hi (4-byte) */
        g_expr_type = LT_FLOAT;  /* binop fn dispatches on this */
        fn();
        g_expr_unsigned = 0;
        return;
    }
    /* THE INT OPERAND OF A LONG OP WIDENS BY ITS OWN SIGNEDNESS -- A.6.2's
     * "zero-filling unsigned values and sign-extending signed values" --
     * not by g_expr_unsigned, which describes whichever operand was walked
     * last. */
    if (lhs_type == LT_LONG && rhs_type != LT_LONG) {
        /* RHS in A is int → widen to long. */
        g_expr_unsigned = rhs_unsigned;
        emit_promote_a_to_long();
        rhs_type = LT_LONG;
    } else if (rhs_type == LT_LONG && lhs_type != LT_LONG) {
        /* LHS on stack is int.  Stash RHS, pop LHS, widen, push as
         * long, restore RHS. */
        emit_stash_long_to_b();
        emit_pop_a();
        g_expr_unsigned = lhs_unsigned;
        emit_promote_a_to_long();
        emit_push_long();
        /* Restore RHS into (A, _fcc_long_hi). */
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_b_lo"));
        ir_emitf("                LDX     _fcc_long_b_hi\n");
        ir_emitf("                STX     _fcc_long_hi\n");
        lhs_type = LT_LONG;
    }
    LocalType common = (lhs_type == LT_LONG) ? LT_LONG : LT_INT;
    g_expr_type = common;        /* emit_stash_rhs dispatches on this */
    emit_stash_rhs();
    if (common == LT_LONG) emit_pop_long();
    else                   emit_pop_a();
    g_expr_type = common;        /* binop fn dispatches on this */
    fn();
    /* A-1: result keeps the op's unsignedness (harmless for comparison
     * results, which are 0/1 bools). */
    g_expr_unsigned = g_binop_unsigned;
}

/* The constant k, already at its own width and sign (ast_const_int), as the
 * second operand of a long operation: widened as emit_promote_a_to_long would
 * widen it, through X, so A:_fcc_long_hi is untouched. */
void
emit_stage_long_b(long k)
{
    unsigned long v = (unsigned long)k;
    ir_emitf("                LDX     #%lu\n", v & 0xFFFFuL);
    ir_emitf("                STX     _fcc_long_b_lo\n");
    ir_emitf("                LDX     #%lu\n", (v >> 16) & 0xFFFFuL);
    ir_emitf("                STX     _fcc_long_b_hi\n");
}

/* A long operation whose right operand is the constant k: the left operand
 * stays in A:_fcc_long_hi and k goes straight to the second-operand cells,
 * with no push, pop or runtime widening between. */
void
emit_long_binop_const(int lhs_unsigned, LocalType rhs_type, int rhs_unsigned,
                      long k, void (*fn)(void))
{
    if (fn == emit_binop_shl || fn == emit_binop_shr)
        g_binop_unsigned = promoted_unsigned(LT_LONG, lhs_unsigned);
    else
        g_binop_unsigned = arith_unsigned(LT_LONG, lhs_unsigned,
                                          rhs_type, rhs_unsigned);
    emit_stage_long_b(k);
    g_expr_type = LT_LONG;
    fn();
    g_expr_unsigned = g_binop_unsigned;
}

/* Lower an int ALU tail (A = A <op> _fcc_tmp_b).  Reproduces the exact text of
 * the lifted emit_binop_* int paths. */
static void
emit_binop_lower(unsigned kind)
{
    switch ((IrBinKind)kind) {
    case IRBIN_ADD:
        ir_emitf("                CLC\n");
        ir_emitf("                ADC     _fcc_tmp_b\n");
        break;
    case IRBIN_SUB:
        ir_emitf("                SEC\n");
        ir_emitf("                SBC     _fcc_tmp_b\n");
        break;
    case IRBIN_BAND: ir_emitf("                AND     _fcc_tmp_b\n"); break;
    case IRBIN_BOR:  ir_emitf("                ORA     _fcc_tmp_b\n"); break;
    case IRBIN_BXOR: ir_emitf("                EOR     _fcc_tmp_b\n"); break;
    }
}

/* fcc2 isel Phase 1: emit `[CLC|SEC] <op> <operand>` for a folded load-op binop
 * (A = A <op> mem).  The leaf was never loaded into A, so A still holds the LHS;
 * operand order matches the un-folded `A <op> _fcc_tmp_b`. */
static void
emit_binop_mem_op(unsigned kind, const char *operand)
{
    switch ((IrBinKind)kind) {
    case IRBIN_ADD:  ir_emitf("                CLC\n");
                     ir_emitf("                ADC     %s\n", operand); break;
    case IRBIN_SUB:  ir_emitf("                SEC\n");
                     ir_emitf("                SBC     %s\n", operand); break;
    case IRBIN_BAND: ir_emitf("                AND     %s\n", operand); break;
    case IRBIN_BOR:  ir_emitf("                ORA     %s\n", operand); break;
    case IRBIN_BXOR: ir_emitf("                EOR     %s\n", operand); break;
    }
}

static void
emit_binop_mem_global_lower(Global *g, unsigned kind)
{
    refuse_block_static(g, "emit_binop_mem_global_lower");
    emit_binop_mem_op(kind, gname(g));
}

static void
emit_binop_mem_img_lower(unsigned slot, unsigned kind)
{
    char buf[24];
    snprintf(buf, sizeof buf, "_fcc_img%u", slot);
    emit_binop_mem_op(kind, buf);
}

static void
emit_binop_mem_local_lower(Local *lc, int s_delta, unsigned kind)
{
    int saved = g_s_delta;
    char buf[96];
    g_s_delta = s_delta;
    /* Bank-0 stack campaign 1.3: a SOFT local's operand lives in the data bank.
     *
     * This is a SECOND lowering path for a local operand -- the fused
     * `A op= <local>` form -- and it does not go through emit_slot_op.  The
     * first version of 1.3 only patched emit_slot_op, so `return a + b` loaded
     * `a` correctly from the soft frame and then read `b` at `ADC 3,S` off the
     * hardware stack, which is stale garbage once the local moved.  Caught by
     * M35/p33_recurse, a fixture written for exactly this ("per-frame local
     * independence ... must stay green through the flip").
     *
     * Clobbers Y like every other soft access; see emit_slot_op. */
    if (lc->kind == LK_LOCAL && g_fn_is_soft) {
        char sbuf[64];
        ir_emitf("                LDY     #%d\n", 2 * lc->slot_first);
        snprintf(sbuf, sizeof sbuf, "[_fcc_sfp],Y");
        emit_binop_mem_op(kind, sbuf);
        g_s_delta = saved;
        return;
    }
    /* P3-3 3.1b family (d): A op= local/param scalar (offset 0) on the bank-0
     * hardware stack.  A holds the LHS, so the far (>255) calc preserves it.
     * Unified for LOCAL and PARAM — slot_addr_str renders each correctly. */
    if (slot_needs_far(lc, 0)) {
        emit_far_slot_fp(lc, 0, 1);
        emit_binop_mem_op(kind, "[_fcc_fp]");
    } else {
        snprintf(buf, sizeof buf, "%s,S%s", slot_addr_str(lc, 0), slot_annot(lc, 0));
        emit_binop_mem_op(kind, buf);
    }
    g_s_delta = saved;
}

void
emit_binop_add(void)
{
    if (g_expr_type == LT_LLONG) { emit_ll_call("_fcc_ll_add"); return; }
    if (g_expr_type == LT_DOUBLE) { emit_d_call("_fcc_dadd"); return; }
    if (g_expr_type == LT_FLOAT) {
        emit_jsr_rt("_fcc_fadd");
        return;
    }
    if (g_expr_type == LT_LONG) {
        emit_jsr_rt("_fcc_long_add");
        g_expr_type = LT_LONG;
        return;
    }
    g_expr_type = LT_INT;
    ir_record_op1(IR_BINOP, IRBIN_ADD);
}

void
emit_binop_sub(void)
{
    if (g_expr_type == LT_LLONG) { emit_ll_call("_fcc_ll_sub"); return; }
    if (g_expr_type == LT_DOUBLE) { emit_d_call("_fcc_dsub"); return; }
    if (g_expr_type == LT_FLOAT) {
        emit_jsr_rt("_fcc_fsub");
        return;
    }
    if (g_expr_type == LT_LONG) {
        emit_jsr_rt("_fcc_long_sub");
        g_expr_type = LT_LONG;
        return;
    }
    g_expr_type = LT_INT;
    ir_record_op1(IR_BINOP, IRBIN_SUB);
}

void
emit_unary_neg(void)
{
    if (g_expr_type == LT_FLOAT) {
        emit_jsr_rt("_fcc_fneg");
        return;
    }
    if (g_expr_type == LT_LLONG) {
        emit_ll_call("_fcc_ll_neg");
        return;
    }
    if (g_expr_type == LT_LONG) {
        emit_jsr_rt("_fcc_long_neg");
        return;
    }
    ir_emitf("                EOR     #$FFFF\n");
    ir_emitf("                INC\n");
    g_expr_type = LT_INT;
}

void
emit_unary_bnot(void)
{
    /* BOTH WORDS OF A LONG, and the arm is here because it was NOT.  `~' was
     * a bare EOR on A with _fcc_long_hi passed through, so ~0x00800000L came
     * out as 0x0080FFFF and `x &= ~MASK' cleared nothing above bit 15 --
     * silently, and only for masks whose bits are up there.  A low-word mask
     * inverts to the right 32-bit value by accident, which is why every
     * existing caller worked: apple/fgx#209.
     *
     * K&R A.7.4.6: "The result of the ~ operator is the 1's complement of its
     * operand.  The usual arithmetic conversions are performed.  The type of
     * the operand must be integral."  The 1's complement OF THE OPERAND, and
     * the conversions keep a long a long -- nothing narrows it to the low
     * word.  emit_unary_neg beside this one already had the arm. */
    if (g_expr_type == LT_LLONG) {
        emit_ll_call("_fcc_ll_com");
        return;
    }
    if (g_expr_type == LT_LONG) {
        emit_jsr_rt("_fcc_long_not");
        return;
    }
    ir_emitf("                EOR     #$FFFF\n");
    g_expr_type = LT_INT;
}

void
emit_unary_lnot(void)
{
    int lab_true = new_label();
    int lab_end  = new_label();
    /* Z is ALREADY set by the caller's walk_cond() -- which weighs a far
     * pointer's bank byte, so `!p` no longer misreads bank:0000 as NULL.
     * Re-emitting `CMP #0` here would clobber that verdict with a test of
     * whatever the pointer path happened to leave in A. */
    emit_bcond(IRC_BEQ, lab_true, 0);
    ir_emitf("                LDA     #0\n");
    emit_br(lab_end, 0);
    ir_emitf("%s_L%d\n", g_tu_prefix, lab_true);
    ir_emitf("                LDA     #1\n");
    ir_emitf("%s_L%d\n", g_tu_prefix, lab_end);
    g_expr_type = LT_INT;
}

void
emit_binop_mul(void)
{
    if (g_expr_type == LT_LLONG) { emit_ll_call("_fcc_ll_mul"); return; }
    if (g_expr_type == LT_DOUBLE) { emit_d_call("_fcc_dmul"); return; }
    if (g_expr_type == LT_FLOAT) {
        emit_jsr_rt("_fcc_fmul");
        return;
    }
    if (g_expr_type == LT_LONG) {
        emit_jsr_rt("_fcc_long_mul");
        return;
    }
    emit_jsr_rt("_fcc_mul16");
    g_expr_type = LT_INT;
}

void
emit_binop_div(void)
{
    if (g_expr_type == LT_LLONG) { emit_ll_call(g_binop_unsigned ? "_fcc_ll_divu" : "_fcc_ll_divs"); return; }
    if (g_expr_type == LT_DOUBLE) { emit_d_call("_fcc_ddiv"); return; }
    if (g_expr_type == LT_FLOAT) {
        emit_jsr_rt("_fcc_fdiv");
        return;
    }
    if (g_expr_type == LT_LONG) {
        ir_emitf(g_binop_unsigned
                 ? "                JSR     _fcc_long_divu\n"   /* A-1 */
                 : "                JSR     _fcc_long_divs\n");
        return;
    }
    if (g_binop_unsigned)  /* A-1 */
        emit_jsr_rt("_fcc_divu16");
    else
        emit_jsr_rt("_fcc_divs16");
    g_expr_type = LT_INT;
}

void
emit_binop_mod(void)
{
    if (g_expr_type == LT_LLONG) { emit_ll_call(g_binop_unsigned ? "_fcc_ll_modu" : "_fcc_ll_mods"); return; }
    /* Signed 16-bit modulus.  No LT_LONG path yet — die loudly if a
     * caller tries `long % long` so the gap is obvious; can add
     * _fcc_long_mods when needed. */
    if (g_expr_type == LT_FLOAT)
        die(g_cur.line, g_cur.col,
            "modulus (%) is not valid on float operands");
    if (g_expr_type == LT_LONG) {
        /* 32-bit signed modulus — the runtime routine already exists
         * (_fcc_long_mods, paired with _fcc_long_divs); wire it like
         * emit_binop_div's long path.  (ed's putd: `count % 10`.) */
        ir_emitf(g_binop_unsigned
                 ? "                JSR     _fcc_long_modu\n"   /* A-1 */
                 : "                JSR     _fcc_long_mods\n");
        return;
    }
    if (g_binop_unsigned)  /* A-1 */
        emit_jsr_rt("_fcc_modu16");
    else
        emit_jsr_rt("_fcc_mods16");
    g_expr_type = LT_INT;
}

void
emit_binop_shl(void)
{
    if (g_expr_type == LT_LLONG) { emit_ll_call("_fcc_ll_shl"); return; }
    if (g_expr_type == LT_LONG) {
        emit_jsr_rt("_fcc_long_shl");
        return;
    }
    emit_jsr_rt("_fcc_shl16");
    g_expr_type = LT_INT;
}

void
emit_binop_shr(void)
{
    if (g_expr_type == LT_LLONG) { emit_ll_call(g_binop_unsigned ? "_fcc_ll_shru" : "_fcc_ll_shr"); return; }
    if (g_expr_type == LT_LONG) {
        ir_emitf(g_binop_unsigned
                 ? "                JSR     _fcc_long_shru\n"   /* A-1: logical */
                 : "                JSR     _fcc_long_shr\n");  /* arithmetic */
        return;
    }
    ir_emitf(g_binop_unsigned
             ? "                JSR     _fcc_shr16\n"    /* logical (unsigned) */
             : "                JSR     _fcc_shrs16\n"); /* A-1: arithmetic — the
                                                             old always-LSR zero-
                                                             filled negatives */
    g_expr_type = LT_INT;
}

/* T1.2: inline constant shift on A (int).  LSHIFT -> ASL×k ; UNSIGNED RSHIFT ->
 * LSR×k (implied-accumulator forms, as used by index scaling).  Caller
 * guarantees an int (not long/float) LHS in A, 1<=k<=15, and for RSHIFT that the
 * LHS is unsigned (signed >> keeps the libcall).  Preserves signedness. */
static void
emit_shift_const_lower(unsigned is_lsr, unsigned k)
{
    unsigned i;
    const char *mn = is_lsr ? "LSR" : "ASL";
    for (i = 0; i < k; i++)
        ir_emitf("                %s\n", mn);
}

void
emit_inline_shift(TokKind op, int is_unsigned, unsigned k)
{
    g_expr_type = LT_INT;
    g_expr_unsigned = is_unsigned;
    ir_record_op2(IR_SHIFT_CONST, (op == TOK_LSHIFT) ? 0u : 1u, k);
}

/* T1.2/Tier-1: is A*k cheaper inline than the _fcc_mul16 libcall?  {0,1} and any
 * power of two always; otherwise a shift-add decomposition is emitted only when
 * it stays small -- <=4 set bits (<=3 adds) and msb<=12 (<=12 shifts) -- which
 * covers struct/array element strides (e.g. 56 = i*sizeof) and common factors
 * (3,5,6,10,12,...) while leaving dense/huge constants to _fcc_mul16. */
int
mul_const_inlineable(unsigned k)
{
    int bits = 0, msb = -1, i;
    if (k == 0 || k == 1) return 1;
    if ((k & (k - 1)) == 0 && k <= 0x8000u) return 1;              /* power of two */
    for (i = 0; i < 16; i++) if ((k >> i) & 1) { bits++; msb = i; }
    return (bits > 0 && bits <= 4 && msb <= 12);   /* bits>0: k with no low-16 bit can't shift-add */
}

/* Emit A = A * k for an inlineable constant k (caller MUST have checked
 * mul_const_inlineable).  k=0 -> LDA #0; k=1 -> nop; power of two -> ASL×n;
 * otherwise a MSB-first shift-add Horner sequence using _fcc_tmp_b to hold the
 * multiplicand.  A-only: clobbers A + _fcc_tmp_b; X/Y/stack untouched.  Result
 * is the low 16 bits of x*k (mod 2^16) -- bit-for-bit identical to _fcc_mul16. */
static void
emit_mul_const_seq(unsigned k)
{
    int msb, b;
    if (k == 0) { ir_emitf("                LDA     #0\n"); return; }
    if (k == 1) return;                                            /* x*1 = x */
    if ((k & (k - 1)) == 0) {                                      /* power of two */
        unsigned n = 0, t = k;
        while (t > 1) { t >>= 1; n++; }
        while (n--) ir_emitf("                ASL\n");
        return;
    }
    /* shift-add: A starts = x (top set bit's contribution); then for each lower
     * bit, ASL (double) and ADD x when that bit is set.  CLC each time because
     * ASL shifts the old bit-15 into C. */
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
    msb = 15; while (msb >= 0 && !((k >> msb) & 1)) msb--;   /* guard: gate ensures msb>=0 */
    for (b = msb - 1; b >= 0; b--) {
        ir_emitf("                ASL\n");
        if ((k >> b) & 1) {
            ir_emitf("                CLC\n");
            ir_emitf("                ADC     _fcc_tmp_b\n");
        }
    }
}

static void
emit_mulconst_lower(unsigned k)
{
    emit_mul_const_seq(k);
}

int
emit_inline_mul_const(unsigned k)
{
    if (!mul_const_inlineable(k)) return 0;                        /* keep _fcc_mul16 */
    g_expr_type = LT_INT;
    ir_record_op1(IR_MULCONST, k);
    return 1;
}

/* Scale A (an array/struct index) by a compile-time-constant element stride for
 * subscript / pointer arithmetic.  The single source of truth for index
 * scaling (was duplicated as ~10 open-coded ASL/ASL-ASL/mul16 blocks): stride
 * 0/1 -> nothing; pow2 -> ASL×n; small non-pow2 -> shift-add; otherwise the
 * _fcc_mul16 libcall.  A-only: clobbers A + _fcc_tmp_b; X/Y/stack untouched. */
void
emit_index_scale(unsigned stride)
{
    /* 0 AND 1 BOTH MEAN "NO SCALING" HERE, and apple/fgx#166's suggestion to
     * assert `stride != 0` at this site was tried and is wrong: measured, a
     * die here fires on ordinary userland (calc, cal, compress, b3ptyrx and
     * more), because several callers pass elem_size_for's 0 for a shape that
     * genuinely needs no scale.  The sentinel is only dangerous where a
     * STRIDE was meant, which is why the check lives in ipv_elem_size,
     * air_row_stride and emit_cio_scale instead. */
    if (stride <= 1) return;
    if (mul_const_inlineable(stride)) { emit_mul_const_seq(stride); return; }
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
    ir_emitf("                LDA     #%u\n", stride);
    emit_jsr_rt("_fcc_mul16");
}

/* A = A / k for a SIGNED dividend and a power-of-two k, truncating TOWARD
 * ZERO -- which is what _fcc_divs16 does, and matching it is the whole
 * constraint.  K&R 2nd ed A.7.6 (p.166) does NOT require truncation toward
 * zero: "it is always true that (a/b)*b + a%b is equal to a.  If both operands
 * are non-negative, then the remainder is non-negative and smaller than the
 * divisor, if not, it is guaranteed only that the absolute value of the
 * remainder is smaller than the absolute value of the divisor."  A bare
 * arithmetic shift satisfies that -- it floors, and its remainder is still
 * smaller in absolute value than the divisor.  What it does NOT satisfy is
 * agreeing with the helper this replaces, and a compiler whose answer for
 * `x / 512` depends on whether 512 was written as a literal is worse than one
 * that rounds either way consistently.
 *
 * So a negative dividend is biased by k-1 before the shift, which is the
 * standard toward-zero correction.
 *
 * THE 65816 HAS NO ARITHMETIC SHIFT RIGHT.  `CMP #$8000` sets carry exactly
 * when A has its top bit set, and ROR then rotates that carry back into bit
 * 15 -- so the pair is one arithmetic shift, and it costs 4 bytes a step.
 * That is why divs_pow2_inlineable caps k: the sequence grows with the shift
 * count where the libcall is a fixed three bytes. */
void
emit_inline_divs_pow2(unsigned k)
{
    unsigned n = 0, t = k;
    int lab;

    while (t > 1) { t >>= 1; n++; }
    lab = new_label();
    ir_emitf("                CMP     #$8000\n");        /* C=1 iff negative */
    ir_emitf("                BCC     %s_L%d\n", g_tu_prefix, lab);
    ir_emitf("                CLC\n");
    ir_emitf("                ADC     #%u\n", k - 1);
    ir_emitf("%s_L%d\n", g_tu_prefix, lab);
    while (n--) {
        ir_emitf("                CMP     #$8000\n");
        ir_emitf("                ROR\n");
    }
    g_expr_type = LT_INT;
}

/* A = A % k for a SIGNED dividend and a power-of-two k.  K&R 2nd ed A.7.6
 * (p.166): "it is always true that (a/b)*b + a%b is equal to a", and `/'
 * truncates toward zero here (emit_inline_divs_pow2 and _fcc_divs16 alike),
 * so the remainder takes the dividend's sign -- what _fcc_mods16 returns.
 * The magnitude is |a| & (k-1), negated back for a negative dividend.
 * -32768 negates to itself and masks to 0, which is its remainder.  The
 * sequence is the same size for every k, so no cap applies. */
void
emit_inline_mods_pow2(unsigned k)
{
    int pos = new_label(), done = new_label();

    ir_emitf("                CMP     #$8000\n");        /* C=1 iff negative */
    ir_emitf("                BCC     %s_L%d\n", g_tu_prefix, pos);
    ir_emitf("                EOR     #$FFFF\n");
    ir_emitf("                INC\n");
    ir_emitf("                AND     #%u\n", k - 1);
    ir_emitf("                EOR     #$FFFF\n");
    ir_emitf("                INC\n");
    ir_emitf("                BRA     %s_L%d\n", g_tu_prefix, done);
    ir_emitf("%s_L%d\n", g_tu_prefix, pos);
    ir_emitf("                AND     #%u\n", k - 1);
    ir_emitf("%s_L%d\n", g_tu_prefix, done);
    g_expr_type = LT_INT;
}


/* ---- 32-bit constant shifts ------------------------------------------------
 *
 * K&R 2nd ed A.7.8 (p.166): "The type of the result is that of the promoted
 * left operand", so these leave g_expr_type at LT_LONG, and "The result is
 * undefined if the right operand is negative, or greater than or equal to the
 * number of bits in the left expression's type" -- which is what bounds k at
 * 31 for a 32-bit long and lets the k>=32 case stay with the libcall.
 *
 * A long travels in A (low) + _fcc_long_hi.  The park cell is _fcc_long_b_hi,
 * the same cell _fcc_long_shl itself reuses ("stash low (b_hi was count high,
 * unused)"), so the clobber set is identical to the call being replaced: the
 * count rode in as a literal and was consumed at parse time, so the b-operand
 * cells are dead here exactly as they are inside the runtime routine.
 *
 * A.7.8 also gives the left shift as a pure bit pattern -- "E1 (interpreted as
 * a bit pattern) left-shifted E2 bits" -- so one emitter serves both
 * signednesses.  The right shift is only defined for a nonnegative or unsigned
 * E1: "otherwise the result is implementation-defined" (p.167).  FGX's
 * implementation choice is already made and published by _fcc_long_shr, which
 * is sign-preserving, so the signed sequence below reproduces THAT rather than
 * reading the licence as freedom -- the same reasoning emit_inline_divs_pow2
 * applies for agreement with _fcc_divs16.
 */

/* Size in bytes of the sequence long_shift_inlineable would emit.  Kept as one
 * function rather than three caps so the budget below is a statement about
 * emitted code and not three numbers that drift apart. */
static unsigned
long_shift_bytes(int is_lshift, int is_unsigned, unsigned k)
{
    if (is_lshift)
        return (k >= 16) ? (k - 16) + 6 : 4 * k;
    if (k >= 16)
        return is_unsigned ? (k - 16) + 6 : 4 * (k - 16) + 17;
    return is_unsigned ? 4 * k + 12 : 4 * k + 23;
}

/* A long shift by a constant is worth inlining while the sequence stays small
 * against the 3-byte JSR it replaces.  The libcall is not merely three bytes of
 * course -- it marshals the count, loops k times over MEMORY operands and pays
 * a JSR/RTS -- so the budget is deliberately loose: 64 bytes buys the whole of
 * lblkno's >>10 (63) and every k>=16, where the shift degenerates to a word
 * move and the inline is SMALLER than the call as well as faster. */
int
long_shift_inlineable(int is_lshift, int is_unsigned, unsigned k)
{
    if (k == 0 || k > 31) return 0;                 /* A.7.8: >=32 undefined */
    return long_shift_bytes(is_lshift, is_unsigned, k) <= 64u;
}

/* long <<= k.  Signedness-independent (A.7.8's bit-pattern rule). */
void
emit_inline_long_shl(unsigned k)
{
    unsigned i;
    if (k >= 16) {
        /* Everything below bit 16 is shifted out: the low word BECOMES the
         * high word and the low word becomes zero. */
        for (i = 0; i < k - 16; i++)
            ir_emitf("                ASL\n");
        ir_emitf("                STA     _fcc_long_hi\n");
        ir_emitf("                LDA     #0\n");
    } else {
        for (i = 0; i < k; i++) {
            ir_emitf("                ASL\n");
            ir_emitf("                ROL     _fcc_long_hi\n");
        }
    }
    g_expr_type = LT_LONG;
}

/* long >>= k. */
void
emit_inline_long_shr(int is_unsigned, unsigned k)
{
    unsigned i;
    int lab;

    if (k >= 16) {
        /* The high word BECOMES the low word; only the new high differs by
         * signedness -- zero, or the sign the arithmetic shift preserved. */
        ir_emitf("                LDA     _fcc_long_hi\n");
        if (is_unsigned) {
            for (i = 0; i < k - 16; i++)
                ir_emitf("                LSR\n");
            /* STZ leaves A alone, so the result is already in place. */
            ir_emitf("                STZ     _fcc_long_hi\n");
        } else {
            for (i = 0; i < k - 16; i++) {
                ir_emitf("                CMP     #$8000\n");   /* C = sign */
                ir_emitf("                ROR\n");
            }
            /* A's sign is the ORIGINAL sign -- an arithmetic shift preserves
             * it -- so the new high word is read off A.  CMP touches neither A
             * nor X, so the result survives the test. */
            lab = new_label();
            ir_emitf("                LDX     #0\n");
            ir_emitf("                CMP     #$8000\n");
            ir_emitf("                BCC     %s_L%d\n", g_tu_prefix, lab);
            ir_emitf("                LDX     #$FFFF\n");
            ir_emitf("%s_L%d\n", g_tu_prefix, lab);
            ir_emitf("                STX     _fcc_long_hi\n");
        }
        g_expr_type = LT_LONG;
        return;
    }

    if (!is_unsigned) {
        /* Save the sign BEFORE shifting: the sequence below is the LOGICAL
         * shift, and the sign is restored once at the end by setting the k
         * bits it vacated.  Doing it that way costs one fixed tail instead of
         * a CMP #$8000 on every step. */
        ir_emitf("                LDX     _fcc_long_hi\n");
    }
    ir_emitf("                STA     _fcc_long_b_hi\n");       /* park low */
    ir_emitf("                LDA     _fcc_long_hi\n");
    for (i = 0; i < k; i++) {
        ir_emitf("                LSR\n");
        ir_emitf("                ROR     _fcc_long_b_hi\n");
    }
    if (!is_unsigned) {
        lab = new_label();
        ir_emitf("                CPX     #$8000\n");   /* C=1 iff negative */
        ir_emitf("                BCC     %s_L%d\n", g_tu_prefix, lab);
        ir_emitf("                ORA     #$%04X\n",
                 (unsigned)((0xFFFFu << (16 - k)) & 0xFFFFu));
        ir_emitf("%s_L%d\n", g_tu_prefix, lab);
    }
    ir_emitf("                STA     _fcc_long_hi\n");
    ir_emitf("                LDA     _fcc_long_b_hi\n");
    g_expr_type = LT_LONG;
}


/* T1.2: inline UNSIGNED x/2^n -> LSR×n, x%2^n -> AND #(k-1); plus x/1=identity,
 * x%1 -> 0.  Returns 1 if emitted, else 0 (keep the libcall).  Caller restricts
 * this to unsigned LHS — signed div/mod rounds toward zero, which LSR/AND do not
 * reproduce for negative values. */
int
emit_inline_divmod_pow2(TokKind op, unsigned k)
{
    if (k == 1) {
        if (op == TOK_PERCENT) ir_emitf("                LDA     #0\n");  /* x%1 = 0 */
        g_expr_type = LT_INT;                                                   /* x/1 = x */
        return 1;
    }
    if (k < 2 || (k & (k - 1)) != 0 || k > 0x8000u) return 0;     /* non-pow2 */
    if (op == TOK_PERCENT) {
        ir_emitf("                AND     #%u\n", k - 1);
    } else {
        unsigned n = 0, t = k;
        while (t > 1) { t >>= 1; n++; }
        while (n--) ir_emitf("                LSR\n");
    }
    g_expr_type = LT_INT;
    return 1;
}

void
emit_binop_band(void)
{
    if (g_expr_type == LT_LLONG) { emit_ll_call("_fcc_ll_and"); return; }
    if (g_expr_type == LT_LONG) {
        emit_jsr_rt("_fcc_long_and");
        return;
    }
    g_expr_type = LT_INT;
    ir_record_op1(IR_BINOP, IRBIN_BAND);
}

void
emit_binop_bor(void)
{
    if (g_expr_type == LT_LLONG) { emit_ll_call("_fcc_ll_or"); return; }
    if (g_expr_type == LT_LONG) {
        emit_jsr_rt("_fcc_long_or");
        return;
    }
    g_expr_type = LT_INT;
    ir_record_op1(IR_BINOP, IRBIN_BOR);
}

void
emit_binop_bxor(void)
{
    if (g_expr_type == LT_LLONG) { emit_ll_call("_fcc_ll_xor"); return; }
    if (g_expr_type == LT_LONG) {
        emit_jsr_rt("_fcc_long_xor");
        return;
    }
    g_expr_type = LT_INT;
    ir_record_op1(IR_BINOP, IRBIN_BXOR);
}

void
emit_binop_for_compound(TokKind op, int lhs_unsigned)
{
    /* A-1: compound assignment (x /= y) doesn't route through
     * emit_scalar_binop, so g_binop_unsigned would be stale.  The caller
     * captured the LHS's signedness at load time, promoted; g_expr_unsigned
     * holds the RHS's, and an unsigned CHAR there is an int after A.6.1's
     * promotion -- its zero-extending load is what made it 0..255. */
    g_binop_unsigned = (lhs_unsigned ||
                        promoted_unsigned(g_expr_type, g_expr_unsigned));
    switch (op) {
        case TOK_PLUSEQ:    emit_binop_add();  break;
        case TOK_MINUSEQ:   emit_binop_sub();  break;
        case TOK_STAREQ:    emit_binop_mul();  break;
        case TOK_SLASHEQ:   emit_binop_div();  break;
        case TOK_PERCENTEQ: emit_binop_mod();  break;
        case TOK_AMPEQ:     emit_binop_band(); break;
        case TOK_PIPEEQ:    emit_binop_bor();  break;
        case TOK_CARETEQ:   emit_binop_bxor(); break;
        case TOK_LSHIFTEQ:  emit_binop_shl();  break;
        case TOK_RSHIFTEQ:  emit_binop_shr();  break;
        default:
            die(g_cur.line, g_cur.col, "bad compound op (internal)");
    }
}

/* E1 op= E2 once E1 is back in A (:_fcc_long_hi) and E2 is stashed, E2's type
 * in g_expr_type.  K&R A.7.17: "E1 op= E2 is equivalent to E1 = E1 op (E2)".
 * When E2 is a float and E1 an integer, the usual arithmetic conversions
 * (A.6.5) make the operation a float one, so E1 converts to float first and
 * the result converts back to E1's type by the assignment -- `i += 1.5' adds
 * in float and truncates, which is not `i + (int)1.5' (apple/fgx#396).
 * Every other pairing is emit_binop_for_compound's as before. */
void
emit_compound_op(TokKind op, int lhs_unsigned, LocalType lt)
{
    if (g_expr_type == LT_FLOAT &&
        (lt == LT_INT || lt == LT_CHAR || lt == LT_LONG)) {
        g_expr_unsigned = lhs_unsigned;      /* E1 converts, by E1's type */
        if (lt == LT_LONG) emit_long_to_float();
        else               emit_int_to_float();
        emit_binop_for_compound(op, 0);
        emit_assign_conv(lt);
        return;
    }
    emit_binop_for_compound(op, lhs_unsigned);
}

/* Scale the integer RHS (in A) by a pointer LHS's pointee size, for the
 * `ptr += n` / `ptr -= n` compound-assignment forms — n counts ELEMENTS, not
 * bytes (mirrors the binary p+i / p-i scaling in parse_add_expr).  fcc's
 * compound-assign routed straight through emit_binop_for_compound (a raw add/
 * sub), so a pointer compound-assign advanced by bytes — e.g. 2.11BSD ed's
 * `a1 += n` on an int* produced byte-misaligned line handles.  Call AFTER the
 * RHS is evaluated into A and BEFORE it is stashed, only for +=/-=.  No-op for
 * non-pointer LHS or a 1-byte pointee (char*). */
/* A holds the integer operand of a `ptr += n' / `ptr -= n'.  Scale it by the
 * pointee (K&R A.7.7) before the add.
 *
 * Was `ptr_stride()' plus a hand-rolled ASL for stride 2 and 4 only, which is
 * wrong twice for a STRUCT pointer: ptr_stride returns 0 there by design (the
 * size needs the struct id, which the type word cannot carry), so NO scaling
 * was emitted at all and `p += 1' advanced one byte; and a struct is not a
 * power of two in general, so shifts could not express it even given the size.
 * elem_size_for knows the size, emit_index_scale already scales by an
 * arbitrary constant -- the same one subscripting uses, which is why `p[i]'
 * was right the whole time `p += i' was not (apple/fgx#154).  Byte-identical
 * output for strides 2 and 4. */
void
emit_scale_compound_ptr(LocalType lhs_type, int struct_id, TokKind op)
{
    if (op != TOK_PLUSEQ && op != TOK_MINUSEQ)
        return;
    emit_index_scale((unsigned)elem_size_for(lhs_type, struct_id));
}

void
emit_label(int n)
{
    fpr_sym_live_check();
    ir_record_op1(IR_LABEL, (unsigned)n);
}

/* T2-3: record-time control-flow helpers.  Cond index: BEQ=0 BNE=1 BCC=2
 * BCS=3 BMI=4 BPL=5 BVC=6 BVS=7 (pairs differ in bit0, so FAR inversion is
 * c^1).  far adds bit3.  */
void
emit_br(int n, int is_brl)
{
    fpr_sym_live_check();
    ir_record_op2(IR_BR, (unsigned)n, is_brl ? 1u : 0u);
}

void
emit_bcond(int cond, int n, int far)
{
    fpr_sym_live_check();
    ir_record_op2(IR_BCOND, (unsigned)n,
                  (unsigned)(cond & 7) | (far ? 8u : 0u));
}

void
emit_jsr_rt(const char *name)
{
    ir_record_op_ptr(IR_JSR_RT, (void *)name);
}

/* P2' loop safepoint, apple/fgx#371.  Emitted at every loop top, so this runs
 * once per iteration of every loop in every FGX program -- which is why the
 * CALLING CONVENTION, not the check, was the cost:
 *
 *     JSR _fcc_safepoint      6      LDAL KFGX_YIELD_MIRROR  6
 *     LDAL KFGX_YIELD_MIRROR  6      BEQ  *+5                2
 *     BEQ  @sp_done           2      ---                     8
 *     RTS                     6
 *     ---                    20      (+6 bytes per loop site)
 *
 * Twelve of the twenty were the JSR and RTS doing no work.  Hoisting the test
 * to the emission site leaves the call on the taken arm only, where a
 * reschedule is actually pending and 6 cycles are noise against a context
 * switch.  `_fcc_safepoint' re-reads the mirror; that re-read is now redundant
 * but harmless, and keeping it means the routine is still correct for a direct
 * call.
 *
 * SAFE BY THE PRECONDITION THE RUNTIME ALREADY DOCUMENTS, unchanged: at a loop
 * top A and the N/Z flags are dead, so the LDAL clobbers nothing live.  This
 * moves that same LDAL from the callee to the caller and clobbers no more than
 * it already did.  X and Y are untouched here and still survive the yield by
 * the context switch.
 *
 * `*+5' rather than a label: BEQ is 2 bytes and JSR is 3, so the branch target
 * is the next instruction, and the displacement is a constant 3 that cannot go
 * out of range.  It is the idiom IR_BCOND's far form already uses.  Taking a
 * label would consume a `new_label()' number and renumber every `_L<n>' in the
 * translation unit, which would rewrite every golden for no gain.
 */
void
emit_safepoint(void)
{
    if (!g_emit_safepoints) return;
    ir_emitf("                LDAL    KFGX_YIELD_MIRROR\n");
    ir_emitf("                BEQ     *+5\n");
    emit_jsr_rt("_fcc_safepoint");
}

/* T2-3: accumulator width switches (the SEP/REP+MX pair as one op). */
void emit_m8(void)  { ir_record_op(IR_M8);  }
void emit_m16(void) { ir_record_op(IR_M16); }

/* T2-3 %s-cell lift helpers: canonical interned cell names for the
 * IR_LDA_CELL/IR_STA_CELL ptr (fpr_name()/gname() return REUSED static
 * buffers — interning is what makes the pointer safe to store).  cellp2
 * composes the "+2" hi-word form so the op's ptr carries the FULL
 * operand text (byte-identical lowering via "LDA %s"). */
const char *
cellp(const char *base)
{
    return lex_intern_ident(base, (int)strlen(base));
}

/* printf-style composed cell name -> canonical interned pointer. */
const char *
cellpf(const char *fmt, ...)
{
    char b[80];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(b, sizeof b, fmt, ap);
    va_end(ap);
    return lex_intern_ident(b, (int)strlen(b));
}

const char *
cellp2(const char *base)
{
    char b[80];
    snprintf(b, sizeof b, "%s+2", base);
    return lex_intern_ident(b, (int)strlen(b));
}

/* Test the evaluated expression against zero, setting Z.  A is PRESERVED.
 *
 * Scalars only.  A far pointer holds just its OFFSET in A, so testing a
 * pointer here would ignore the bank byte; pointer conditions go through
 * emit_fpr_test_zero() below, which the walker's walk_cond() selects on
 * ISPTR.  See the note there for the history. */
void
emit_test_a_zero(void)
{
    ir_emitf("                CMP     #0\n");
}

/* Truth-test a far pointer held in fprK: Z=1 iff the pointer is ENTIRELY
 * zero (offset word AND bank byte).  Same polarity as emit_test_a_zero's
 * CMP #0, so a call site's existing BEQ/BNE keeps its meaning.
 *
 * CLOBBERS A -- unlike emit_test_a_zero, which preserves it.  Every current
 * caller branches immediately and then rewrites A, so none depends on it.
 *
 * This closes a gap (issue #6) that stood from 2026-07-26: `if (p)`, `!p`,
 * `p ? :`, `&&` and `||` compared the offset alone, so a pointer at
 * bank:0000 -- a non-zero bank with a zero offset -- read as NULL, while
 * `p == (T *)0` went through emit_fpr_cmp, compared both halves, and read
 * the same pointer as non-NULL.  This makes the truth test agree with the
 * equality form rather than contradict it.
 *
 * Why THIS shape and not the one that was reverted: the earlier attempt
 * fell through to an 8-bit test of _fcc_ptr+2, a cell populated only by the
 * LOAD paths.  For a pointer that came from anywhere else -- a function
 * return, a computed pointer -- it held a STALE bank, so genuinely-NULL
 * pointers tested NON-null and got dereferenced (failsafe 15/15 -> 0/15).
 * Trading "some non-null pointers look null" for "some null pointers look
 * non-null" is strictly worse.  Reading the CURRENT expression's own FPR
 * carrier avoids that: walk_fpr() guarantees the slot is materialized, and
 * its fallback for an A-only result STZs the bank to 0 -- so the worst case
 * degrades to today's offset-only answer and never manufactures a non-null.
 *
 * The +2 cell's high byte is a DON'T-CARE PAD (call_stashed_fnptr and
 * emit_fpr_restore_live both write +2 16 bits wide), hence the mask.  The
 * m8 route emit_fpr_cmp uses would not help here: an 8-bit LDA leaves stale
 * garbage in A's high byte that the 16-bit ORA would fold straight in. */
/* Truth-test a 32-bit long/float: Z=1 iff the whole value is zero.
 *
 * A holds the LOW word and _fcc_long_hi the HIGH word, so the plain
 * emit_test_a_zero() `CMP #0` tested the low word alone -- `65536L` (lo=$0000,
 * hi=$0001) read as FALSE while `v != 0` went through _fcc_long_eq, compared
 * all 32 bits, and read it as TRUE.  Same defect as the far-pointer one above,
 * one type over (issue #8).
 *
 * FLOAT masks the sign bit: IEEE-754 NEGATIVE ZERO is $80000000 and compares
 * equal to 0.0, so `if (-0.0)` must be false.  ORing the raw high word would
 * make it true -- a bug the integer form cannot have.
 *
 * CLOBBERS A (and _fcc_tmp_b in the float case); callers branch immediately. */
void
emit_test_long_zero(int is_float)
{
    if (is_float) {
        ir_emitf("                STA     _fcc_tmp_b\n");      /* save lo */
        ir_emitf("                LDA     _fcc_long_hi\n");
        ir_emitf("                AND     #$7FFF\n");          /* drop the sign */
        ir_emitf("                ORA     _fcc_tmp_b\n");
        return;
    }
    ir_emitf("                ORA     _fcc_long_hi\n");
}

void
emit_fpr_test_zero(int k)
{
    fpr_sym_flush(k);
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp2(fpr_name(k)));
    ir_emitf("                AND     #$00FF\n");     /* drop the pad byte */
    ir_emitf("                ORA     %s\n", fpr_name(k));
}

void
emit_beq_label(int n)
{
    emit_bcond(IRC_BEQ, n, 1);       /* far form: BNE *+5 / BRL — one op */
}

/* Long-safe BNE: the 65816 BNE is an 8-bit relative branch (+-127); for a
 * forward target past that range (e.g. `||` jumping over a large RHS), invert
 * to BEQ-over-BRL.  Mirrors emit_beq_label. */
void
emit_bne_label(int n)
{
    emit_bcond(IRC_BNE, n, 1);       /* far form: BEQ *+5 / BRL — one op */
}

void
emit_bra_label(int n)
{
    emit_br(n, 1);
}

void
emit_brl_label(int n)
{
    emit_br(n, 1);
}

/* A long long comparison: the runtime answers -1, 0 or 1 in A with N/Z set,
 * and this turns that into K&R's 1 or 0 (A.7.9, "the result is int").  GT and
 * LE test A against 1; the rest branch on the flags as they come back.
 *   B??  *+7  -> LDA #1      LDA #0  /  BRA *+5  /  LDA #1 */
void
emit_ll_cmp(const char *br)
{
    emit_ll_call(g_binop_unsigned ? "_fcc_ll_cmpu" : "_fcc_ll_cmps");
    if (strcmp(br, "GT") == 0) {
        ir_emitf("                CMP     #1\n");
        br = "BEQ";
    } else if (strcmp(br, "LE") == 0) {
        ir_emitf("                CMP     #1\n");
        br = "BNE";
    }
    ir_emitf("                %s     *+7\n", br);
    ir_emitf("                LDA     #0\n");
    ir_emitf("                BRA     *+5\n");
    ir_emitf("                LDA     #1\n");
    g_expr_type = LT_INT;
    g_expr_unsigned = 0;
}

/* A long double comparison.  _fcc_dcmp answers $FFFF, 0 or 1 for an ordered
 * pair and 2 when either is a NaN, so each test picks out exactly the answers
 * that make it true: `!=' is true of an unordered pair and the other five are
 * false.  LE is $FFFF or 0, which one INC maps to the two values below 2; GE
 * is 0 or 1. */
void
emit_d_cmp(const char *br)
{
    emit_d_call("_fcc_dcmp");
    if (strcmp(br, "GT") == 0) {
        ir_emitf("                CMP     #1\n");
        br = "BEQ";
    } else if (strcmp(br, "LE") == 0) {
        ir_emitf("                INC\n");
        ir_emitf("                CMP     #2\n");
        br = "BCC";
    } else if (strcmp(br, "GE") == 0) {
        ir_emitf("                CMP     #2\n");
        br = "BCC";
    }
    ir_emitf("                %s     *+7\n", br);
    ir_emitf("                LDA     #0\n");
    ir_emitf("                BRA     *+5\n");
    ir_emitf("                LDA     #1\n");
    g_expr_type = LT_INT;
    g_expr_unsigned = 0;
}

/* Z clear iff the long double in the accumulator is not zero: any bit but
 * the sign.  -0.0 is zero, and a NaN is not (A.7.4.7's `compares equal to
 * 0'). */
void
emit_test_double_zero(void)
{
    ir_emitf("                TAY\n");
    ir_emitf("                LDA     _fcc_q3\n");
    ir_emitf("                AND     #$7FFF\n");
    ir_emitf("                ORA     _fcc_q2\n");
    ir_emitf("                ORA     _fcc_long_hi\n");
    ir_emitf("                STY     _fcc_tmp_b\n");
    ir_emitf("                ORA     _fcc_tmp_b\n");
}

/* The long double in the accumulator, negated: its sign bit flipped (A.7.4.5,
 * "the negative of its operand"; -0.0 and a NaN's sign flip too). */
void
emit_neg_double(void)
{
    ir_emitf("                TAY\n");
    ir_emitf("                LDA     _fcc_q3\n");
    ir_emitf("                EOR     #$8000\n");
    ir_emitf("                STA     _fcc_q3\n");
    ir_emitf("                TYA\n");
    g_expr_type = LT_DOUBLE;
}

/* The long double in the accumulator plus or minus one: _fcc_dadd with the
 * second operand 1.0 or -1.0.  A is w0 and is left alone. */
void
emit_double_add_unit(int is_inc)
{
    ir_emitf("                STZ     _fcc_long_b_lo\n");
    ir_emitf("                STZ     _fcc_long_b_hi\n");
    ir_emitf("                STZ     _fcc_qb2\n");
    ir_emitf("                LDX     #$%s\n", is_inc ? "3FF0" : "BFF0");
    ir_emitf("                STX     _fcc_qb3\n");
    emit_d_call("_fcc_dadd");
    g_expr_type = LT_DOUBLE;
}

/* Z set iff the long long in the accumulator is zero. */
void
emit_test_llong_zero(void)
{
    ir_emitf("                ORA     _fcc_long_hi\n");
    ir_emitf("                ORA     _fcc_q2\n");
    ir_emitf("                ORA     _fcc_q3\n");
}

void emit_cmp_eq(void) {
    if (g_expr_type == LT_LLONG) { emit_ll_cmp("BEQ"); return; }
    if (g_expr_type == LT_DOUBLE) { emit_d_cmp("BEQ"); return; }
    if (g_expr_type == LT_FLOAT)     emit_jsr_rt("_fcc_feq");
    else if (g_expr_type == LT_LONG) emit_jsr_rt("_fcc_long_eq");
    else                             emit_jsr_rt("_fcc_eq16");
    g_expr_type = LT_INT;
}

void emit_cmp_ne(void) {
    if (g_expr_type == LT_LLONG) { emit_ll_cmp("BNE"); return; }
    if (g_expr_type == LT_DOUBLE) { emit_d_cmp("BNE"); return; }
    if (g_expr_type == LT_FLOAT)     emit_jsr_rt("_fcc_fne");
    else if (g_expr_type == LT_LONG) emit_jsr_rt("_fcc_long_ne");
    else                             emit_jsr_rt("_fcc_ne16");
    g_expr_type = LT_INT;
}

/* Load into A the bank of the value currently being stored into a 4-byte
 * pointer slot.  A real pointer rvalue carries its bank in _fcc_ptr+2; an
 * int/char rvalue (bare NULL / 0) has no bank, so it stores bank 0 — otherwise
 * stale garbage in _fcc_ptr+2 makes NULL look like a wild cross-bank pointer.
 * Mirrors the widen already done in emit_store_{local,global}_field.  (Cast
 * NULL like `(T*)0` is handled at the cast site, which zeros _fcc_ptr+2 and
 * leaves g_expr_type a pointer, so this falls to the _fcc_ptr+2 load = 0.) */
void emit_long_hi_bank(void) {
    ir_emitf("                LDA     _fcc_long_hi\n");
    ir_emitf("                AND     #$00FF\n");
}

void emit_load_value_bank(void) {
    if (g_expr_type == LT_LONG) {
        emit_long_hi_bank();                /* a long carries its own bank */
    } else if (g_expr_type == LT_INT || g_expr_type == LT_CHAR) {
        /* apple/fgx#12: a CONSTANT int keeps bank 0 (NULL, `(char*)-1`,
         * `(char*)0xC000`); a RUNTIME int addresses the task DATA bank. */
        if (g_expr_const_int)
            ir_emitf("                LDA     #0\n");        /* constant */
        else
            emit_jsr_rt("_fcc_bank_for_int");  /* #12: A=offset -> A=bank */
    } else {
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
    }
}

/* Reinterpret a pointer value (offset in A, bank in _fcc_ptr+2) as a long for
 * == / != so the comparison includes the BANK: low word = offset, high word =
 * bank (zero-extended).  Without this, multi-bank pointer compares went through
 * _fcc_eq16/_fcc_ne16 (offset only) and two objects in different heap banks
 * with the same offset compared equal — vi's `memp->next != Fileend->linep`
 * list walk then never terminated (hang in _fcc_ne16).  Caller MX %00. */
void emit_ptr_to_long_for_cmp(void) {
    ir_record_raw(IR_PUSH_A, 0, 0, NULL);            /* save offset (low word) */
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
    ir_emitf("                AND     #$00FF\n"); /* bank byte, zero-extended */
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
    ir_record_raw(IR_POP_A, 0, 0, NULL);            /* restore offset */
}

/* FUSED COMPARE-AND-BRANCH.  The flags a comparison leaves ARE the branch, so
 * neither the 0/1 the helper materialises nor the `CMP #0` that turned it back
 * into flags is emitted.  `if (a < b)` was `JSR _fcc_lts16` + `CMP #0` + the
 * branch -- three steps to get back to where the subtraction already was.  The
 * four 16-bit helpers were 2.04% of a five-exec profile.
 *
 * In: A = LHS, _fcc_tmp_b = RHS, exactly as emit_scalar_binop leaves them.
 * Emits the branch to `label` taken when the comparison is TRUE (want_true) or
 * FALSE.
 *
 * `>` IS `<` WITH THE OPERANDS THE OTHER WAY ROUND, and `<=` is `>=`.  Taken
 * directly, `a > b` is "carry set AND zero clear", which no single Bcc
 * expresses; swapping costs three instructions and buys one branch.
 *
 * THE SWAP ALSO AVOIDS A TRAP.  The signed arm corrects N with `EOR #$8000`,
 * which REPLACES A -- so Z afterwards describes the EOR and not the
 * subtraction, and a difference of exactly $8000 (reachable: 0 - (-32768)
 * overflows to it) would set Z on operands that are not equal.  Nothing here
 * reads Z after the correction, and the swap is why nothing needs to. */
void
emit_cmp_branch(TokKind op, int is_unsigned, int label, int want_true)
{
    int cc;

    if (op == TOK_GT || op == TOK_LE) {
        ir_emitf("                LDX     _fcc_tmp_b\n");
        ir_emitf("                STA     _fcc_tmp_b\n");
        ir_emitf("                TXA\n");
        op = (op == TOK_GT) ? TOK_LT : TOK_GE;
    }

    if (op == TOK_EQEQ || op == TOK_NE || is_unsigned) {
        ir_emitf("                CMP     _fcc_tmp_b\n");
        cc = (op == TOK_EQEQ) ? IRC_BEQ :
             (op == TOK_NE)   ? IRC_BNE :
             (op == TOK_LT)   ? IRC_BCC : IRC_BCS;
    } else {
        /* Signed: the difference's sign is N XOR V, which is the same
         * correction _fcc_lts16 makes (src/kernel/far/fcc_rt.s). */
        int lab = new_label();
        ir_emitf("                SEC\n");
        ir_emitf("                SBC     _fcc_tmp_b\n");
        emit_bcond(IRC_BVC, lab, 0);       /* over the 3-byte EOR: near */
        ir_emitf("                EOR     #$8000\n");
        emit_label(lab);
        cc = (op == TOK_LT) ? IRC_BMI : IRC_BPL;
    }

    /* cc is the branch-if-TRUE condition; the pairs differ in bit 0. */
    if (!want_true) cc ^= 1;
    emit_bcond(cc, label, 1);
    g_expr_type = LT_INT;
}


/* emit_cmp_branch with a literal 0 on the right: A is the left side, and
 * `CMP #0' leaves the N and Z the subtraction would -- A - 0 cannot
 * overflow, so the sign of A is the sign of the difference. */
void
emit_cmp_zero_branch(TokKind op, int label, int want_true)
{
    int cc = (op == TOK_EQEQ) ? IRC_BEQ :
             (op == TOK_NE)   ? IRC_BNE :
             (op == TOK_LT)   ? IRC_BMI : IRC_BPL;
    ir_emitf("                CMP     #0\n");
    if (!want_true) cc ^= 1;
    emit_bcond(cc, label, 1);
    g_expr_type = LT_INT;
}


void emit_cmp_lt(void) {
    if (g_expr_type == LT_LLONG) { emit_ll_cmp("BMI"); return; }
    if (g_expr_type == LT_DOUBLE) { emit_d_cmp("BMI"); return; }
    if (g_expr_type == LT_FLOAT)      emit_jsr_rt("_fcc_flt");
    else if (g_expr_type == LT_LONG)  ir_emitf(g_binop_unsigned
                                          ? "                JSR     _fcc_long_ltu\n"    /* A-1 */
                                          : "                JSR     _fcc_long_lts\n");
    else if (g_binop_unsigned)        emit_jsr_rt("_fcc_ltu16");
    else                              emit_jsr_rt("_fcc_lts16");
    g_expr_type = LT_INT;
}

void emit_cmp_gt(void) {
    if (g_expr_type == LT_LLONG) { emit_ll_cmp("GT"); return; }
    if (g_expr_type == LT_DOUBLE) { emit_d_cmp("GT"); return; }
    if (g_expr_type == LT_FLOAT)      emit_jsr_rt("_fcc_fgt");
    else if (g_expr_type == LT_LONG)  ir_emitf(g_binop_unsigned
                                          ? "                JSR     _fcc_long_gtu\n"    /* A-1 */
                                          : "                JSR     _fcc_long_gts\n");
    else if (g_binop_unsigned)        emit_jsr_rt("_fcc_gtu16");
    else                              emit_jsr_rt("_fcc_gts16");
    g_expr_type = LT_INT;
}

void emit_cmp_le(void) {
    if (g_expr_type == LT_LLONG) { emit_ll_cmp("LE"); return; }
    if (g_expr_type == LT_DOUBLE) { emit_d_cmp("LE"); return; }
    if (g_expr_type == LT_FLOAT)      emit_jsr_rt("_fcc_fle");
    else if (g_expr_type == LT_LONG)  ir_emitf(g_binop_unsigned
                                          ? "                JSR     _fcc_long_leu\n"    /* A-1 */
                                          : "                JSR     _fcc_long_les\n");
    else if (g_binop_unsigned)        emit_jsr_rt("_fcc_leu16");
    else                              emit_jsr_rt("_fcc_les16");
    g_expr_type = LT_INT;
}

void emit_cmp_ge(void) {
    if (g_expr_type == LT_LLONG) { emit_ll_cmp("BPL"); return; }
    if (g_expr_type == LT_DOUBLE) { emit_d_cmp("GE"); return; }
    if (g_expr_type == LT_FLOAT)      emit_jsr_rt("_fcc_fge");
    else if (g_expr_type == LT_LONG)  ir_emitf(g_binop_unsigned
                                          ? "                JSR     _fcc_long_geu\n"    /* A-1 */
                                          : "                JSR     _fcc_long_ges\n");
    else if (g_binop_unsigned)        emit_jsr_rt("_fcc_geu16");
    else                              emit_jsr_rt("_fcc_ges16");
    g_expr_type = LT_INT;
}

void
emit_str_pool(void)
{
    if (g_n_str_lits == 0) return;
    /* C5: in --far-calls the string pool lives in the data segment (DBR-
     * resident) alongside globals, so a code-bank pointer to it carries the
     * data bank, not the code bank.  Else (FGX1 / plain --data-segment) it
     * stays in code as before.  --libso: in code, one section per literal,
     * because libc.so's literals are read-only and shared (K&R A.2.6), and a
     * function pushes its literal's bank with PHK (emit_fpr_lit_str). */
    FILE *dst = g_libso ? g_out : g_data_out;
    fprintf(dst, "\n;-------------------------------\n");
    fprintf(dst, "; M7 string literal pool\n");
    fprintf(dst, ";-------------------------------\n");
    for (int i = 0; i < g_n_str_lits; i++) {
        int off = g_str_lits[i].offset;
        int len = g_str_lits[i].len;
        /* char[]-init blobs stream into the array's own storage
         * (emit_globals_section); no label, no pool bytes. */
        if (g_str_lits[i].no_pool)
            continue;
        /* Export every string pool entry whenever a data segment exists.
         * Plain --data-segment: pool is in CODE, referenced from the data seg.
         * --far-calls: pool is IN the data seg, but the data-side global/struct
         * char* INIT pointers (FGX2_LONG_PTR) are resolved by fgx_ld via the
         * export table — even though CODE reads strings via dataseg_layout EQUs.
         * (FGX2_EXPORT is a zero-byte marker, so this never shifts the layout.) */
        if (g_libso && g_sections)
            fprintf(dst, "                FGX_SECT %s_S%d\n", g_tu_prefix, i);
        emit_mac_export(!g_libso, "%s_S%d", g_tu_prefix, i);
        /* Chunk long strings across HEX lines: merlin32 SIGABRTs on a
         * source line somewhere past 788 chars (measured: 256 bytes/788
         * chars assembles, 400 bytes/1220 chars aborts -- frotz
         * dumb_init's 684-byte usage text found it).  128 bytes/line is
         * ~404 chars, 3x under the cliff, and no string under 128 bytes
         * changes shape, which is all of the pre-frotz corpus. */
        fprintf(dst, "%s_S%-13d HEX     ", g_tu_prefix, i);
        for (int j = 0; j < len; j++) {
            if (j > 0 && (j & 127) == 0)
                fprintf(dst, "\n                HEX     ");
            fprintf(dst, "%s%02X",
                    ((j & 127) == 0) ? "" : ",",
                    (unsigned char)g_str_pool[off + j]);
        }
        fprintf(dst, "\n");
        if (g_libso && g_sections)
            fprintf(dst, "                FGX_ENDS\n");
    }
}

static void emit_one_global(Global *g);

/* --libso: each library member's statics as ONE block template.  The core
 * holds the member's cell, _<lib>_blk_<member> (--libso-name; libc's by
 * default), which each process points at
 * its own copy of the block; a static is at block_offset(g) in it (shared
 * libc SP2 spec, section 4), which the template asserts per static. */
static void
emit_block_templates(void)
{
    const char *mem[256];
    int n_mem = block_members(mem, 256);
    FILE *dst = g_data_out;
    for (int j = 0; j < n_mem; j++) {
        emit_mac_export(1, "_%s_blk_%s", g_libso_name, mem[j]);
        /* --libso-inplace: the template IS this process's block (a program
         * whose data segment carries libc's statics); else the loader or
         * startup points the cell at the process's block. */
        if (g_libso_inplace)
            fprintf(dst, "_%s_blk_%-5s DA      %s__BT\n", g_libso_name, mem[j], mem[j]);
        else
            fprintf(dst, "_%s_blk_%-5s DA      0\n", g_libso_name, mem[j]);
    }
    for (int j = 0; j < n_mem; j++) {
        if (g_sections)
            fprintf(dst, "                FGX_SECT %s__BT\n", mem[j]);
        emit_mac_export(1, "%s__BT", mem[j]);
        fprintf(dst, "%s__BT          ANOP\n", mem[j]);
        for (int i = 0; i < g_n_globals; i++) {
            Global *g = &g_globals[i];
            if (g->member != mem[j] || !is_block_static(g)) continue;
            {
                /* The code addresses this static at block_offset(g); assert
                 * that is where the template put it (ERR fails the assembly
                 * on a nonzero value). */
                fprintf(dst, "                ERR     *-%s__BT-%d\n",
                        mem[j], block_offset(g));
                emit_one_global(g);
            }
        }
        if (g_sections)
            fprintf(dst, "                FGX_ENDS\n");
    }
}

static void
emit_one_global(Global *g)
{
    FILE *dst = g_data_out;
    /* --libso: a block static's address is its process's block plus an
     * offset, known only at run time; an initialiser is a link-time
     * constant, so it would point at the shared template instead (shared
     * libc SP2 spec, section 4: no pointer into a block from data). */
    if (g->is_reloc_target && is_block_static(g)) {
        char msg[200];
        snprintf(msg, sizeof msg, "block static '%s' has its address taken in "
                 "an initialiser; its address is per-process", gname(g));
        die(0, 0, msg);
    }
    /* multi-TU: extern declarations don't emit storage. */
    if (g->is_extern) return;
    /* K&R A.10.2 tentative-def coalescing (--commons): a tentative def
     * (uninit, no `extern`) is NOT emitted as a per-TU `<name> DS` label --
     * it would collide across TUs when the data segments assemble together.
     * Record it in the sidecar (TENT name size reloc) for gen_commons to
     * merge into ONE definition; a real (initialized) def is recorded DEF so
     * gen_commons drops the tentatives (the real def, emitted below, wins). */
    if (g_commons_out) {
        if (!g->is_initialised) {
            fprintf(g_commons_out, "TENT %s %d %d\n",
                    gname(g), g->n_bytes, g->is_reloc_target ? 1 : 0);
            return;                /* no per-TU storage in .data.s */
        }
        fprintf(g_commons_out, "DEF %s\n", gname(g));
    }
    /* If another global initialises a pointer to this one, export its
     * label so fgx_ld can resolve the FGX2_LONG_PTR.  Zero-byte macro
     * (no layout shift); sits at the storage address below. */
    if (g->is_reloc_target)
        emit_mac_export(1, "%s", gname(g));
    fprintf(dst, "%-15s ", gname(g));
    if (!g->is_initialised) {
        fprintf(dst, "DS      %d\n", g->n_bytes);
        return;
    }
    /* B-7: initialised fn-ptr global — 4-byte own-bank pointer.
     * init_func_idx >= 0 -> &function: DA label / DFB ^label / pad.
     * The link-baked ^bank is a placeholder; emit_load_global's ISPTR
     * path recovers the runtime bank via PHK (own-bank fn-ptr semantics).
     * init_func_idx < 0 (a `= 0` / NULL init) -> 4-byte zero. */
    if (g->type == LT_FN_PTR) {
        if (g->init_func_idx >= 0) {
            Func *fn = &g_funcs[g->init_func_idx];
            /* Multi-bank (--far-calls): &function is a CROSS-BANK far
             * pointer.  The packer may place fn in another code bank, so
             * emit FGX2_LONG_PTR — fgx_ld resolves the name GLOBALLY across
             * every seg's exports (every fn is FGX2_EXPORT'd under
             * --far-calls) and relocs the bank byte.  Single-bank: bake
             * DA/^ (own-bank; PHK recovers the bank at the call).
             * Guard on g_far_calls (NOT g_data_out): plain --data-segment
             * 2-seg builds are single-code-bank (fn same bank as caller,
             * PHK correct) and don't FGX2_EXPORT functions. */
            EMIT_FA_PTR(fn);
        } else {
            fprintf(dst, "DA      $0000\n");
            fprintf(dst, "                DA      $0000\n");
        }
        return;
    }
    /* M22: struct-array brace init — walk elements × fields per
     * struct layout.  Handled before the flat path since storage
     * shape is different. */
    if ((g->type == LT_STRUCT_ARRAY || g->type == LT_STRUCT) &&
        g->n_init_values > 0) {
        /* A scalar struct (LT_STRUCT) is n_elems == 1; the same
         * elements×fields walk emits it correctly (well-formed, indented). */
        Struct *s = &g_structs[g->struct_id];
        /* Walk the same LEAF slots the parser filled (struct_init_leaves):
         * one per scalar, with an embedded struct member flattened and a
         * non-char array member expanded per element.  For an all-scalar
         * struct the leaf list is exactly the field list, so this emits
         * byte-identically to the previous s->fields walk.  Leaves carry
         * ABSOLUTE byte_offset within the element, which is all the
         * offset-driven padding below needs. */
        Field leaves[MAX_STRUCT_INIT_LEAVES];
        int n_fields = struct_init_leaves(g->struct_id, leaves, NULL,
                                          MAX_STRUCT_INIT_LEAVES);
        if (n_fields < 0) n_fields = s->n_fields;   /* fail closed */
        if (g->init_slots_per_elem > 0) n_fields = g->init_slots_per_elem;
        int es = (s->total_size + 1) & ~1;
        int init_elems = (n_fields > 0) ?
                         (g->n_init_values / n_fields) : 0;
        int prefix_needed = 0;
        for (int e = 0; e < g->n_elems; e++) {
            int pos = 0;
            int provided = (e < init_elems);
            for (int f = 0; f < n_fields; f++) {
                Field *fld = &leaves[f];
                int idx = e * n_fields + f;
                unsigned v = provided ? g->init_values[idx] : 0;
                while (pos < fld->byte_offset) {
                    if (prefix_needed) fprintf(dst, "                ");
                    fprintf(dst, "DFB     $00\n");
                    prefix_needed = 1;
                    pos++;
                }
                if (fld->type == LT_CHAR_PTR) {
                    /* Uniform 4-byte in-struct pointer: the bank travels
                     * with the field (no PHK recovery at deref).  Mirror
                     * the top-level char*[] (is_cptr_arr) emission:
                     *   --data-segment mode → FGX2_LONG_PTR (loader-relocated)
                     *   single-bank        → baked DA + DFB ^ + DFB $00
                     * init_values_hi[idx] flag: 0 = string-pool label,
                     * 1 = NULL pointer (4-byte zero), 3 = &global (the
                     * field is initialized to a global's address — an
                     * array name decays to &arr[0]; init_values[idx] is
                     * the global index). */
                    if (prefix_needed) fprintf(dst, "                ");
                    if (provided && g->init_values_hi[idx] == 0) {
                        emit_mac_longptr("_Sa", 0, "%s_S%u", g_tu_prefix, v);
                    } else if (provided && g->init_values_hi[idx] == 3) {
                        /* char* field = &global (an array name decays to
                         * &arr[0]; init_values[idx] is the global index).
                         * Multi-bank: same-segment far pointer — the target
                         * global lives in seg1 with the cell, so the offset
                         * is assembly-resolved and only the bank byte is
                         * relocated (works for extern targets defined in
                         * ANOTHER TU, which never FGX2_EXPORT them).
                         * (elvis opts.c's `opts[].value = o_autoindent`.)
                         * Single-bank: bake the address (DA label /
                         * DFB ^bank / pad). */
                        /* &global(.member): init_values packs the global
                         * index (low 16) + member byte offset (high 16); the
                         * reloc resolves label+offset (telnet Setlist's
                         * `char *charp = &nttyb.sg_erase`). */
                        Global *tg = &g_globals[v & 0xFFFF];
                        int goff = (int)(v >> 16);
                        if (goff != 0)
                            emit_mac_dataptr("_Ga", "%s+%d", gname(tg), goff);
                        else
                            emit_mac_dataptr("_Ga", "%s", gname(tg));
                    } else {
                        fprintf(dst, "DA      $0000\n");          /* NULL: 4-byte zero */
                        fprintf(dst, "                DFB     $00\n");
                        fprintf(dst, "                DFB     $00\n");
                    }
                    prefix_needed = 1;
                    pos += 4;
                } else if (fld->type == LT_INT) {
                    if (prefix_needed) fprintf(dst, "                ");
                    fprintf(dst, "DA      $%04X\n", v & 0xFFFFu);
                    prefix_needed = 1;
                    pos += 2;
                } else if (fld->type == LT_CHAR) {
                    if (prefix_needed) fprintf(dst, "                ");
                    fprintf(dst, "DFB     $%02X\n", v & 0xFFu);
                    prefix_needed = 1;
                    pos += 1;
                } else if (fld->type == LT_LONG ||
                           fld->type == LT_FLOAT) {
                    /* 32-bit constant, little-endian word pair (the
                     * parse side kept the full value — a float field's
                     * IEEE-754 bits — in init_values). */
                    if (prefix_needed) fprintf(dst, "                ");
                    fprintf(dst, "DA      $%04X\n", v & 0xFFFFu);
                    fprintf(dst, "                DA      $%04X\n",
                            (v >> 16) & 0xFFFFu);
                    prefix_needed = 1;
                    pos += 4;
                } else if (fld->type == LT_LLONG ||
                           fld->type == LT_DOUBLE) {
                    /* 64-bit constant, four little-endian words: the low
                     * 32 bits in init_values, the high in init_q. */
                    unsigned q = provided ? init_q(g, idx) : 0;
                    if (prefix_needed) fprintf(dst, "                ");
                    fprintf(dst, "DA      $%04X\n", v & 0xFFFFu);
                    fprintf(dst, "                DA      $%04X\n",
                            (v >> 16) & 0xFFFFu);
                    fprintf(dst, "                DA      $%04X\n",
                            q & 0xFFFFu);
                    fprintf(dst, "                DA      $%04X\n",
                            (q >> 16) & 0xFFFFu);
                    prefix_needed = 1;
                    pos += 8;
                } else if (fld->type == LT_FN_PTR) {
                    /* Fn-ptr field: 4-byte own-bank pointer, same shape as a
                     * scalar fn-ptr global (DA label / DFB ^label / pad).  The
                     * ^bank is a link placeholder recovered via PHK at the
                     * indirect call (own-bank fn-ptr semantics; the multi-bank
                     * far-call reloc of the bank byte is the same open follow-up
                     * as scalar fn-ptr globals).  init_values_hi: 2 = fn idx. */
                    if (prefix_needed) fprintf(dst, "                ");
                    if (provided && g->init_values_hi[idx] == 2) {
                        Func *fn = &g_funcs[g->init_values[idx]];
                        /* Cross-bank fn-ptr in a dispatch table (cmdnames[],
                         * vi keymaps): FGX2_LONG_PTR → global resolution +
                         * bank reloc (see the scalar fn-ptr case above).
                         * g_far_calls guard, not g_data_out (see above). */
                        EMIT_FA_PTR(fn);
                    } else {
                        fprintf(dst, "DA      $0000\n");        /* NULL: 4-byte zero */
                        fprintf(dst, "                DFB     $00\n");
                        fprintf(dst, "                DFB     $00\n");
                    }
                    prefix_needed = 1;
                    pos += 4;
                } else if (ISPTR(fld->type)) {
                    /* Non-char pointer field (int*, void*, struct*, ...):
                     * 4-byte &global(.member) (init_values_hi=3, index low16
                     * + member offset high16) or NULL — same loader-relocated
                     * shape as the char* &global field (telnet togglelist's
                     * `int *variable = &autoflush`). */
                    if (prefix_needed) fprintf(dst, "                ");
                    if (provided && g->init_values_hi[idx] == 3) {
                        Global *tg = &g_globals[v & 0xFFFF];
                        int goff = (int)(v >> 16);
                        if (goff != 0)
                            emit_mac_dataptr("_Ga", "%s+%d", gname(tg), goff);
                        else
                            emit_mac_dataptr("_Ga", "%s", gname(tg));
                    } else {
                        fprintf(dst, "DA      $0000\n");        /* NULL */
                        fprintf(dst, "                DFB     $00\n");
                        fprintf(dst, "                DFB     $00\n");
                    }
                    prefix_needed = 1;
                    pos += 4;
                } else {
                    die(g_cur.line, g_cur.col,
                        "struct-array emit: field type not supported (M22)");
                }
            }
            while (pos < es) {
                if (prefix_needed) fprintf(dst, "                ");
                fprintf(dst, "DFB     $00\n");
                prefix_needed = 1;
                pos++;
            }
        }
        return;
    }
    /* Brace-init array: emit one DA per init value (DA pair for
     * long arrays, DFB for char arrays — char is 1 byte/elem),
     * then zero-fill remainder. */
    if (g->n_init_values > 0) {
        int is_long_arr = (g->type == LT_LONG_ARRAY ||
                           g->type == LT_FLOAT_ARRAY ||
                           g->type == LT_LLONG_ARRAY ||
                           g->type == LT_DOUBLE_ARRAY);
        int is_llong_arr = (g->type == LT_LLONG_ARRAY ||
                            g->type == LT_DOUBLE_ARRAY);
        int is_cptr_arr = (g->type == LT_CHAR_PTR_ARRAY);
        int is_char_arr = (g->type == LT_CHAR_ARRAY);
        int is_fnptr_arr = (ISARY(g->type) && DECREF(g->type) == LT_FN_PTR);
        for (int j = 0; j < g->n_init_values; j++) {
            if (is_fnptr_arr) {
                /* B-7: each item is a target FUNCTION index.
                 * Multi-bank (--far-calls): FGX2_LONG_PTR — global
                 * resolution + bank reloc (the packer may place fn in
                 * another code bank).  Single-bank: bake DA func / DFB ^func
                 * / pad (own-bank; PHK recovers bank at element read).
                 * Checked before is_ptr_array (which a fn-ptr array also
                 * satisfies) so init_values are read as func indices.
                 * g_far_calls guard, not g_data_out (see scalar case).
                 * init_values_hi[j] == 1 -> a `0`/NULL slot: 4-byte zero
                 * (tcsh ed.defns FuncNames[] trailing DUMMY VALUE). */
                if (g->init_values_hi[j] == 1) {
                    fprintf(dst, "DA      $0000\n");   /* NULL: 4-byte zero */
                    fprintf(dst, "                DFB     $00\n");
                    fprintf(dst, "                DFB     $00\n");
                } else {
                    Func *fn = &g_funcs[g->init_values[j]];
                    EMIT_FA_PTR(fn);
                }
            } else if (is_cptr_arr) {
                /* M21: each item is a string-pool label index.
                 * Emit a 4-byte long pointer: DA addr / DFB bank / DFB pad.
                 * Slice 4.5: use FGX2_LONG_PTR in --data-segment mode.
                 * CU-2: init_values_hi[j] discriminates (same tags as
                 * char* struct fields above): 0 = string-pool label,
                 * 1 = NULL, 3 = &global (curses cr_tty.c sflags[]). */
                if (g->init_values_hi[j] == 3) {
                    Global *tg = &g_globals[g->init_values[j]];
                    emit_mac_dataptr("_Ga", "%s", gname(tg));
                } else if (g->init_values_hi[j] == 1) {
                    fprintf(dst, "DA      $0000\n");   /* NULL: 4-byte zero */
                    fprintf(dst, "                DFB     $00\n");
                    fprintf(dst, "                DFB     $00\n");
                } else {
                unsigned lbl = g->init_values[j];
                emit_mac_longptr("_Sa", 0, "%s_S%u", g_tu_prefix, lbl);
                }
            } else if (is_ptr_array(g->type)) {
                /* B-5: each item is a target global's index; emit a
                 * 4-byte long pointer to it (&global).  Data-segment
                 * mode: same-segment far pointer (assembly-resolved
                 * offset + bank reloc — works for extern targets in
                 * another TU).  Single-bank: baked address. */
                Global *tg = &g_globals[g->init_values[j]];
                emit_mac_dataptr("_Ga", "%s", gname(tg));
            } else if (is_char_arr) {
                fprintf(dst, "DFB     $%02X\n",
                        g->init_values[j] & 0xFFu);
            } else {
                fprintf(dst, "DA      $%04X\n",
                        g->init_values[j] & 0xFFFFu);
                if (is_long_arr) {
                    fprintf(dst, "                DA      $%04X\n",
                            g->init_values_hi[j] & 0xFFFFu);
                }
                if (is_llong_arr) {
                    fprintf(dst, "                DA      $%04X\n",
                            init_q(g, j) & 0xFFFFu);
                    fprintf(dst, "                DA      $%04X\n",
                            (init_q(g, j) >> 16) & 0xFFFFu);
                }
            }
            if (j + 1 < g->n_elems)
                fprintf(dst, "                ");
        }
        for (int j = g->n_init_values; j < g->n_elems; j++) {
            if (is_fnptr_arr) {
                fprintf(dst, "DA      $0000\n");          /* NULL fn-ptr: 4-byte zero */
                fprintf(dst, "                DFB     $00\n");
                fprintf(dst, "                DFB     $00\n");
            } else if (is_cptr_arr) {
                /* Zero-fill: NULL pointer = 4 bytes of zero. */
                fprintf(dst, "DA      $0000\n");
                fprintf(dst, "                DFB     $00\n");
                fprintf(dst, "                DFB     $00\n");
            } else if (is_char_arr) {
                fprintf(dst, "DFB     $00\n");
            } else {
                fprintf(dst, "DA      $0000\n");
                if (is_long_arr) {
                    fprintf(dst, "                DA      $0000\n");
                }
                if (is_llong_arr) {
                    fprintf(dst, "                DA      $0000\n");
                    fprintf(dst, "                DA      $0000\n");
                }
            }
            if (j + 1 < g->n_elems)
                fprintf(dst, "                ");
        }
        return;
    }
    if (g->init_global_idx >= 0) {
        /* Pointer initialised to another global's address
         * (`T *p = global;` / `&global;` — sed's labtab = ltab).
         * Multi-bank: same-segment far pointer — the target global
         * lives in seg1 with the cell, so the offset is assembly-
         * resolved and the loader patches the bank at +2 (works for
         * extern targets defined in another TU).  Single-bank: baked
         * DA + DFB ^bank (own-bank link ORG; emit_load_global recovers
         * via the stored byte / PHK).  4-byte long-pointer storage. */
        Global *tg = &g_globals[g->init_global_idx];
        /* The relocation carries the addend: `label+off' for `&arr[k]',
         * `&obj.member' and `arr + k' (K&R A.7.19 -- "the address of a
         * previously declared external or static object plus or minus a
         * constant").  Same shape as the struct-field arm's _Ga above. */
        if (g->init_global_off != 0)
            emit_mac_dataptr("_Spg", "%s+%d", gname(tg),
                             g->init_global_off);
        else
            emit_mac_dataptr("_Spg", "%s", gname(tg));
        return;
    }
    if (g->type == LT_CHAR_ARRAY && g->init_str_label >= 0) {
        /* Big `char x[] = "literal"` (over MAX_INIT_VALUES): the
         * parse side interned a NO-POOL blob instead of expanding
         * per-byte; stream the bytes into the array's own storage
         * here.  Same DFB-per-byte shape as the brace-init char-
         * array arm, zero-filled up to a larger declared size. */
        int off = g_str_lits[g->init_str_label].offset;
        int L   = g_str_lits[g->init_str_label].len;   /* incl. NUL */
        if (L > g->n_elems) L = g->n_elems;
        for (int j = 0; j < L; j++) {
            fprintf(dst, "DFB     $%02X\n",
                    (unsigned char)g_str_pool[off + j]);
            if (j + 1 < g->n_elems)
                fprintf(dst, "                ");
        }
        for (int j = L; j < g->n_elems; j++) {
            fprintf(dst, "DFB     $00\n");
            if (j + 1 < g->n_elems)
                fprintf(dst, "                ");
        }
        return;
    }
    if (g->init_str_label >= 0) {
        /* String-literal-initialised pointer global: emit 4-byte
         * long pointer (offset + own-bank + pad).  Without the
         * extra bytes, n_bytes=4 storage stays half-uninitialised
         * and emit_load_global reads garbage as the bank byte.
         * Slice 4.5: use FGX2_LONG_PTR in --data-segment mode. */
        if (g->type == LT_CHAR_PTR || g->type == LT_INT_PTR ||
            g->type == LT_VOID_PTR) {
            emit_mac_longptr("_Sg", 0, "%s_S%d", g_tu_prefix,
                             g->init_str_label);
            return;
        }
        fprintf(dst, "DA      %s_S%d\n", g_tu_prefix, g->init_str_label);
        if (g->type == LT_CHAR_PTR || g->type == LT_INT_PTR ||
            g->type == LT_VOID_PTR) {
            fprintf(dst, "                DFB     ^%s_S%d\n", g_tu_prefix,
                    g->init_str_label);
            fprintf(dst, "                DFB     $00\n");
        }
        return;
    }
    if (g->type == LT_CHAR) {
        fprintf(dst, "DFB     $%02X\n",
                (unsigned)(g->init_value & 0xFF));
    } else if (ISPTR(g->type)) {
        /* Literal-initialised pointer — ANY pointer type (char, int,
         * void, struct, long, float pointee; ptr-to-ptr; fn-ptr),
         * 4-byte cell.  The old char-/int-/void-pointer whitelist
         * dropped struct pointers into the generic 2-byte DA arm
         * below: `WINDOW *curscr = NULL;` emitted a 2-byte cell, so
         * 4-byte reads picked up the NEXT global's bytes as the bank
         * — curses initscr saw curscr != NULL and delwin'd garbage
         * (kernel double-free storm on target).
         *
         * THE BANK IS THE CONSTANT'S OWN.  K&R A.7.19: "Initializers must
         * evaluate either to a constant or to the address of a previously
         * declared external or static object plus or minus a constant" --
         * `(char *)0xE12000L' is the first kind, a 24-bit address whose
         * bank byte is $E1, and it is not a data-bank address to relocate.
         * The pad byte is 0; `T *p = 0;' stays four zero bytes. */
        fprintf(dst, "DA      $%04X\n",
                (unsigned)(g->init_value & 0xFFFF));
        fprintf(dst, "                DA      $%04X\n",
                (unsigned)(g->init_value_hi & 0x00FF));
    } else if (g->type == LT_LONG || g->type == LT_FLOAT) {
        /* M20/B-6: 4-byte long or IEEE-754 float literal — lo then hi. */
        fprintf(dst, "DA      $%04X\n",
                (unsigned)(g->init_value & 0xFFFF));
        fprintf(dst, "                DA      $%04X\n",
                (unsigned)(g->init_value_hi & 0xFFFF));
    } else if (g->type == LT_LLONG || g->type == LT_DOUBLE) {
        /* 8-byte long long or long double constant, four words from the
         * lowest. */
        fprintf(dst, "DA      $%04X\n",
                (unsigned)(g->init_value & 0xFFFF));
        fprintf(dst, "                DA      $%04X\n",
                (unsigned)(g->init_value_hi & 0xFFFF));
        fprintf(dst, "                DA      $%04X\n",
                g->init_value_q & 0xFFFFu);
        fprintf(dst, "                DA      $%04X\n",
                (g->init_value_q >> 16) & 0xFFFFu);
    } else {
        fprintf(dst, "DA      $%04X\n",
                (unsigned)(g->init_value & 0xFFFF));
    }
    }

void
emit_globals_section(void)
{
    if (g_n_globals == 0) return;
    FILE *dst = g_data_out;
    fprintf(dst, "\n;-------------------------------\n");
    fprintf(dst, "; M7 globals\n");
    fprintf(dst, ";-------------------------------\n");
    for (int i = 0; i < g_n_globals; i++)
        if (!is_block_static(&g_globals[i]))
            emit_one_global(&g_globals[i]);
    emit_block_templates();
}

/* ===== P3-2 T1: far-pointer expression registers (FPR band) ==============
 *
 * The new pointer-value carrier: a pointer rvalue is a self-contained
 * (offset,bank) pair in one of the DP slots _fcc_fpr0.._fcc_fpr7
 * ($98-$B7; offset @ +0..+1, bank @ +2, pad @ +3), never "A plus the
 * shared _fcc_ptr+2".  Deref goes `LDA [_fcc_fprK](,Y)` directly — no
 * staging copy.  Walk-time stack allocator below; caller-save across
 * calls; FPR0 is the pointer-return home.
 *
 * BRING-UP STATE (P3-2.2): vocabulary only — nothing calls these until
 * the walker arms flip.  The carrier bridges (emit_fpr_from/to_carrier)
 * exist for the transition window where a converted producer feeds a
 * not-yet-converted consumer (and vice versa); they are deleted with
 * _fcc_ptr itself at P3-2.7.
 *
 * PAD DISCIPLINE: nothing may rely on the pad byte (+3).  Bank writes
 * are 8-bit; whole-FPR moves copy bank+pad as a word (pad = don't
 * care); pointer comparisons must compare offset word + bank BYTE.
 * Plan: docs/history/plans/2026-07-07-fcc-p32-pointer-model.md. */

#define FCC_NFPR 8

static int g_fpr_top = 0;

/* A CONSTANT-ADDRESS FPR.  `&global + off' with the bank in DBR is a value
 * known at assembly time, and K&R A.7.3.3 makes `E1->MOS' "the same as
 * (*E1).MOS", so a member reached through it is the object at gname+off+m.
 * emit_fpr_addr_global records the symbol here instead of building the
 * register; add_const moves the offset, and the field load, store and
 * inc/dec emit `LDA gname+n'.  Anything else materializes the register
 * first (fpr_sym_flush).  fpr_name() and the label/branch emitters die on a
 * symbolic register, so a consumer that was not taught this fails the build
 * rather than reading an unwritten register. */
static Global *g_fpr_symg[FCC_NFPR];
static int     g_fpr_symo[FCC_NFPR];

int
fpr_is_sym(int k)
{
    return k >= 0 && k < FCC_NFPR && g_fpr_symg[k] != NULL;
}

/* The assembler operand for a symbolic register's address plus n. */
static const char *
fpr_sym_cell(int k, int n)
{
    int off = g_fpr_symo[k] + n;
    if (off == 0) return cellpf("%s", gname(g_fpr_symg[k]));
    if (off < 0)  return cellpf("%s-%d", gname(g_fpr_symg[k]), -off);
    return cellpf("%s+%d", gname(g_fpr_symg[k]), off);
}

/* Build a symbolic register for real: bank from DBR, offset gname+off.  A is
 * preserved (PHA/PLA, no n,S operand between them), so a caller holding a
 * value in A can flush. */
void
fpr_sym_flush(int k)
{
    const char *addr;
    if (!fpr_is_sym(k)) return;
    addr = fpr_sym_cell(k, 0);
    g_fpr_symg[k] = NULL;
    ir_emitf("                PHA\n");
    emit_fpr_bank_dbr(k);
    ir_emitf("                LDA     #%s\n", addr);
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
    ir_emitf("                PLA\n");
}

/* Every live symbolic register, before control flow joins or leaves. */
void
fpr_sym_flush_live(void)
{
    int k;
    for (k = 0; k < g_fpr_top; k++) fpr_sym_flush(k);
}

/* A label or branch with a symbolic register live.  Each path reaching a
 * label must agree on what the register holds, so it is built here, before
 * the branch leaves or the label is placed, with A and the flags kept: a
 * conditional branch reads the flags the compare just set. */
void
fpr_sym_live_check(void)
{
    int k, any = 0;
    for (k = 0; k < g_fpr_top; k++) any |= (g_fpr_symg[k] != NULL);
    if (!any) return;
    ir_emitf("                PHP\n");
    fpr_sym_flush_live();
    ir_emitf("                PLP\n");
}

void
emit_incdec_at_sym(int k, int stride, int is_inc, int is_prefix, int is_ptr,
                   tword rt, int rt_sid)
{
    g_rmw_cell = fpr_sym_cell(k, 0);
    emit_incdec_at_fcc_ptr(stride, is_inc, is_prefix, is_ptr, rt, rt_sid);
    g_rmw_cell = NULL;
}

/* The same in place through register k, which already holds the address:
 * `LDA [_fcc_fprK]', with no copy of it into _fcc_ptr first. */
void
emit_incdec_at_fpr(int k, int stride, int is_inc, int is_prefix, int is_ptr,
                   tword rt, int rt_sid)
{
    g_rmw_ptr = cellp(fpr_name(k));
    emit_incdec_at_fcc_ptr(stride, is_inc, is_prefix, is_ptr, rt, rt_sid);
    g_rmw_ptr = NULL;
}

/* ++/-- of a pointer held at the address fpr k + off, yielding the pointer
 * (old for postfix, new for prefix) in k itself: the address is dead once
 * the word is written back, so the result's offset and bank go straight
 * into k rather than through the carrier.  The offset rides in Y, so k is
 * read as it stands.  A = the offset, as fpr_in leaves it. */
void
emit_ptr_incdec_into_fpr(int k, int off, int stride, int is_inc, int is_prefix)
{
    const char *cell = cellp(fpr_name(k));
    g_rmw_ptr = cell;
    rmw_lda(off);                                                  /* old offset */
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
    if (is_inc) ir_record_raw(IR_ADD_CONST, (unsigned)stride, 0, NULL);
    else        ir_record_raw(IR_SUB_CONST, (unsigned)stride, 0, NULL);
    ir_record_raw(IR_STA_DEREF, off ? 1 : 0, 0, (void *)cell);     /* Y is still off */
    if (is_prefix)
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
    rmw_lda(off + 2);                                 /* bank (and pad) word */
    g_rmw_ptr = NULL;
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(cell));
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cell);
}

int
fpr_alloc(void)
{
    if (g_fpr_top >= FCC_NFPR)
        die(g_cur.line, g_cur.col,
            "fcc-fpr: expression pointer-register pressure (max 8)");
    g_fpr_symg[g_fpr_top] = NULL;
    return g_fpr_top++;
}

void
fpr_free(int k)
{
    if (k != g_fpr_top - 1)
        die(g_cur.line, g_cur.col, "fcc-fpr: non-LIFO register free");
    g_fpr_symg[k] = NULL;
    g_fpr_top--;
}

void
fpr_reset(void)
{
    int k;
    for (k = 0; k < FCC_NFPR; k++) g_fpr_symg[k] = NULL;
    g_fpr_top = 0;
}

int
fpr_live(void)
{
    return g_fpr_top;
}

const char *
fpr_name(int k)
{
    static char buf[16];
    if (fpr_is_sym(k)) {
        die(g_cur.line, g_cur.col,
            "internal: fcc-fpr: a symbolic register named before it was built");
    }
    snprintf(buf, sizeof buf, "_fcc_fpr%d", k);
    return buf;
}

/* Literal (incl. NULL) in pointer context: offset = val, bank = 0.  The
 * ONE place literal-to-pointer bank normalization lives (retires the
 * emit_load_value_bank scatter + the S_RETURN c35 site at conversion).
 * 16-bit STZ on +2 clears bank AND pad — pad stays don't-care. */
void
emit_fpr_lit(int k, unsigned off)
{
    ir_emitf("                LDA     #%u\n", off & 0xFFFFu);
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
    ir_emitf("                STZ     %s+2\n", fpr_name(k));
}

/* Whole-FPR move (offset word + bank/pad word; pad is don't-care). */
void
emit_fpr_mov(int dst, int src)
{
    if (fpr_is_sym(src)) {
        g_fpr_symg[dst] = g_fpr_symg[src];
        g_fpr_symo[dst] = g_fpr_symo[src];
        return;
    }
    g_fpr_symg[dst] = NULL;
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp(fpr_name(src)));
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(dst)));
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp2(fpr_name(src)));
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(fpr_name(dst)));
}

/* Bank materialization: DBR (data addresses) / PB (code addresses).
 * 8-bit dance clobbers only the bank byte. */
void
emit_fpr_bank_dbr(int k)
{
    emit_m8();
    ir_emitf("                PHB\n");
    ir_record_raw(IR_POP_A, 0, 0, NULL);
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(fpr_name(k)));
    emit_m16();
}

void
emit_fpr_bank_pbr(int k)
{
    emit_m8();
    ir_emitf("                PHK\n");
    ir_record_raw(IR_POP_A, 0, 0, NULL);
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(fpr_name(k)));
    emit_m16();
}

/* &global -> fprK.  THE bank-source decision point for data symbols:
 * data-segment builds take DBR (globals live in the data bank), single-
 * bank takes PB (crt0 sets DBR = PB; link-baked ^gname is NOT runtime-
 * valid — transcribed from emit_addr_of_global). */
void
emit_fpr_addr_global(int k, Global *g)
{
    if (!is_block_static(g)) {
        g_fpr_symg[k] = g;
        g_fpr_symo[k] = 0;
        return;
    }
    emit_fpr_bank_dbr(k);
    if (is_block_static(g)) {
        /* --libso: a block static lives in this process's block for its
         * member -- the block's address is in the core cell, the static is
         * at a fixed offset in it (shared libc SP2 spec, section 4). */
        ir_emitf("                LDA     _%s_blk_%s\n", g_libso_name, g->member);
        ir_emitf("                CLC\n");
        ir_emitf("                ADC     #%d\n", block_offset(g));
    } else {
        ir_emitf("                LDA     #%s\n", gname(g));
    }
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
}

/* &local -> fprK: offset = _fcc_fb + 2*slot_first, bank = 0 (the frame is on
 * the bank-0 HW stack; transcribed from emit_addr_of_local's LK_LOCAL arm).
 * Param (&hw-stack) addr-of keeps its structured IR_ADDR_PARAM path and
 * converts with the arm. */
void
emit_fpr_addr_local_soft(int k, Local *lc)
{
    lc->addr_taken = 1;
    emit_m8();
    /* Soft frame -> the bank is DBR (the data bank); hardware frame -> 0.
     * Same reasoning as emit_addr_of_local.  There are THREE sites that MINT a
     * frame address -- emit_addr_of_local, this one, and emit_air_tail's
     * partial-decay row pointer -- and every one must stop naming bank 0 or the
     * escape class survives (design 3.1).  The count read "two" until the
     * 2026-08-02 audit found emit_addr_of_local had no soft arm at all. */
    emit_frame_bank_a();
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(fpr_name(k)));
    emit_m16();
    ir_record_raw(IR_LDA_CELL, 0, 0,
                  (void *)cellp(g_fn_is_soft ? "_fcc_sfp" : "_fcc_fb"));
    ir_record_raw(IR_ADD_CONST, (unsigned)(2 * lc->slot_first), 0, NULL);
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
}

/* Transition bridges: legacy carrier (A = offset, _fcc_ptr+2 = bank)
 * <-> fprK.  DELETED at P3-2.7 with _fcc_ptr. */
void
emit_fpr_from_carrier(int k)
{
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
    emit_m8();
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(fpr_name(k)));
    emit_m16();
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
}

void
emit_fpr_to_carrier(int k)
{
    fpr_sym_flush(k);
    emit_m8();
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp2(fpr_name(k)));
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
    emit_m16();
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
}

/* Deref load through fprK, no staging copy.  Scalar results land in A
 * (+ _fcc_long_hi for 4-byte scalars) exactly like the legacy deref;
 * a POINTER result lands back in fprK itself (offset+bank), consumed
 * by the FPR protocol.  Bank source for the ptr-pointee load keeps the
 * transition split in THIS one place: stored byte under --data-segment,
 * PB re-derivation single-bank (transcribed from
 * the faithful 4-byte pointer read; the split died at P3-2.6). */
void
emit_fpr_deref_load(int k, tword pointee)
{
    if (fpr_is_sym(k)) { emit_fpr_deref_field(k, pointee, 0); return; }
    if (ISPTR(pointee)) {
        ir_record_raw(IR_LDA_DEREF, 0, 0, (void *)cellp(fpr_name(k)));   /* offset word */
        ir_record_raw(IR_PUSH_A, 0, 0, NULL);
        emit_m8();
        ir_emitf("                LDY     #2\n");
        ir_record_raw(IR_LDA_DEREF, 1, 0, (void *)cellp(fpr_name(k)));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(fpr_name(k)));
        emit_m16();
        ir_record_raw(IR_POP_A, 0, 0, NULL);
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
        return;
    }
    if (BTYPE(pointee) == BT_LONG || BTYPE(pointee) == BT_FLOAT) {
        ir_emitf("                LDY     #2\n");
        ir_record_raw(IR_LDA_DEREF, 1, 0, (void *)cellp(fpr_name(k)));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
        ir_record_raw(IR_LDA_DEREF, 0, 0, (void *)cellp(fpr_name(k)));
        return;
    }
    ir_record_raw(IR_LDA_DEREF, 0, 0, (void *)cellp(fpr_name(k)));
    if (BTYPE(pointee) == BT_CHAR || BTYPE(pointee) == BT_VOID)
        ir_emitf("                AND     #$00FF\n");
}

/* Deref store through fprK: A (the RHS value) -> *(fprK+off), the
 * field offset folded into Y.  Word / byte flavors; long and ptr RHS
 * flavors below. */
void
emit_fpr_deref_store_word(int k, int off)
{
    emit_assign_conv(LT_INT);        /* A.7.17: a float truncates, never its bits */
    if (fpr_is_sym(k)) {
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)fpr_sym_cell(k, off));
        return;
    }
    if (off > 0) {
        ir_emitf("                LDY     #%d\n", off);
        ir_record_raw(IR_STA_DEREF, 1, 0, (void *)cellp(fpr_name(k)));
    } else {
        ir_record_raw(IR_STA_DEREF, 0, 0, (void *)cellp(fpr_name(k)));
    }
}

void
emit_fpr_deref_store_byte(int k, int off)
{
    emit_assign_conv(LT_CHAR);       /* A.7.17: a float truncates, never its bits */
    emit_m8();
    if (fpr_is_sym(k)) {
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)fpr_sym_cell(k, off));
        emit_m16();
        return;
    }
    if (off > 0) {
        ir_emitf("                LDY     #%d\n", off);
        ir_record_raw(IR_STA_DEREF, 1, 0, (void *)cellp(fpr_name(k)));
    } else {
        ir_record_raw(IR_STA_DEREF, 0, 0, (void *)cellp(fpr_name(k)));
    }
    emit_m16();
}

/* Pointer arithmetic: offset half only, bank untouched.  A = scaled
 * index (bytes); fprK.offset += A. */
void
emit_fpr_add_a(int k)
{
    if (fpr_is_sym(k)) {
        /* A = the scaled index; the register becomes gname+off+A. */
        const char *addr = fpr_sym_cell(k, 0);
        g_fpr_symg[k] = NULL;
        ir_emitf("                CLC\n");
        ir_emitf("                ADC     #%s\n", addr);
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
        emit_fpr_bank_dbr(k);
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
        return;
    }
    ir_emitf("                CLC\n");
    ir_emitf("                ADC     %s\n", fpr_name(k));
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
}

/* Call-arg push: bank+pad word, then offset word (same wire layout as
 * emit_push_ptr).  Caller tracks g_s_delta (+4), matching the
 * emit_push_ptr_lower/emit_push_ptr split. */
void
emit_fpr_push_lower(int k)
{
    fpr_sym_flush(k);
    ir_emitf("                PEI     %s+2\n", fpr_name(k));
    ir_emitf("                PEI     %s\n", fpr_name(k));
}

void
emit_fpr_push(int k)
{
    emit_fpr_push_lower(k);
    g_s_delta += 4;
}

/* Pointer return: FPR0 is the return home. */
void
emit_fpr_ret(int k)
{
    fpr_sym_flush(k);
    if (k != 0)
        emit_fpr_mov(0, k);
}

/* Non-pointer value (A) materialized as a far pointer: offset = A, bank per
 * `bank`.  The int-operand half of a mixed ptr/int comparison and the
 * int-RHS-into-pointer-home flow both funnel here (NULL normalization shares
 * emit_fpr_lit's shape).
 *
 * apple/fgx#12: `bank` is MANDATORY and has no default on purpose.  Every
 * caller must state which bank an integer becomes when it turns into a pointer,
 * so a new materialization site cannot silently inherit bank 0 -- omitting it
 * is a compile error in fcc itself.  That is the property the first two #12
 * attempts lacked: the decision lived in a global that most sites never set,
 * so a missed site was invisible instead of loud.
 *
 * BANK_ZERO -- a compile-time constant: NULL, the `(char*)-1` error sentinel, a
 * `(char*)0xC000` hardware register.  Bank-agnostic, so the sentinel still
 * matches across banks and fcc #6's bank-inclusive truth test still sees NULL
 * as false.
 *
 * BANK_DBR -- a RUNTIME integer, which under FGX's model addresses the task
 * DATA bank: every int-addressable object (globals, the sbrk heap) lives there,
 * so a bare `int` used as an address is DBR-relative.  This is the 2.11BSD
 * sh/tcsh blok arena idiom, which round-trips arena pointers through `int`
 * (Rcheat(a) = (int)a) and reconstitutes them; the reconstituted pointer MUST
 * land back in the data bank or the free-block chain walk follows a bank-0
 * alias into an infinite loop.
 *
 * BANK_LONG_HI -- a LONG, whose high word IS the bank: FGX maps a pointer to a
 * long as offset:bank (the ptr -> long cast), so the long -> pointer conversion
 * is its inverse, whether a cast or an assignment asks for it.  Leaves A = the
 * bank, not the offset. */
void
emit_fpr_from_a(int k, BankSel bank)
{
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));   /* offset = A */
    if (bank == BANK_ZERO || bank == BANK_LONG_HI) {
        ir_emitf("                STZ     %s+2\n", fpr_name(k));
        if (bank == BANK_LONG_HI) {        /* bank byte = the long's high word */
            ir_emitf("                LDA     _fcc_long_hi\n");
            emit_m8();
            ir_emitf("                STA     %s+2\n", fpr_name(k));
            emit_m16();
        }
        return;
    }
    /* #12: the cached data bank (crt0 snapshots DBR, which is invariant in
     * FGX2 user code) replaces a SEP/PHB/PLA/REP island -- 6 bytes cheaper at
     * every site, and tcsh has 1511 of them. */
    emit_jsr_rt("_fcc_bank_for_int");                               /* A=offset -> bank */
    ir_emitf("                STA     %s+2\n", fpr_name(k));         /* bank */
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp(fpr_name(k)));   /* A = offset (contract) */
}

/* fprK <- a STRUCT VALUE's carrier (A = offset, _fcc_ptr+2 = bank).
 *
 * Same shape and same byte count as emit_fpr_from_a, which is the point: the
 * inline bridge (emit_fpr_from_carrier) costs more, and tcsh packs its 7 code
 * banks with 268 bytes to spare.  See _fcc_bank_from_carrier in
 * toolchain/lib/fcc_runtime.s for why the bank must come from the carrier
 * (apple/fgx#42). */
void
emit_fpr_from_carrier_a(int k)
{
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));   /* offset = A */
    emit_jsr_rt("_fcc_bank_from_carrier");                          /* A = bank */
    ir_emitf("                STA     %s+2\n", fpr_name(k));
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp(fpr_name(k)));   /* A = offset */
}

/* fprK.offset += constant (member offsets, constant indices). */
void
emit_fpr_add_const(int k, int n)
{
    if (n == 0) return;
    if (fpr_is_sym(k)) { g_fpr_symo[k] += n; return; }
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
    ir_record_raw(IR_ADD_CONST, (unsigned)(n), 0, NULL);
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
}

/* Pointer equality: offset word AND bank BYTE (pad discipline: never
 * word-compare +2).  Result 0/1 in A, replacing the legacy
 * ptr->long reinterpret + _fcc_long_eq route.  REP #$20 preserves N/Z,
 * so the 8-bit bank CMP's flags survive into the 16-bit branch. */
void
emit_fpr_cmp(int k1, int k2, int is_ne)
{
    fpr_sym_flush(k1);
    fpr_sym_flush(k2);
    int lab_diff = new_label();
    int lab_end  = new_label();
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp(fpr_name(k1)));
    ir_emitf("                CMP     %s\n", fpr_name(k2));
    emit_bne_label(lab_diff);
    emit_m8();
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp2(fpr_name(k1)));
    ir_emitf("                CMP     %s+2\n", fpr_name(k2));
    emit_m16();
    emit_bne_label(lab_diff);
    ir_emitf("                LDA     #%d\n", is_ne ? 0 : 1);
    emit_bra_label(lab_end);
    emit_label(lab_diff);
    ir_emitf("                LDA     #%d\n", is_ne ? 1 : 0);
    emit_label(lab_end);
}

/* Field/deref load through fprK with the field offset FOLDED INTO Y
 * (cost lever #1: no ADC-into-offset, no staging).  Transcribes
 * emit_deref_ptr_field's semantics onto the FPR carrier:
 *   - 4-byte scalar (long/float): hi @ off+2 -> _fcc_long_hi, lo -> A
 *   - pointer pointee (any ISPTR, fn-ptrs included): the stored offset
 *     and bank, both read BEFORE fprK is overwritten; the bank comes with
 *     its don't-care pad as one word.
 *   - char/void: byte + mask; int: word.
 * Scalar results -> A; a pointer result lands back in fprK. */
void
emit_fpr_deref_field(int k, tword t, int off)
{
    if (fpr_is_sym(k)) {
        /* The object is at a fixed address: read it there.  A pointer result
         * replaces the register, which then holds a value, not an address. */
        if (ISPTR(t)) {
            /* The bank and pad as a word: the pad is don't-care (the PAD
             * DISCIPLINE above), so no 8-bit read is needed for the bank. */
            const char *lo = fpr_sym_cell(k, off), *hi = fpr_sym_cell(k, off + 2);
            g_fpr_symg[k] = NULL;
            ir_record_raw(IR_LDA_CELL, 0, 0, (void *)hi);
            ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(fpr_name(k)));
            ir_record_raw(IR_LDA_CELL, 0, 0, (void *)lo);
            ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
            return;
        }
        if (BT_IS_QUAD(BTYPE(t))) {
            ir_record_raw(IR_LDA_CELL, 0, 0, (void *)fpr_sym_cell(k, off + 6));
            ir_emitf("                STA     _fcc_q3\n");
            ir_record_raw(IR_LDA_CELL, 0, 0, (void *)fpr_sym_cell(k, off + 4));
            ir_emitf("                STA     _fcc_q2\n");
            ir_record_raw(IR_LDA_CELL, 0, 0, (void *)fpr_sym_cell(k, off + 2));
            ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
            ir_record_raw(IR_LDA_CELL, 0, 0, (void *)fpr_sym_cell(k, off));
                return;
        }
        if (BTYPE(t) == BT_LONG || BTYPE(t) == BT_FLOAT) {
            ir_record_raw(IR_LDA_CELL, 0, 0, (void *)fpr_sym_cell(k, off + 2));
            ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
            ir_record_raw(IR_LDA_CELL, 0, 0, (void *)fpr_sym_cell(k, off));
                return;
        }
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)fpr_sym_cell(k, off));
        if (BTYPE(t) == BT_CHAR || BTYPE(t) == BT_VOID)
            ir_emitf("                AND     #$00FF\n");
        return;
    }
    if (ISPTR(t)) {
        /* The offset, then the bank and pad as one word: both read before
         * fprK is written, and A = the offset at the end as before.  The
         * pad is don't-care (the PAD DISCIPLINE above: every consumer
         * masks it), so the bank needs no 8-bit read. */
        if (off > 0) {
            ir_emitf("                LDY     #%d\n", off);
            ir_record_raw(IR_LDA_DEREF, 1, 0, (void *)cellp(fpr_name(k)));
        } else {
            ir_record_raw(IR_LDA_DEREF, 0, 0, (void *)cellp(fpr_name(k)));
        }
        ir_record_raw(IR_PUSH_A, 0, 0, NULL);                       /* new offset */
        if (off > 0) {
            ir_emitf("                INY\n");
            ir_emitf("                INY\n");
        } else {
            ir_emitf("                LDY     #2\n");
        }
        ir_record_raw(IR_LDA_DEREF, 1, 0, (void *)cellp(fpr_name(k)));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(fpr_name(k)));
        ir_record_raw(IR_POP_A, 0, 0, NULL);
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
        return;
    }
    if (BT_IS_QUAD(BTYPE(t))) {                /* four words, w0 last */
        ir_emitf("                LDY     #%d\n", off + 6);
        ir_record_raw(IR_LDA_DEREF, 1, 0, (void *)cellp(fpr_name(k)));
        ir_emitf("                STA     _fcc_q3\n");
        ir_emitf("                LDY     #%d\n", off + 4);
        ir_record_raw(IR_LDA_DEREF, 1, 0, (void *)cellp(fpr_name(k)));
        ir_emitf("                STA     _fcc_q2\n");
        ir_emitf("                LDY     #%d\n", off + 2);
        ir_record_raw(IR_LDA_DEREF, 1, 0, (void *)cellp(fpr_name(k)));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
        ir_emitf("                LDY     #%d\n", off);
        ir_record_raw(IR_LDA_DEREF, 1, 0, (void *)cellp(fpr_name(k)));
        return;
    }
    if (BTYPE(t) == BT_LONG || BTYPE(t) == BT_FLOAT) {
        ir_emitf("                LDY     #%d\n", off + 2);
        ir_record_raw(IR_LDA_DEREF, 1, 0, (void *)cellp(fpr_name(k)));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
        if (off > 0) {
            ir_emitf("                LDY     #%d\n", off);
            ir_record_raw(IR_LDA_DEREF, 1, 0, (void *)cellp(fpr_name(k)));
        } else {
            ir_record_raw(IR_LDA_DEREF, 0, 0, (void *)cellp(fpr_name(k)));
        }
        return;
    }
    if (off > 0) {
        ir_emitf("                LDY     #%d\n", off);
        ir_record_raw(IR_LDA_DEREF, 1, 0, (void *)cellp(fpr_name(k)));
    } else {
        ir_record_raw(IR_LDA_DEREF, 0, 0, (void *)cellp(fpr_name(k)));
    }
    if (BTYPE(t) == BT_CHAR || BTYPE(t) == BT_VOID)
        ir_emitf("                AND     #$00FF\n");
}

/* 4-byte scalar store through fprK: A (+_fcc_long_hi) -> *(fprK+off).
 * Caller has already widened/converted an int RHS.  Result = RHS low
 * word back in A (chained-assign convention). */
void
emit_fpr_deref_store_long(int k, int off)
{
    fpr_sym_flush(k);
    if (g_expr_type == LT_DOUBLE)
        emit_from_double(LT_LONG);
    if (off > 0) {
        ir_emitf("                LDY     #%d\n", off);
        ir_record_raw(IR_STA_DEREF, 1, 0, (void *)cellp(fpr_name(k)));
    } else {
        ir_record_raw(IR_STA_DEREF, 0, 0, (void *)cellp(fpr_name(k)));
    }
    ir_record_raw(IR_TAX, 0, 0, NULL);                           /* RHS low */
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
    ir_emitf("                LDY     #%d\n", off + 2);
    ir_record_raw(IR_STA_DEREF, 1, 0, (void *)cellp(fpr_name(k)));
    ir_record_raw(IR_TXA, 0, 0, NULL);
}

/* 8-byte long long store through fprK: the carrier -> *(fprK+off).  The
 * value is already in long long form.  Result = w0 back in A. */
void
emit_fpr_deref_store_llong(int k, int off)
{
    fpr_sym_flush(k);
    ir_emitf("                LDY     #%d\n", off);
    ir_record_raw(IR_STA_DEREF, 1, 0, (void *)cellp(fpr_name(k)));
    ir_record_raw(IR_TAX, 0, 0, NULL);
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
    ir_emitf("                LDY     #%d\n", off + 2);
    ir_record_raw(IR_STA_DEREF, 1, 0, (void *)cellp(fpr_name(k)));
    ir_emitf("                LDA     _fcc_q2\n");
    ir_emitf("                LDY     #%d\n", off + 4);
    ir_record_raw(IR_STA_DEREF, 1, 0, (void *)cellp(fpr_name(k)));
    ir_emitf("                LDA     _fcc_q3\n");
    ir_emitf("                LDY     #%d\n", off + 6);
    ir_record_raw(IR_STA_DEREF, 1, 0, (void *)cellp(fpr_name(k)));
    ir_record_raw(IR_TXA, 0, 0, NULL);
}

/* Pointer store through a pointer: *(fprKD+off) = fprKS (offset word +
 * bank BYTE; the destination pad byte is left as-is — don't-care).
 * The RHS stays live in fprKS as the assignment's result. */
void
emit_fpr_deref_store_ptr(int kd, int ks, int off)
{
    fpr_sym_flush(kd);
    fpr_sym_flush(ks);
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp(fpr_name(ks)));
    if (off > 0) {
        ir_emitf("                LDY     #%d\n", off);
        ir_record_raw(IR_STA_DEREF, 1, 0, (void *)cellp(fpr_name(kd)));
    } else {
        ir_record_raw(IR_STA_DEREF, 0, 0, (void *)cellp(fpr_name(kd)));
    }
    emit_m8();
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp2(fpr_name(ks)));
    ir_emitf("                LDY     #%d\n", off + 2);
    ir_record_raw(IR_STA_DEREF, 1, 0, (void *)cellp(fpr_name(kd)));
    emit_m16();
}

/* Pointer-typed GLOBAL home <-> FPR (textual today, so converted
 * natively; ptr LOCAL homes stay on the structured IR path + carrier
 * bridges until P3-2.5).  Load transcribes emit_load_global's stored-
 * byte-vs-PHK split; store writes bank+pad as a word (pad don't-care,
 * matching the legacy 16-bit bank write). */
void
emit_fpr_load_global_ptr(int k, Global *g)
{
    refuse_block_static(g, "emit_fpr_load_global_ptr");
    emit_m8();
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp2(gname(g)));
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(fpr_name(k)));
    emit_m16();
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp(gname(g)));
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
}

void
emit_fpr_store_global_ptr(int k, Global *g)
{
    fpr_sym_flush(k);
    refuse_block_static(g, "emit_fpr_store_global_ptr");
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(gname(g)));
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp2(fpr_name(k)));
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(gname(g)));
}

/* String literal -> fprK: offset = the S-label, bank = DBR (the string
 * pool lives in the data segment — one-mode). */
void
emit_fpr_lit_str(int k, int sidx)
{
    if (g_libso)
        emit_fpr_bank_pbr(k);    /* --libso: the literal is in this code bank */
    else
        emit_fpr_bank_dbr(k);
    ir_emitf("                LDA     #%s_S%d\n", g_tu_prefix, sidx);
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
}

/* &function -> fprK.  Far: via a hidden data-segment FGX2_LONG_PTR
 * (fgx_ld resolves the cross-segment offset + relocs the bank byte);
 * single-bank: PB + in-bank offset.  Transcribes emit_addr_of_func. */
void
emit_fpr_addr_func(int k, Func *fn)
{
    {
        int lab = new_label();
        fprintf(g_data_out, "%s_FA%d       ", g_tu_prefix, lab);
        EMIT_FA_PTR(fn);
        emit_m8();
        ir_emitf("                LDA     %s_FA%d+2\n", g_tu_prefix, lab);
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(fpr_name(k)));
        emit_m16();
        ir_emitf("                LDA     %s_FA%d\n", g_tu_prefix, lab);
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
    }
}

/* Caller-save discipline: spill every live FPR to the HW stack before
 * a call that can reach compiled C (which uses the band freely), pop
 * after.  MUST run before any args are pushed (args must sit adjacent
 * above the return address).  Restore preserves A (the call result);
 * _fcc_long_hi / the carrier bridges are untouched by the pops. */
int
emit_fpr_spill_live(void)
{
    fpr_sym_flush_live();
    int n = g_fpr_top;
    for (int k = 0; k < n; k++)
        emit_fpr_push_lower(k);
    g_s_delta += 4 * n;
    return n;
}

void
emit_fpr_restore_live(int n)
{
    if (n == 0) return;
    ir_record_raw(IR_TAY, 0, 0, NULL);
    for (int k = n - 1; k >= 0; k--) {
        ir_record_raw(IR_POP_A, 0, 0, NULL);
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
        ir_record_raw(IR_POP_A, 0, 0, NULL);
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(fpr_name(k)));
    }
    ir_record_raw(IR_TYA, 0, 0, NULL);
    g_s_delta -= 4 * n;
}

/* Small FPR accessors for the walker (fpr_name is emit.c-private). */
void
emit_fpr_to_a(int k)
{
    fpr_sym_flush(k);
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
}

void
emit_fpr_off_from_a(int k)
{
    fpr_sym_flush(k);
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
}

/* A = fprK1.offset - fprK2.offset (ptr - ptr, pre-stride-divide). */
void
emit_fpr_diff(int k1, int k2)
{
    fpr_sym_flush(k1);
    fpr_sym_flush(k2);
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp(fpr_name(k1)));
    ir_emitf("                SEC\n");
    ir_emitf("                SBC     %s\n", fpr_name(k2));
}

/* fprK.offset -= A (ptr - int, scaled index in A). */
void
emit_fpr_sub_a(int k)
{
    fpr_sym_flush(k);
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
    ir_emitf("                SEC\n");
    ir_emitf("                SBC     _fcc_tmp_b\n");
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
}

/* ++g/g++ on a POINTER GLOBAL home: home.offset = fprK.offset + delta
 * (home bank byte untouched); prefix also advances fprK so it carries
 * the NEW value, postfix leaves fprK = OLD.  (Pointer LOCAL homes keep
 * the structured-IR bridge path so promotion is undisturbed.) */
void
emit_fpr_incdec_home_global(int k, Global *g, int delta, int update_fpr)
{
    fpr_sym_flush(k);
    refuse_block_static(g, "emit_fpr_incdec_home_global");
    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
    if (delta >= 0) {
        ir_record_raw(IR_ADD_CONST, (unsigned)(delta), 0, NULL);
    } else {
        ir_record_raw(IR_SUB_CONST, (unsigned)(-delta), 0, NULL);
    }
    if (update_fpr)
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(gname(g)));
}

/* Pointer-typed struct FIELD value -> fprK: read the STORED (offset,
 * bank) pair in BOTH modes.  FGX2: loader-patched / runtime-stamped.
 * FGX1: runtime stores stamp valid banks, and soft-stack/heap structs
 * live OUTSIDE the program bank — PHK re-derivation read the wrong
 * bank (the forward_struct regression), and the pre-FPR code only got
 * it right by stale-carrier luck.  Link-baked static ptr-field
 * initializers were already broken on FGX1 (no bank reloc;
 * global_ptr_init is FGX-INCOMPAT there).  FN_PTR stays on the legacy
 * helper (single-bank code pointers ARE own-bank; far reads the
 * reloc'd byte). */
void
emit_fpr_load_field(int k, Local *lc, Global *g, Field *f)
{
    refuse_block_static(g, "emit_fpr_load_field");
    if (lc) {
        emit_field_lda(lc, f->byte_offset + 2);        /* bank+pad word */
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(fpr_name(k)));
        emit_field_lda(lc, f->byte_offset);            /* offset word */
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
    } else {
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset + 2));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(fpr_name(k)));
        ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellpf("%s+%d", gname(g), f->byte_offset));
        ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
    }
}

/* Struct copy through two FPRs: nbytes (even) from *fprKS to *fprKD. */
void
emit_fpr_struct_copy(int kd, int ks, int nbytes)
{
    fpr_sym_flush(kd);
    fpr_sym_flush(ks);
    int lab = new_label();
    ir_emitf("                LDY     #%d\n", nbytes - 2);
    ir_emitf("%s_L%d\n", g_tu_prefix, lab);
    ir_record_raw(IR_LDA_DEREF, 1, 0, (void *)cellp(fpr_name(ks)));
    ir_record_raw(IR_STA_DEREF, 1, 0, (void *)cellp(fpr_name(kd)));
    ir_emitf("                DEY\n");
    ir_emitf("                DEY\n");
    emit_bcond(IRC_BPL, lab, 0);
}

/* Reserve an nbytes (even) window on the HW stack for a by-value struct
 * ARG and point fprK at it (offset = S+1, bank 0 — the hw stack lives in
 * bank 0).  Paired with emit_fpr_struct_copy; retires the by-value arg's
 * _fcc_ptr2 staging (P3-2.4).  Caller bumps g_s_delta.  MVN stays
 * unusable: its bank bytes are compile-time immediates, the source bank
 * is a runtime value. */
void
emit_fpr_arg_window(int k, int nbytes)
{
    fpr_sym_flush(k);
    ir_emitf("                TSC\n");
    ir_record_raw(IR_SUB_CONST, (unsigned)(nbytes), 0, NULL);
    ir_emitf("                TCS\n");
    ir_emitf("                TSC\n");
    ir_emitf("                INC\n");
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
    ir_emitf("                STZ     %s+2\n", fpr_name(k));
}
