#include "fcc.h"
/* arr_row_elem_size -- the ELEMENT size a multi-dimensional array's row stride
 * is built from.  apple/fgx#192.
 *
 * The two multi-dim declaration sites (parse_stmt.c's local and global array
 * paths) both wrote `es = (t == LT_CHAR_ARRAY) ? 1 : 2` inline, so a
 * `long l[3][4]` got a row stride of 8 instead of 16 and every subscript past
 * the first dimension landed inside the wrong row -- silently, in the READ
 * path as much as in the address one.  The 1-D ladders below already had the
 * 4-byte arms; only the multi-dim sites lacked them.
 *
 * IT IS NOT UNIFIED WITH THOSE TWO LADDERS, deliberately.  They answer a wider
 * question -- the stride of any symbol, pointers included, and they differ
 * from each other in their pointer arms for reasons their own comments give.
 * This answers only "how big is one element of this ARRAY", which is all a row
 * stride needs and is the same at both call sites.  Folding four ladders into
 * one is a separate change with its own risk; three copies of a number was the
 * defect, and one caller-shaped helper removes the two that mattered. */
int
arr_row_elem_size(tword t)
{
    if (is_ptr_array(t))                            return 4;
    if (t == LT_CHAR_ARRAY)                         return 1;
    if (t == LT_LONG_ARRAY || t == LT_FLOAT_ARRAY)  return 4;
    if (t == LT_LLONG_ARRAY || t == LT_DOUBLE_ARRAY) return 8;
    return 2;
}


int
user_labels_lookup(const char *name, int name_len)
{
    const char *cn = lex_intern_ident(name, name_len);   /* T2-1 canonical */
    for (int i = 0; i < g_n_user_labels; i++) {
        if (g_user_labels[i].name == cn)
            return i;
    }
    return -1;
}

int
user_labels_intern(const char *name, int name_len, int line, int col)
{
    int idx = user_labels_lookup(name, name_len);
    if (idx >= 0) return idx;
    if (g_n_user_labels >= MAX_USER_LABELS)
        die(line, col, "too many user labels (max " FCC_STR(MAX_USER_LABELS) ")");
    int nl = name_len < MAX_IDENT - 1 ? name_len : MAX_IDENT - 1;
    g_user_labels[g_n_user_labels].name = lex_intern_ident(name, nl);
    g_user_labels[g_n_user_labels].defined = 0;
    g_user_labels[g_n_user_labels].referenced = 0;
    return g_n_user_labels++;
}

void
user_labels_reset(void)
{
    g_n_user_labels = 0;
}

void
locals_reset(const char *fname, int fname_len)
{
    g_n_locals        = 0;
    g_n_params        = 0;
    g_n_local_decls   = 0;
    g_total_slots     = 0;
    g_s_delta         = 0;
    g_n_static_aliases = 0;   /* C-3 */
    if (fname_len >= MAX_IDENT) fname_len = MAX_IDENT - 1;
    memcpy(g_func_name, fname, (size_t)fname_len);
    g_func_name[fname_len] = '\0';
    user_labels_reset();
}

void
locals_declare(const char *name, int name_len, LocalKind kind,
               LocalType type, int slot_count, int line, int col)
{
    if (name_len >= MAX_IDENT) {
        die(line, col, "identifier too long");
    }
    /* M21+: allow same-name shadowing.  Each redecl gets a fresh slot;
     * locals_lookup scans newest-first so the latest binding wins.
     * Not full C scope semantics (no automatic pop on block exit), but
     * matches the common pattern of `int idx` in mutually-exclusive
     * branches. */
    if (g_n_locals >= MAX_LOCALS) {
        die(line, col, "too many local variables (max 128)");
    }
    /* Long pointers (24-bit) occupy 2 slots (4 bytes) in the local frame.
     * LT_FN_PTR, LT_LONG_PTR, and LT_STRUCT_PTR join INT_PTR/CHAR_PTR/
     * VOID_PTR in the 4-byte tier.  M20 LT_LONG also 4-byte.
     * STRUCT_PTR joined the 4-byte tier (2026-05-25) after the 2-byte
     * shape silently corrupted writes via [_fcc_ptr] because the bank
     * byte wasn't carried — emit_deref_ptr_field_store reads 4 bytes
     * from the stack regardless. */
    int eff_slots = slot_count;
    if (kind == LK_LOCAL && (ISPTR(type) || type == LT_LONG || type == LT_FLOAT)) {
        /* B-3: a pointer of ANY depth is 4-byte (2-slot) storage.  Was an
         * exact _PTR list that missed depth-2 pointers; under-allocating a
         * depth-2 local to 2 bytes corrupted the frame (the bank byte was
         * stored past the slot, clobbering the return address). */
        eff_slots = slot_count * 2;
    }
    if (kind == LK_LOCAL && IS_QUAD(type))
        eff_slots = slot_count * 4;             /* long long: 8 bytes */
    /* A frame lives in the per-task software-stack region, so it may be far
     * larger than the old 4KB bank-0 hardware stack — capped at MAX_SOFT_SLOTS,
     * leaving region headroom for the call chain. */
    if (kind == LK_LOCAL) {
        if (g_total_slots + eff_slots > MAX_SOFT_SLOTS) {
            char m[64];
            snprintf(m, sizeof m, "too many local slots (max %d)", MAX_SOFT_SLOTS);
            die(line, col, m);
        }
    }
    g_locals[g_n_locals].name = lex_intern_ident(name, name_len);
    g_locals[g_n_locals].kind       = kind;
    g_locals[g_n_locals].type       = type;
    g_locals[g_n_locals].slot_count = eff_slots;
    g_locals[g_n_locals].struct_id  = -1;             /* M8: caller patches for struct decls */
    g_locals[g_n_locals].fn_sig_id  = -1;             /* M18: caller patches for fn-ptr decls */
    g_locals[g_n_locals].n_dims     = 1;              /* M19: caller patches for multi-dim */
    g_locals[g_n_locals].dims[0]    = slot_count;
    g_locals[g_n_locals].is_unsigned = 0;             /* A-1: caller patches for unsigned */
    g_locals[g_n_locals].addr_taken    = 0;           /* fcc2 P1.3-inc2: promotion guards */
    g_locals[g_n_locals].raw_accessed  = 0;
    g_locals[g_n_locals].loop_accessed = 0;
    g_locals[g_n_locals].scope_hidden  = 0;           /* K&R A.11.1 block scope */
    g_locals[g_n_locals].homed_from    = -1;
    /* Use-before-set: entries are REUSED across functions and this routine
     * assigns field by field rather than clearing, so these must be reset
     * here or the previous occupant's verdict is inherited. */
    g_locals[g_n_locals].n_stores       = 0;
    g_locals[g_n_locals].n_loads        = 0;
    g_locals[g_n_locals].use_before_set = 0;
    g_locals[g_n_locals].ubs_in_loop    = 0;
    g_locals[g_n_locals].array_bytes    = 0;
    g_locals[g_n_locals].decl_line      = line;
    g_locals[g_n_locals].decl_col       = col;
    {
        int _es = is_ptr_array(type) ? 4 :   /* ptr-element arrays: 4-byte far ptrs */
                  (ISPTR(type) && ISPTR(DECREF(type))) ? 4 : /* T**: element is a 4-byte far ptr (mirror ptr_stride; store path uses row_stride raw) */
                  (type == LT_CHAR || type == LT_CHAR_ARRAY ||
                   type == LT_CHAR_PTR || type == LT_VOID_PTR) ? 1 :
                  (type == LT_LONG || type == LT_LONG_ARRAY ||
                   type == LT_LONG_PTR ||
                   type == LT_FLOAT || type == LT_FLOAT_ARRAY ||
                   type == LT_FLOAT_PTR) ? 4 :        /* B-6: float is 4-byte */
                  BT_IS_QUAD(BTYPE(type)) ? 8 : 2;
        g_locals[g_n_locals].row_stride = _es;
    }
    if (ISPTR(type) || type == LT_LONG || type == LT_FLOAT) {   /* B-3/B-6: 4-byte scalar */
        g_locals[g_n_locals].byte_size = 4;
    } else if (IS_QUAD(type)) {
        g_locals[g_n_locals].byte_size = 8;
    } else {
        g_locals[g_n_locals].byte_size = slot_count * 2;
    }
    if (kind == LK_PARAM) {
        g_locals[g_n_locals].slot_first = g_n_params;
        g_n_params++;
    } else {
        g_locals[g_n_locals].slot_first = g_total_slots;
        g_total_slots += eff_slots;
        g_n_local_decls++;
    }
    g_n_locals++;
}

/* Lay out the frame slots of the locals declared from index `first` on:
 * scalars (8 bytes or less) first, in declaration order, then aggregates, in
 * declaration order.  A 65816 `n,S` displacement is 8 bits, and a local past
 * offset 255 is reached through _fcc_fp at about 20 cycles an access
 * (slot_needs_far), so an array declared ahead of the scalars used to push
 * every scalar onto that path.  An aggregate past 255 costs the far path once,
 * for its base address.
 *
 * K&R A.7.9 leaves the relative addresses of separate automatics open:
 * "Pointer comparison is defined only for parts of the same object ...
 * Otherwise, pointer comparison is undefined."  Called once the function
 * body's tree is built and before it is walked, which is the earliest every
 * local is known and the latest before any offset is emitted. */
/* The parameter whose own address node n takes, or NULL: `&p', `&s.f', or an
 * `&chain' rooted at p whose first step is not through p's value. */
Local *
param_addr_node(int n)
{
    Node  *a = &g_ast[n];
    Local *lc;
    int    step;

    if (a->kind == N_ADDR_VAR || a->kind == N_ADDR_DOT_BARE ||
        a->kind == N_ADDR_DOT_ARRFIELD || a->kind == N_ADDR_ARR_ELEM ||
        a->kind == N_ADDR_ARR_ELEM_MD)
        lc = a->sym_lc;
    else if (a->kind == N_ADDR_LV_E && a->a >= 0 &&
             g_ast[a->a].kind == N_LV_CHAIN && g_ast[a->a].a < 0) {
        lc   = g_ast[a->a].sym_lc;
        step = g_ast[a->a].b;
        if (step >= 0 && (g_ast[step].kind == N_LV_STEP_ARROW ||
                          g_ast[step].kind == N_LV_STEP_DEREF ||
                          g_ast[step].kind == N_LV_STEP_INDEX))
            return NULL;
    } else
        return NULL;
    return (lc && (lc->kind == LK_PARAM || lc->homed_from >= 0)) ? lc : NULL;
}

/* A parameter sits above the whole frame, at 6 + FRAMESIZE + its offset from
 * S, so a frame of more than about 250 bytes -- one BUFSIZ buffer -- puts
 * every parameter on the _fcc_fp path, six instructions an access.  K&R
 * A.10.1: "the parameters are understood to be declared just after the
 * beginning of the compound statement constituting the function's body",
 * and "the arguments are converted as necessary and assigned to the
 * parameters".  So each scalar or pointer parameter of such a function is
 * given a frame slot, assigned from where the caller pushed it at entry
 * (ir_emit_param_seeds), and read and written there.
 *
 * Its address is what this cannot move: `&last' is how stdarg and varargs
 * reach the arguments after it.  A function that takes the address of any
 * parameter keeps them all where they are; the walker refuses such a node on
 * a homed one, so a form this scan misjudges is a compile error, not a stray
 * pointer.  main's argc and argv are bound into their pushed slots before the
 * seed point, so main keeps its parameters too.  Returns the slots added. */
static int
params_home(int first)
{
    int i, n, need = 0, bytes = 0;

    if (g_fn_is_soft || g_main_argc_local || g_main_argv_local)
        return 0;
    for (i = 0; i < first; i++)
        if (g_locals[i].kind == LK_PARAM)
            bytes += g_locals[i].byte_size;
    if (6 + 2 * g_total_slots + bytes < 224)      /* leaves room for pushes */
        return 0;
    for (n = 0; n < g_n_ast; n++)
        if (param_addr_node(n))
            return 0;
    for (i = 0; i < first; i++) {
        Local *lc = &g_locals[i];
        if (lc->kind != LK_PARAM)
            continue;
        if (!(lc->type == LT_INT || lc->type == LT_CHAR || lc->type == LT_LONG ||
              (ISPTR(lc->type) && lc->type != LT_FN_PTR)))
            continue;
        lc->homed_from = lc->slot_first;
        lc->kind       = LK_LOCAL;
        lc->slot_count = lc->byte_size / 2;
        lc->n_stores   = 1;                     /* the entry copy */
        need += lc->slot_count;
    }
    return need;
}

void
locals_layout(int first)
{
    int slot = -1;
    int homed = params_home(first);
    if (homed) {
        slot = 0;                               /* the frame's first slot */
        g_total_slots += homed;
    }
    for (int pass = 0; pass < 2; pass++) {
        for (int i = homed ? 0 : first; i < g_n_locals; i++) {
            Local *lc = &g_locals[i];
            if (lc->kind != LK_LOCAL)
                continue;
            if (slot < 0)
                slot = lc->slot_first;
            if ((lc->slot_count > 4) != pass)
                continue;
            lc->slot_first = slot;
            slot += lc->slot_count;
        }
    }
}

Local *
locals_lookup(const char *name, int name_len)
{
    /* T2-1: names are canonical interned pointers, so the scan is a
     * POINTER compare.  Canonicalize the query first — callers may pass
     * any (ptr,len), token-interned or not; the intern probe is O(1) and
     * replaces a strlen+memcmp against EVERY entry. */
    const char *cn = lex_intern_ident(name, name_len);
    /* Scan newest-first so the latest decl shadows earlier same-name
     * locals (M21 shadowing). */
    for (int i = g_n_locals - 1; i >= 0; i--) {
        if (g_locals[i].name == cn && !g_locals[i].scope_hidden)
            return &g_locals[i];
    }
    return NULL;
}

/* Bits 32-63 of init value n of a long long array or member.  The table is
 * allocated by the first long long value stored, so every other global goes
 * without it. */
unsigned
init_q(const Global *g, int n)
{
    return g->init_values_q ? g->init_values_q[n] : 0;
}

void
init_put_q(Global *g, int n, long v)
{
    if (g->init_values_q == NULL) {
        g->init_values_q = calloc(MAX_INIT_VALUES, sizeof (unsigned));
        if (g->init_values_q == NULL)
            die(0, 0, "out of memory for a long long initializer");
    }
    g->init_values_q[n] = (unsigned)((unsigned long)v >> 32);
}

Global *
globals_lookup(const char *name, int name_len)
{
    const char *cn = lex_intern_ident(name, name_len);   /* T2-1 canonical */
    /* C-3: a function's static locals shadow same-named file globals —
     * check the per-function alias table first. */
    for (int i = 0; i < g_n_static_aliases; i++) {
        if (g_static_aliases[i].name == cn)
            return &g_globals[g_static_aliases[i].global_idx];
    }
    for (int i = 0; i < g_n_globals; i++) {
        if (g_globals[i].name == cn)              /* T2-1: pointer scan */
            return &g_globals[i];
    }
    return NULL;
}

int
structs_lookup(const char *name, int name_len)
{
    const char *cn = lex_intern_ident(name, name_len);   /* T2-1 canonical */
    /* BACKWARDS, AND SKIPPING WHAT HAS GONE OUT OF SCOPE.  K&R A.11.1: "The
     * scope of a structure, union, or enumeration tag ... persists to the end
     * of a translation unit (for declarations at the external level) or to the
     * end of the block (for declarations within a function)."  Searching from
     * the end finds the INNERMOST tag of a name, which is the one an inner
     * block's declaration is entitled to shadow with. */
    for (int i = g_n_structs - 1; i >= 0; i--) {
        if (g_structs[i].name == cn && !g_structs[i].scope_hidden)
            return i;
    }
    return -1;
}

int
typedefs_lookup(const char *name, int name_len)
{
    const char *cn = lex_intern_ident(name, name_len);   /* T2-1 canonical */
    for (int i = 0; i < g_n_typedefs; i++) {
        if (g_typedefs[i].name == cn)
            return i;
    }
    return -1;
}

int
enum_consts_lookup(const char *name, int name_len)
{
    const char *cn = lex_intern_ident(name, name_len);   /* T2-1 canonical */
    for (int i = 0; i < g_n_enum_consts; i++) {
        if (g_enum_consts[i].name == cn)
            return i;
    }
    return -1;
}

int
fn_sig_intern(LocalType ret, int n_params, LocalType *params,
              int *param_struct_ids, int is_variadic, int ret_unsigned)
{
    for (int i = 0; i < g_n_fn_sigs; i++) {
        if (g_fn_sigs[i].return_type != ret) continue;
        if (g_fn_sigs[i].n_params    != n_params) continue;
        if (g_fn_sigs[i].is_variadic != is_variadic) continue;
        if (g_fn_sigs[i].ret_unsigned != ret_unsigned) continue;   /* A-1 */
        int ok = 1;
        for (int j = 0; j < n_params; j++) {
            if (g_fn_sigs[i].param_types[j] != params[j]) { ok = 0; break; }
        }
        if (ok) return i;
    }
    if (g_n_fn_sigs >= MAX_FN_SIGS)
        die(g_cur.line, g_cur.col, "too many fn-pointer signatures (max 128)");
    FnSig *s = &g_fn_sigs[g_n_fn_sigs];
    s->return_type = ret;
    s->n_params    = n_params;
    s->is_variadic = is_variadic;
    s->ret_unsigned = ret_unsigned;
    for (int j = 0; j < n_params; j++) {
        s->param_types[j] = params[j];
        s->param_struct_ids[j] = param_struct_ids ? param_struct_ids[j] : -1;
    }
    return g_n_fn_sigs++;
}

/* --libso: the member a declaration belongs to is the stem of the file its
 * token was scanned from ("lib/libc_c/strtok.c" -> "strtok"). */
static const char *
member_stem(const char *path)
{
    const char *b, *dot;
    int n;
    if (!path) return NULL;
    b = strrchr(path, '/');
    b = b ? b + 1 : path;
    dot = strrchr(b, '.');
    n = dot ? (int)(dot - b) : (int)strlen(b);
    return lex_intern_ident(b, n);
}

Global *
globals_declare(const char *name, int name_len, LocalType type,
                int n_elems, int line, int col, int is_extern_decl)
{
    if (name_len >= MAX_IDENT)
        die(line, col, "identifier too long");
    /* G45: C tentative-definition / extern reconciliation.  A global may be
     * declared more than once in a TU: the standard header pattern is
     * `extern T x;` in a shared header (stevie.h's `extern int Rows;`,
     * `extern struct param params[];`) followed by the defining `T x [=
     * init];` in one .c (main.c, param.c, charset.c).  Reuse the slot and
     * RE-INITIALIZE it from THIS decl — the defining decl carries the real
     * size/initializer and overrides the extern placeholder.  is_extern is
     * set HERE (centralized; callers no longer scribble it) so the reverse
     * order also reconciles: an `extern` re-declaration AFTER the definition
     * (a header re-included later in a merged pile TU — libcurses' curses.ext
     * after curses.c) is a NO-OP, never demoting the defined slot back to
     * extern or wiping its initializer (that dropped LINES/COLS/_tty_ch from
     * the libcurses data seg, 2026-07-16).
     * Require a matching base type to catch genuine conflicts. */
    Global *g = globals_lookup(name, name_len);
    const char *member = (g_libso && !is_extern_decl) ? member_stem(g_cur.file)
                                                     : NULL;
    if (g != NULL && member && g->member && !g->is_extern &&
        strcmp(g->member, member) != 0) {
        char msg[200];
        snprintf(msg, sizeof msg,
                 "static '%.*s' is defined in members '%s' and '%s'; "
                 "libc.so needs one owner", name_len, name, g->member, member);
        die(line, col, msg);
    }
    if (g != NULL) {
        if (g->type != type)
            die(line, col, "conflicting types for global");
        if (is_extern_decl && !g->is_extern)
            return g;     /* extern re-decl after definition: keep storage */
    } else {
        FCC_GROW(g_globals, g_n_globals, g_globals_cap, Global);
        g = &g_globals[g_n_globals++];
        g->name = lex_intern_ident(name, name_len);
    }
    g->type      = type;
    g->struct_id = -1;       /* M8: caller patches for struct decls */
    g->fn_sig_id = -1;       /* M18: caller patches for fn-ptr decls */
    g->n_dims    = 1;        /* M19: caller patches for multi-dim */
    g->dims[0]   = n_elems;
    {
        int _es = is_ptr_array(type) ? 4 :            /* M21/B-5: ptr-array stride */
                  (type == LT_CHAR || type == LT_CHAR_ARRAY ||
                   type == LT_CHAR_PTR || type == LT_VOID_PTR) ? 1 :
                  (type == LT_LONG || type == LT_LONG_ARRAY ||
                   type == LT_LONG_PTR ||
                   type == LT_FLOAT || type == LT_FLOAT_ARRAY ||
                   type == LT_FLOAT_PTR) ? 4 :          /* B-6: float is 4-byte */
                  BT_IS_QUAD(BTYPE(type)) ? 8 :
                  /* pointer-to-pointer (e.g. LINE**) element = 4-byte long ptr;
                   * the old `: 2` default halved its subscript stride and (with
                   * the G52 double-scale) broke vi's LinePointers[]. */
                  (ISPTR(type) && ptr_stride(type)) ? ptr_stride(type) : 2;
        g->row_stride = _es;
    }
    g->n_elems   = n_elems;
    if (is_ptr_array(type)) {        /* M21/B-5: T*[N] — 4 bytes/element */
        g->n_bytes = 4 * n_elems;
    } else if (ISPTR(type)) {
        /* ANY pointer (struct*, int*, char*, void*, fn*, ptr-to-ptr, …) is a
         * 24-bit long pointer = 4 bytes (3B payload + 1B pad).  The explicit
         * LT_*_PTR cases below covered scalar pointers but MISSED LT_STRUCT_PTR,
         * which fell to `default: 2`.  A 2-byte reservation means the bank byte
         * (gname+2) overflows into the next global, corrupting every heap
         * pointer's bank — silently, because fcc's pointer `==` is offset-only.
         * First exposed by vi's heap LINE linked list (Filemem->linep->next). */
        g->n_bytes = 4 * n_elems;
    } else switch (type) {
        case LT_CHAR:
        case LT_CHAR_ARRAY:    g->n_bytes = n_elems;     break;
        case LT_INT:
        case LT_INT_ARRAY:     g->n_bytes = 2 * n_elems; break;
        case LT_INT_PTR:
        case LT_CHAR_PTR:
        case LT_VOID_PTR:
        case LT_FN_PTR:
        case LT_LONG_PTR:      g->n_bytes = 4 * n_elems; break;  /* long ptr: 3B payload + 1B pad */
        case LT_LONG:
        case LT_LONG_ARRAY:    g->n_bytes = 4 * n_elems; break;
        case LT_FLOAT:
        case LT_FLOAT_ARRAY:   g->n_bytes = 4 * n_elems; break;  /* B-6 */
        case LT_LLONG:
        case LT_LLONG_ARRAY:
        case LT_DOUBLE:
        case LT_DOUBLE_ARRAY:  g->n_bytes = 8 * n_elems; break;
        default:               g->n_bytes = 2;            break;
    }
    g->is_initialised  = 0;
    g->init_value      = 0;
    g->init_value_hi   = 0;
    g->init_value_q    = 0;
    g->init_values_q   = NULL;
    g->init_str_label  = -1;
    g->init_func_idx   = -1;
    g->init_global_idx = -1;
    g->init_global_off = 0;
    g->is_reloc_target = 0;
    g->is_static       = 0;
    g->is_extern       = is_extern_decl;   /* centralized (see G45 above) */
    g->member          = member;
    g->is_local_static = 0;
    g->n_init_values   = 0;
    g->init_slots_per_elem = 0;   /* FCC_GROW memory is not zeroed */
    return g;
}


int
funcs_declare(const char *name, int name_len, int n_params,
              int line, int col)
{
    if (name_len >= MAX_IDENT)
        die(line, col, "function name too long (max 31 chars)");
    /* RTL-ABI: a prototype→definition promotion removes the prototype slot
     * below, discarding its fields.  Carry the EXPLICIT-varargs flag forward so
     * a `void msg();` header decl still marks the msg() definition variadic. */
    int carry_variadic_expl = 0;
    int carry_ret_unsigned  = 0;
    g_fn_redecl_defined = 0;
    g_fn_kept_proto = 0;
    int empty_parens_decl = g_declare_empty_parens;
    g_declare_empty_parens = 0;                       /* consume-once */
    for (int i = 0; i < g_n_funcs; i++) {
        if (g_funcs[i].name == lex_intern_ident(name, name_len)) {   /* T2-1 */
            /* Re-declaration: allowed iff the existing entry is just a
             * prototype (is_extern), in which case the new decl is the
             * definition. Caller will reset is_extern after parsing
             * the body.  Otherwise, true duplicate → die. */
            if (g_funcs[i].is_extern) {
                /* K&R-compat (M-4): a bare `f()` REdeclaration of a real
                 * PROTOTYPE keeps the prototype — C semantics: a non-
                 * prototype declarator does not remove parameter info.
                 * Without this, `extern void *malloc();` (elvis config.h)
                 * after stdlib.h's wide prototype downgraded malloc to
                 * push-args-as-is 16-bit ints.  Route through the
                 * redecl_defined skip so the caller doesn't scribble
                 * return/variadic state either; a '{' after such a decl
                 * dies as a redefinition there (param-shape conflict —
                 * loud beats silent). */
                /* The RETURN type is NOT parameter info, and must not ride
                 * along with that skip -- g_fn_kept_proto tells the caller to
                 * apply it.  This declarator was the only source of the struct
                 * id for a `struct S *f();' whose entry came from the --sigs
                 * sidecar, which cannot carry a TU-local struct id.  With the
                 * id lost, `f(x)->m = v' fell out of the strict field lookup
                 * into the K&R global-member pun, whose '->' arm DEREFERENCES
                 * the base -- and here the base is already the pointer.
                 * apple/fgx#153: every `export VAR' in sh stored its flag
                 * through a pointer read out of the node's first two members. */
                if (empty_parens_decl && !g_funcs[i].is_variadic_expl
                    && g_funcs[i].n_params > 0) {
                    g_fn_redecl_defined = 1;
                    g_fn_kept_proto     = 1;
                    return i;
                }
                /* Prototype now being DEFINED — promote IN PLACE (Increment 4).
                 * The historical remove-and-reappend existed only to keep the
                 * "current function = last slot" invariant; with g_cur_fn_idx
                 * that invariant is gone, every handed-out function index stays
                 * valid forever, and the fn-ptr-initializer remap machinery
                 * (funcs_remap_promote + the Global.init_* patch loops) is
                 * deleted with it. */
                carry_variadic_expl = g_funcs[i].is_variadic_expl;
                carry_ret_unsigned  = g_funcs[i].ret_unsigned;   /* A-1 */
                g_funcs[i].name = lex_intern_ident(name, name_len);
                g_funcs[i].n_params = n_params;
                g_funcs[i].return_type = LT_INT;
                g_funcs[i].ret_unsigned = carry_ret_unsigned;
                g_funcs[i].return_struct_id = -1;
                for (int pi = 0; pi < MAX_LOCALS; pi++) {
                    g_funcs[i].param_types[pi] = LT_INT;
                    g_funcs[i].param_struct_ids[pi] = -1;
                }
                g_funcs[i].is_variadic = 0;
                g_funcs[i].is_variadic_expl = carry_variadic_expl;
                g_funcs[i].is_extern   = 0;
                g_funcs[i].is_static   = 0;
                g_funcs[i].is_from_sigs = 0;
                g_funcs[i].n_fixed     = -1;
                g_funcs[i].fn_sig_id   = -1;
                return i;
            }
            /* Already DEFINED.  A prototype re-declaration after the
             * definition is legal C (a header re-included later in the
             * TU — the libcurses merged-pile shape); a second BODY is a
             * redefinition.  We can't see which until the caller reaches
             * ';' vs '{', so flag it, return the entry UNTOUCHED, and let
             * parse_func_decl_with_spec skip mutation / die at '{'. */
            g_fn_redecl_defined = 1;
            return i;
        }
    }
    FCC_GROW(g_funcs, g_n_funcs, g_funcs_cap, Func);
    g_funcs[g_n_funcs].name = lex_intern_ident(name, name_len);
    g_funcs[g_n_funcs].n_params = n_params;
    g_funcs[g_n_funcs].return_type = LT_INT;
    g_funcs[g_n_funcs].ret_unsigned = carry_ret_unsigned;   /* A-1 */
    g_funcs[g_n_funcs].return_struct_id = -1;
    for (int i = 0; i < MAX_LOCALS; i++) {
        g_funcs[g_n_funcs].param_types[i] = LT_INT;
        g_funcs[g_n_funcs].param_struct_ids[i] = -1;
    }
    g_funcs[g_n_funcs].is_variadic = 0;
    g_funcs[g_n_funcs].is_variadic_expl = carry_variadic_expl;   /* RTL-ABI */
    g_funcs[g_n_funcs].is_extern   = 0;
    g_funcs[g_n_funcs].is_static   = 0;
    g_funcs[g_n_funcs].is_from_sigs = 0;
    g_funcs[g_n_funcs].n_fixed     = -1;
    g_funcs[g_n_funcs].fn_sig_id   = -1;   /* M18: patched after param parse */
    return g_n_funcs++;
}

int
funcs_lookup(const char *name, int name_len)
{
    const char *cn = lex_intern_ident(name, name_len);   /* T2-1 canonical */
    for (int i = 0; i < g_n_funcs; i++) {
        if (g_funcs[i].name == cn)                       /* T2-1: pointer scan */
            return i;
    }
    return -1;
}

/* Strict + union-arm member lookup within ONE struct (cn already interned). */
static Field *
field_lookup_strict(int sid, const char *cn)
{
    if (sid < 0) return NULL;
    Struct *s = &g_structs[sid];
    for (int i = 0; i < s->n_fields; i++) {
        if (s->fields[i].name == cn)                     /* T2-1: pointer scan */
            return &s->fields[i];
    }
    /* K&R / anonymous-union fallback: a named union arm's fields are
     * reachable directly through a union pointer (`u->field`, the way
     * 2.11BSD sed accesses `union reptr` as `rep->command`/`rep->re1`).
     * When the field isn't a direct member of a UNION, search the union's
     * struct-typed members (arms).  Each union member sits at offset 0
     * (B-2), so the arm field's byte_offset is already union-relative. */
    if (s->is_union) {
        for (int i = 0; i < s->n_fields; i++) {
            if (BTYPE(s->fields[i].type) == BT_STRUCT &&
                !ISPTR(s->fields[i].type) && !ISARY(s->fields[i].type) &&
                s->fields[i].struct_id >= 0) {
                Field *inner = field_lookup_strict(s->fields[i].struct_id, cn);
                if (inner) return inner;
            }
        }
    }
    return NULL;
}

/* K&R GLOBAL member namespace -- a TOLERATED VIOLATION, not a sanctioned rule.
 *
 * CORRECTION (apple/fgx#85): this comment used to call the strict "member must
 * belong to the struct" requirement "an ANSI-ism", and the commit that added
 * the fallback said fcc enforcing it was "the non-K&R part".  A.7.3.3
 * (p.163-164) says the opposite, for BOTH operators:
 *
 *   '.'  "The first operand expression must be a structure or a union, and the
 *         identifier must name a member of the structure or union."
 *   '->' "The first operand expression must be a pointer to a structure or
 *         union, and the identifier must name a member of the structure or
 *         union."
 *   and: "In the FIRST EDITION of this book, IT WAS ALREADY THE RULE that a
 *         member name in such an expression had to belong to the structure or
 *         union mentioned in the postfix expression; however, a note admitted
 *         that this rule was not firmly enforced.  Recent compilers, and ANSI,
 *         do enforce it."
 *
 * So the pun was never blessed by K&R.  It is a rule the 1st edition stated and
 * did not police, which the PDP-11 compilers of the day let through and which
 * 2.11BSD's sh then built on.  What this function implements is a deliberate
 * NON-ENFORCEMENT kept for the vendored port -- so the question is never "is
 * this K&R", it is "which violations do we still tolerate, and why".
 *
 * The PDP-11 C compiler that built 2.11BSD kept every struct member name in
 * one namespace: `p->m` compiled to *(m's type *)((char*)p + m's offset) for
 * ANY p.  The Bourne /bin/sh relies on this pervasively -- parallel "variant
 * record" structs (trenod/forknod/comnod ... share a common prefix layout) are
 * accessed through one generic TREPTR; message/arg buffers are punned through
 * STRING (char*).  Member names are deliberately prefix-unique so the namespace
 * stays consistent (same name -> same offset), so first-match is well-defined.
 * out_container_sid (optional) receives the defining struct's id -- callers use
 * it to coerce a non-struct base pointer to the punned struct type. */
Field *
field_lookup_global(const char *name, int name_len, int *out_container_sid)
{
    const char *cn = lex_intern_ident(name, name_len);
    for (int si = 0; si < g_n_structs; si++) {
        Struct *s = &g_structs[si];
        for (int i = 0; i < s->n_fields; i++) {
            if (s->fields[i].name == cn) {
                if (out_container_sid) *out_container_sid = si;
                return &s->fields[i];
            }
        }
    }
    return NULL;
}

/* Strict-only lookup by name+len (no global pun fallback).  Callers that must
 * DISTINGUISH a member of the operand's own struct from a global-namespace pun
 * use this -- e.g. the lvalue walker decides deref (a '.' pun aliases the
 * operand's own storage, no deref) only when strict resolution fails. */
Field *
field_lookup_strict_named(int sid, const char *name, int name_len)
{
    if (sid < 0) return NULL;
    return field_lookup_strict(sid, lex_intern_ident(name, name_len));
}

/* Member lookup for a '.' access -- STRICT, no K&R global pun (apple/fgx#85).
 *
 * WHERE THE LINE IS, AND WHY IT IS NOT THE OPERATOR TOKEN.  A.7.3.3 imposes the
 * same "must name a member" requirement on '.' and on '->', and says outright
 * that "E1->MOS is the same as (*E1).MOS" -- so K&R offers no ground for
 * treating the two operators differently, and this is not a conformance split.
 * It is a policy about which tolerated violations (see field_lookup_global) we
 * keep, and the measurement decides it: across the kernel, libc, every userland
 * port and tcsh, plus the 2.11BSD Bourne sh port in tools/sh-fgx2, there are
 * 110 pun resolutions and every one is `t->member` on a trenod*.
 *
 * What the port actually needs is tolerance where the operand is a POINTER --
 * the variant-record idiom, one generic TREPTR over storage that is really a
 * forknod/comnod/lstnod.  Read through A.7.3.3's own equivalence, that is the
 * `(*E1).MOS` shape whichever token spells it, which is why the walker in
 * parse_stmt.c keeps punning a '.' applied to a pointer (sh's `Lcheat`) while
 * this function refuses one applied to a struct VALUE.  TOLERANCE FOLLOWS THE
 * POINTER, NOT THE TOKEN.
 *
 * On a struct value the operand's exact type is right there in the expression,
 * so a name that misses it is a typo -- and the pun answered typos with a
 * silent store at another member's offset.  `T.md.pre = 5`, where struct mid
 * has no `pre` but its member `ld` is a struct leaf that does, wrote the low
 * half of the POINTER T.md.lp.  tests/reject/ holds the cases.
 *
 * If a port ever does need a '.' pun on a struct value, the honest fix is to
 * spell the cast -- `((struct leaf *)&T.md)->pre` -- not to widen this back. */
Field *
field_lookup_dot(int sid, const char *name, int name_len)
{
    return field_lookup_strict_named(sid, name, name_len);
}

Field *
struct_field_lookup(int sid, const char *name, int name_len)
{
    const char *cn = lex_intern_ident(name, name_len);   /* T2-1 canonical */
    Field *f = field_lookup_strict(sid, cn);
    if (f) return f;
    /* K&R global fallback -- only reached when strict resolution fails (which
     * previously errored "no such field"), so ANSI/strict struct access is
     * byte-identical.  This resolves the 2.11BSD parallel-struct pun
     * `t->forktyp` (t a trenod*, forktyp a forknod field at the same offset). */
    return field_lookup_global(name, name_len, NULL);
}

/* Flatten a struct's fields into the LEAF slots a brace initializer supplies
 * one value each for (K&R A.8.7: the initializer for a structure is a
 * brace-enclosed list for its members, and a member that is itself an
 * aggregate takes a nested list -- which may be elided).
 *
 * A struct-VALUE member contributes its own leaves recursively; an ARRAY
 * member contributes one leaf per element.  Everything else is one leaf, so
 * for a struct whose members are ALL scalars the leaf list is byte-for-byte
 * the field list and nothing downstream changes -- that equality is what keeps
 * every existing golden identical.
 *
 * Each leaf is a COPY of its Field with byte_offset rewritten ABSOLUTE within
 * the element and n_elems forced to 1, so the emitter's offset-driven walk
 * (pad to byte_offset, advance pos by the emitted size) needs no new cases.
 *
 * CHAR arrays ARE expanded, since UFS 2.1 (apple/fgx#283).  They were not,
 * on the reasoning that `char name[8]' is initialized from a STRING rather
 * than from 8 scalars and that expanding it would silently mis-fill -- but
 * leaving it as one leaf did not make the string spelling work either, it made
 * BOTH spellings fail closed, and K&R A.8.7 allows each: "An aggregate is a
 * structure or array.  If an aggregate contains members of aggregate type, the
 * initialization rules apply recursively", and separately "As a special case,
 * a character array may be initialized by a string literal."  The caller now
 * handles the string form explicitly against the expanded leaves, which is
 * what makes the expansion safe rather than mis-filling.
 *
 * owners[i] (optional) gets the index of the TOP-LEVEL field leaf i came from,
 * so a caller can find the extent of one nested brace group.
 * Returns the leaf count, or -1 if it would exceed `max`. */
int
struct_init_leaves(int sid, Field *out, int *owners, int max)
{
    return struct_init_leaves_at(sid, 0, out, owners, max, 0, -1);
}

int
struct_init_leaves_at(int sid, int base_off, Field *out, int *owners, int max,
                      int n, int owner)
{
    Struct *s;
    int     f;

    if (sid < 0 || n < 0) return -1;
    s = &g_structs[sid];
    for (f = 0; f < s->n_fields; f++) {
        Field fl  = s->fields[f];
        int   off = base_off + fl.byte_offset;
        int   top = (owner >= 0) ? owner : f;

        /* embedded struct VALUE -> its own leaves */
        if (fl.type == LT_STRUCT && fl.struct_id >= 0 && fl.n_elems <= 1) {
            n = struct_init_leaves_at(fl.struct_id, off, out, owners, max,
                                      n, top);
            if (n < 0) return -1;
            continue;
        }
        /* ARRAY member -> one leaf per element (recursing for a struct
         * element type).  byte_size/n_elems is the element stride. */
        if (ISARY(fl.type) && fl.n_elems > 1) {
            LocalType ety  = DECREF(fl.type);
            int       esz  = (fl.n_elems > 0) ? (fl.byte_size / fl.n_elems) : 0;
            int       e;
            if (esz <= 0) return -1;
            for (e = 0; e < fl.n_elems; e++) {
                if (ety == LT_STRUCT && fl.struct_id >= 0) {
                    n = struct_init_leaves_at(fl.struct_id, off + e * esz, out,
                                              owners, max, n, top);
                    if (n < 0) return -1;
                    continue;
                }
                if (n >= max) return -1;
                out[n] = fl;
                out[n].type        = ety;
                out[n].n_elems     = 1;
                out[n].byte_offset = off + e * esz;
                out[n].byte_size   = esz;
                if (owners) owners[n] = top;
                n++;
            }
            continue;
        }
        if (n >= max) return -1;
        out[n] = fl;
        out[n].byte_offset = off;
        if (owners) owners[n] = top;
        n++;
    }
    return n;
}

int
strlit_intern(const char *bytes, int n)
{
    for (int i = 0; i < g_n_str_lits; i++) {
        if (!g_str_lits[i].no_pool &&
            g_str_lits[i].len == n + 1 &&
            memcmp(&g_str_pool[g_str_lits[i].offset], bytes, (size_t)n) == 0) {
            return i;
        }
    }
    FCC_GROW(g_str_lits, g_n_str_lits, g_str_lits_cap, struct str_lit_s);
    /* g_str_pool is a byte pool; grow until it holds the incoming n+1 bytes. */
    while (g_str_pool_used + n + 1 > g_str_pool_cap) {
        int _oc = g_str_pool_cap;
        g_str_pool_cap = g_str_pool_cap ? g_str_pool_cap * 2 : 4096;
        g_str_pool = (char *)realloc(g_str_pool, (size_t)g_str_pool_cap);
        if (!g_str_pool) { fprintf(stderr, "fcc: out of memory growing g_str_pool\n"); exit(1); }
        memset(g_str_pool + _oc, 0, (size_t)(g_str_pool_cap - _oc));
    }
    g_str_lits[g_n_str_lits].offset  = g_str_pool_used;
    g_str_lits[g_n_str_lits].len     = n + 1;
    g_str_lits[g_n_str_lits].no_pool = 0;
    memcpy(&g_str_pool[g_str_pool_used], bytes, (size_t)n);
    g_str_pool[g_str_pool_used + n] = '\0';
    g_str_pool_used += n + 1;
    return g_n_str_lits++;
}

int
strlit_intern_blob(const char *bytes, int n)
{
    /* A `char x[] = "literal"` too long for init_values[] (frotz
     * dumb_input's 2.1KB runtime-help text).  Same pool storage as
     * strlit_intern but NO dedup and flagged no_pool: the bytes are
     * emitted into the ARRAY'S OWN storage by emit_globals_section, so
     * no _S label exists for a char* use of the same text to share --
     * which is also why the dedup scan above must never match one. */
    FCC_GROW(g_str_lits, g_n_str_lits, g_str_lits_cap, struct str_lit_s);
    while (g_str_pool_used + n + 1 > g_str_pool_cap) {
        int _oc = g_str_pool_cap;
        g_str_pool_cap = g_str_pool_cap ? g_str_pool_cap * 2 : 4096;
        g_str_pool = (char *)realloc(g_str_pool, (size_t)g_str_pool_cap);
        if (!g_str_pool) { fprintf(stderr, "fcc: out of memory growing g_str_pool\n"); exit(1); }
        memset(g_str_pool + _oc, 0, (size_t)(g_str_pool_cap - _oc));
    }
    g_str_lits[g_n_str_lits].offset  = g_str_pool_used;
    g_str_lits[g_n_str_lits].len     = n + 1;
    g_str_lits[g_n_str_lits].no_pool = 1;
    memcpy(&g_str_pool[g_str_pool_used], bytes, (size_t)n);
    g_str_pool[g_str_pool_used + n] = '\0';
    g_str_pool_used += n + 1;
    return g_n_str_lits++;
}

/* ---- K&R cross-TU signature sidecar (--emit-sigs / --sigs) ---------------
 *
 * Why this exists: K&R C has no prototypes, so when fcc compiles a TU that
 * CALLS a function DEFINED IN ANOTHER TU it knows nothing about the parameter
 * types and must push each argument at its own width.  On a PDP-11 that is
 * harmless because sizeof(int) == sizeof(char *) == 2.  On FGX a far pointer
 * is 4 bytes, so a bare `0` passed for a pointer parameter goes out 2 bytes
 * wide, the callee reads 4, and every argument after it is shifted.
 *
 * fcc already does the right thing when it KNOWS the parameter types --
 * walk_call_args materialises an int-valued argument for a pointer parameter
 * as a 4-byte NULL.  All that is missing is the knowledge.  So: one pass
 * writes each TU's defined signatures out, the real pass reads them all back
 * in as prototypes.
 *
 * Format is one line per function, whitespace separated:
 *     NAME ret variadic n_params ptype0 ptype1 ...
 * Types are the raw LocalType words -- both passes are the same fcc build, so
 * no stable external encoding is needed.
 *
 * Functions taking a struct BY VALUE are skipped: their param_struct_ids index
 * this TU's struct table, which does not carry across TUs.  Skipping is safe
 * (that call then falls back to today's behaviour) and, unlike guessing, cannot
 * corrupt a frame.
 */
void
sigs_emit(const char *path)
{
    FILE *f = fopen(path, "a");     /* append: one file accumulates the TUs */
    if (!f) { perror(path); return; }
    for (int i = 0; i < g_n_funcs; i++) {
        Func *fn = &g_funcs[i];
        if (fn->is_extern) continue;            /* prototype only, not a body */
        if (fn->is_variadic) continue;          /* arg widths are not fixed */
        /* STATIC functions must not be exported.  Func.name is the bare source
         * name (mangling happens in fname() at emit time), so two TUs with
         * same-named statics of different shapes would both land here, load
         * would keep one, and a THIRD TU calling an unrelated GLOBAL of that
         * name would inherit the static's parameter widths -- silently shifted
         * frames.  That is the very bug this sidecar exists to prevent, so
         * emitting statics would reintroduce it through the tool built to kill
         * it. */
        if (fn->is_static) continue;
        /* is_variadic_expl is NOT a reason to skip, and skipping on it used to
         * gut this sidecar.  A K&R DEFINITION with named params inherits the
         * flag from its own header's `extern T f();` (funcs_declare carries it
         * across the promote-in-place), so in a codebase that declares every
         * function through an `__P(a) -> ()` macro -- tcsh's 46 TUs, and any
         * pre-ANSI tree -- essentially EVERY function carried it and the pass
         * harvested 5 signatures out of ~600.  That is how tcsh's
         * `Calloc(s, n) size_t s, n;` came to be called with 2-byte int
         * arguments: the callee read 4-byte size_t params, `n` picked up stack
         * junk, and `n *= s` reached malloc as $FFFFD270 -> "Out of memory."
         *
         * The old rationale -- "a fixed-arity left-to-right call into an RTL
         * callee lands the parameters REVERSED" -- no longer holds: the B2
         * universal flip (parse_stmt.c) made the CALLEE layout param0-shallowest
         * and the caller push right-to-left for EVERY function, so
         * is_variadic_expl drives no ordering any more (nothing outside symtab
         * reads it).  Genuine varargs are still excluded by the is_variadic test
         * above, which `...` and a truly-empty `f() {}` definition both set.
         *
         * The emitted vexpl column is therefore always 0: what we export is a
         * fixed-arity definition, and a loaded vexpl=1 would fail the
         * empty-paren keep-guard in funcs_declare and clobber the very
         * parameter types this sidecar exists to carry. */
        int has_struct = 0;
        for (int p = 0; p < fn->n_params; p++)
            if (fn->param_types[p] == LT_STRUCT) has_struct = 1;
        if (has_struct) continue;               /* struct ids are TU-local */
        /* ret_unsigned rides along: without it a loaded entry SUPPRESSES the
         * TU's own `extern unsigned f();` (the empty-paren decl hits the
         * keep-branch, the in-body prototype path is skipped by the
         * funcs_lookup guard), so unsigned compares/div on the result would
         * silently go signed -- a regression versus having no sidecar. */
        fprintf(f, "%s %d %d %d %d", fn->name, (int)fn->return_type,
                0 /* vexpl: see above */, fn->ret_unsigned, fn->n_params);
        for (int p = 0; p < fn->n_params; p++)
            fprintf(f, " %d", (int)fn->param_types[p]);
        /* A lint VARARGSn definition's fixed count rides at the end, so a
         * caller in another TU leaves the trailing arguments unnarrowed too. */
        if (fn->n_fixed >= 0)
            fprintf(f, " v%d", fn->n_fixed);
        fprintf(f, "\n");
    }
    fclose(f);
}

/* ---- this TU's own definitions (--emit-defs) ------------------------------
 *
 * The sidecar stands in for the declaration of a function DEFINED IN ANOTHER
 * TU.  A name this TU defines itself is not such a function: the linker binds
 * every call here to the definition here (fgx_ld's strong-over-LIBC rule), so
 * another TU's parameter types must not shape those calls.  They did whenever
 * the call came BEFORE the definition -- su(1) calls its own
 * setenv(ename, eval, buf) above the body, libc's setenv(name, value, rewrite)
 * was in the sidecar, and the third argument went out as a 2-byte int that
 * su's setenv then read as a 4-byte pointer.
 *
 * K&R A.7.3.2: "If the postfix expression consists of an identifier for which
 * no declaration exists in the current scope, the identifier is implicitly
 * declared as if the declaration extern int identifier(); had been given",
 * and "If the function declaration in scope for a call is old-style, then
 * default argument promotion is applied to each argument".  That is how such
 * a call is compiled once its name is kept out of the sidecar.
 *
 * Only a CONFLICTING entry is dropped.  In a multi-TU build the sidecar is
 * the tool's own (bsh's sh.sigs), and its entry for a function this TU calls
 * before defining is this TU's own signature -- the one that widens
 * `execute(t, 0, 0, pv)'s NULLs -- so it must stay.  Dropping every name the
 * TU defines broke bsh.
 *
 * Which names a TU defines is only known after parsing it, and a call can
 * precede its definition, so main() runs fcc over the TU once first with
 * --emit-defs.  That pass writes every function with a body to <path> (static
 * and variadic included) and, through sigs_emit, the signatures the sidecar
 * format can carry to <path>.sigs.  sigs_load keeps a sidecar entry for a name
 * this TU defines only when <path>.sigs has the same entry; otherwise the call
 * gets the implicit declaration. */
static char (*own_defs)[MAX_IDENT];
static int   n_own_defs;
static char (*own_sig_name)[MAX_IDENT];
static char (*own_sig_body)[256];       /* the fields after the name */
static int   n_own_sigs;

void
defs_emit(const char *path)
{
    FILE *f = fopen(path, "w");
    if (!f) { perror(path); return; }
    for (int i = 0; i < g_n_funcs; i++)
        if (!g_funcs[i].is_extern)
            fprintf(f, "%s\n", g_funcs[i].name);
    fclose(f);

    char sp[1024];
    snprintf(sp, sizeof sp, "%s.sigs", path);
    remove(sp);                     /* sigs_emit appends */
    sigs_emit(sp);
}

/* One sidecar line split into its name and the rest, as sigs_emit wrote it. */
static int
sig_line(FILE *f, char *name, char *body, size_t bodysz)
{
    char line[512], *sp;

    if (!fgets(line, sizeof line, f))
        return 0;
    line[strcspn(line, "\n")] = '\0';
    if (!(sp = strchr(line, ' ')))
        return -1;
    *sp = '\0';
    snprintf(name, MAX_IDENT, "%s", line);
    snprintf(body, bodysz, "%s", sp + 1);
    return 1;
}

void
defs_load(const char *path)
{
    FILE *f = fopen(path, "r");
    char name[MAX_IDENT];
    if (!f) return;                 /* no list: the sidecar applies as before */
    while (fscanf(f, "%63s", name) == 1) {
        own_defs = realloc(own_defs, (size_t)(n_own_defs + 1) * sizeof *own_defs);
        if (!own_defs) { fprintf(stderr, "out of memory\n"); exit(1); }
        strcpy(own_defs[n_own_defs++], name);
    }
    fclose(f);

    char sp[1024], body[256];
    int r;
    snprintf(sp, sizeof sp, "%s.sigs", path);
    if (!(f = fopen(sp, "r")))
        return;
    while ((r = sig_line(f, name, body, sizeof body)) != 0) {
        if (r < 0) continue;
        own_sig_name = realloc(own_sig_name, (size_t)(n_own_sigs + 1) * sizeof *own_sig_name);
        own_sig_body = realloc(own_sig_body, (size_t)(n_own_sigs + 1) * sizeof *own_sig_body);
        if (!own_sig_name || !own_sig_body) { fprintf(stderr, "out of memory\n"); exit(1); }
        strcpy(own_sig_name[n_own_sigs], name);
        strcpy(own_sig_body[n_own_sigs++], body);
    }
    fclose(f);
}

/* Does the sidecar's entry for `name' (its fields rebuilt as sigs_emit writes
 * them) conflict with this TU's own definition of it? */
static int
own_conflict(const char *name, int ret, int vexpl, int runs, int np,
             const LocalType *pts, int nfixed)
{
    char body[256];
    int n, i;

    for (i = 0; i < n_own_defs; i++)
        if (strcmp(own_defs[i], name) == 0)
            break;
    if (i == n_own_defs)
        return 0;                       /* not defined here */
    n = snprintf(body, sizeof body, "%d %d %d %d", ret, vexpl, runs, np);
    for (int p = 0; p < np && n < (int)sizeof body; p++)
        n += snprintf(body + n, sizeof body - (size_t)n, " %d", (int)pts[p]);
    if (nfixed >= 0 && n < (int)sizeof body)
        snprintf(body + n, sizeof body - (size_t)n, " v%d", nfixed);
    for (i = 0; i < n_own_sigs; i++)
        if (strcmp(own_sig_name[i], name) == 0)
            return strcmp(own_sig_body[i], body) != 0;
    return 1;                           /* defined here in a shape the sidecar
                                         * cannot carry: never the same */
}

void
sigs_load(const char *path)
{
    FILE *f = fopen(path, "r");
    if (!f) { perror(path); return; }
    char name[MAX_IDENT];
    int ret, vexpl, runs, np;
    while (fscanf(f, "%31s %d %d %d %d", name, &ret, &vexpl, &runs, &np) == 5) {
        if (np < 0 || np > MAX_LOCALS) break;   /* malformed - stop, don't guess */
        LocalType pts[MAX_LOCALS];
        int ok = 1;
        for (int p = 0; p < np; p++) {
            int t;
            if (fscanf(f, "%d", &t) != 1) { ok = 0; break; }
            pts[p] = (LocalType)t;
        }
        if (!ok) break;
        int nfixed = -1;                /* the optional ` vN' (sigs_emit) */
        {
            char rest[64];
            if (fgets(rest, sizeof rest, f) && sscanf(rest, " v%d", &nfixed) != 1)
                nfixed = -1;
        }
        int len = (int)strlen(name);
        /* First line wins WITHIN the sidecar.  (It cannot dedup against this
         * TU's own declarations -- sigs_load runs before parsing.  Own-decl-wins
         * is delivered later by funcs_declare itself: a definition promotes in
         * place, a typed prototype overwrites, and an empty-paren `extern void
         * f();` correctly KEEPS the richer loaded signature.)  The build must
         * regenerate the sidecar each sweep; a stale line would otherwise win
         * over a changed signature. */
        if (funcs_lookup(name, len) >= 0)
            continue;
        if (own_conflict(name, ret, vexpl, runs, np, pts, nfixed))
            continue;                   /* this TU defines it otherwise */
        int fi = funcs_declare(name, len, np, 0, 0);
        g_funcs[fi].return_type      = (LocalType)ret;
        g_funcs[fi].ret_unsigned     = runs;
        g_funcs[fi].is_variadic      = 0;
        g_funcs[fi].is_variadic_expl = vexpl;
        g_funcs[fi].is_extern        = 1;       /* a definition here promotes it */
        g_funcs[fi].is_from_sigs     = 1;       /* ...and is not a redefinition */
        g_funcs[fi].n_params         = np;
        g_funcs[fi].n_fixed          = nfixed;
        for (int p = 0; p < np; p++) {
            g_funcs[fi].param_types[p]      = pts[p];
            g_funcs[fi].param_struct_ids[p] = -1;
        }
    }
    fclose(f);
}

/*----------------------------------------------------------------------------
 * stack_census_emit - per-function stack accounting for the bank-0 stack study
 * (2026-08-02).  Writes ONE line per compiled function to the file named by
 * $FCC_STACK_CENSUS, appending; silent no-op when the variable is unset.
 *
 * Deliberately an ENVIRONMENT variable rather than a CLI flag, for two reasons.
 * It has to reach fcc through a dozen hand-written build scripts (tcsh, bsh,
 * elvis, tar, ...) that pass their own carefully-tuned flag sets, and none of
 * them should have to be edited for a measurement.  And it emits NOTHING into
 * the .s output, so all 546 fixture goldens stay byte-identical -- a census
 * that forced a golden regen would cost more than it measures.
 *
 * The question it answers: if every addr_taken/raw_accessed local moved out of
 * the bank-0 hardware stack into the task's data bank, how much of each frame
 * would be left?  `exiled` is that movable weight; `resident` is what would
 * remain in bank 0 per activation.  `pin` flags the frames a spiller could
 * never relocate -- explicit varargs (stdarg.h's va_list is a plain char* that
 * walks the caller's pushed arg tail, so those params cannot move) and any
 * function that takes the address of a PARAM.
 *----------------------------------------------------------------------------*/
/*----------------------------------------------------------------------------
 * soft_scc_load / soft_scc_member - the recursion-SCC member list (bank-0 stack
 * campaign 1.3).
 *
 * Which functions form a recursion cycle is a LINK-TIME fact -- it needs the
 * whole call graph -- but the exile decision is made per function at COMPILE
 * time.  The list is therefore a generated, COMMITTED file that the linker
 * produces and fcc consumes, never a file the build writes and reads in the
 * same pass: consuming a link-time fact at compile time is the
 * build-writes-its-own-inputs trap, hit three times in one day on 2026-07-28.
 * The generator must be idempotent and `ninja -n` must say there is no work to
 * do after it runs twice.
 *
 * Delivered by environment variable for the same reason the census is: it has
 * to reach fcc through a dozen hand-written build scripts (tcsh, bsh, elvis,
 * tar) that pass their own carefully-tuned flag sets, and none of them should
 * need editing.  Absent or empty -> nothing is soft and codegen is unchanged.
 *--------------------------------------------------------------------------*/
int
soft_scc_load(const char *path)
{
    FILE *f;
    char line[MAX_IDENT];
    int n;

    if (path == NULL || *path == '\0')
        return 0;
    if ((f = fopen(path, "r")) == NULL)
        return 0;
    while (g_n_soft_scc < MAX_SOFT_SCC && fgets(line, sizeof line, f)) {
        n = (int)strlen(line);
        while (n > 0 && (line[n - 1] == '\n' || line[n - 1] == '\r'))
            line[--n] = '\0';
        if (n == 0 || line[0] == '#')
            continue;
        g_soft_scc[g_n_soft_scc] = strdup(line);
        if (g_soft_scc[g_n_soft_scc] == NULL)
            break;
        g_n_soft_scc++;
    }
    fclose(f);
    return g_n_soft_scc;
}

int
soft_scc_member(const char *name)
{
    int i;

    for (i = 0; i < g_n_soft_scc; i++)
        if (strcmp(g_soft_scc[i], name) == 0)
            return 1;
    return 0;
}


void
stack_census_emit(int frame_bytes, int is_variadic)
{
    const char *path = getenv("FCC_STACK_CENSUS");
    FILE *f;
    int i, exiled = 0, n_exiled = 0, n_locals = 0, param_addr = 0;

    if (path == NULL || *path == '\0')
        return;
    for (i = 0; i < g_n_locals; i++) {
        Local *lc = &g_locals[i];
        if (lc->kind == LK_PARAM) {
            if (lc->addr_taken)
                param_addr++;
            continue;
        }
        if (lc->kind != LK_LOCAL)
            continue;
        n_locals++;
        if (lc->addr_taken || lc->raw_accessed) {
            exiled += lc->byte_size;
            n_exiled++;
        }
    }
    if ((f = fopen(path, "a")) == NULL)
        return;
    fprintf(f, "%s %s frame=%d exiled=%d resident=%d locals=%d/%d "
               "param_addr=%d variadic=%d pin=%d",
            g_input_path ? g_input_path : "?", g_func_name,
            frame_bytes, exiled, frame_bytes - exiled, n_exiled, n_locals,
            param_addr, is_variadic,
            (is_variadic || param_addr) ? 1 : 0);
    /* Byte RANGES of the exiled locals within the frame.  Increment 1.2 turns
     * every access to one of these into `LDY #off / <op> [_fcc_sfp],Y` -- 5
     * bytes where `<op> n,S` is 2 -- and the 64 KB per-code-bank cliff is 1.2's
     * gate criterion.  Emitting the ranges lets the delta be COUNTED from the
     * already-built assembly (each n,S access carries a `; fccstk b=` slot
     * annotation) instead of estimated, which means the go/no-go answer comes
     * before the codegen is written rather than after.
     *
     * The 2026-07-05 soft stack died of exactly this: `LDY/LDA [_fcc_ssp],Y`
     * pushed jsh past FGX1's 64 KB single-bank cap, and it was found by
     * building, not by predicting. */
    fprintf(f, " exrange=");
    for (i = 0; i < g_n_locals; i++) {
        Local *lc = &g_locals[i];
        if (lc->kind != LK_LOCAL || !(lc->addr_taken || lc->raw_accessed))
            continue;
        fprintf(f, "%d:%d,", 2 * lc->slot_first,
                2 * lc->slot_first + lc->byte_size);
    }
    /* The AGGREGATE subset of the exiled set -- arrays and structs.  These are
     * what make a frame FAT (tcsh's ChangeSize is 2,068 bytes of which 10 would
     * remain), so they carry nearly all of the capacity win; but they are
     * reached through a pointer built once from &buf, not through a per-element
     * `n,S`, so they should carry almost none of the +3-bytes-per-access code
     * cost that blocks 1.2.  Emitting them separately is what turns that
     * "should" into a number. */
    fprintf(f, " agrange=");
    for (i = 0; i < g_n_locals; i++) {
        Local *lc = &g_locals[i];
        if (lc->kind != LK_LOCAL || !(lc->addr_taken || lc->raw_accessed))
            continue;
        if (!ISARY(lc->type) && lc->struct_id < 0)
            continue;
        fprintf(f, "%d:%d,", 2 * lc->slot_first,
                2 * lc->slot_first + lc->byte_size);
    }
    fprintf(f, "\n");
    fclose(f);
}

/* --core-list: statics that stay in libc's per-process core rather than a
 * member block (shared libc SP2 spec, section 4) -- one unmangled name per
 * line, `#' comments. */
#define MAX_CORE_NAMES 64
static const char *g_core_names[MAX_CORE_NAMES];
static int g_n_core_names;

void
core_list_load(const char *path)
{
    char line[128];
    FILE *f = fopen(path, "r");
    if (!f) { perror(path); exit(1); }
    while (fgets(line, sizeof line, f)) {
        int n = (int)strcspn(line, " \t\r\n#");
        if (n == 0) continue;
        if (g_n_core_names == MAX_CORE_NAMES)
            die(0, 0, "--core-list: more than 64 names");
        g_core_names[g_n_core_names++] = lex_intern_ident(line, n);
    }
    fclose(f);
}

/* A block static: in library mode, a file-scope or function-local static a
 * libc member defines and the core list does not name.  Each process holds
 * it in its member's block, reached through _<lib>_blk_<member>.
 * FCC_LIBSO_NOBLOCKS=1 turns blocks off (the byte-identity check's
 * baseline). */
int
is_block_static(Global *g)
{
    static int noblocks = -1;
    if (noblocks < 0) noblocks = getenv("FCC_LIBSO_NOBLOCKS") != NULL;
    if (!g_libso || noblocks || g->is_extern || !g->member) return 0;
    if (!(g->is_static || g->is_local_static)) return 0;
    for (int i = 0; i < g_n_core_names; i++)
        if (strcmp(g_core_names[i], g->name) == 0) return 0;
    return 1;
}

/* A block static's offset in its member's block: the sizes of the member's
 * block statics declared before it.  Stable once g is declared -- later
 * declarations only append -- so code can use it before the data is
 * emitted; the template asserts it (emit_block_templates). */
int
block_offset(Global *g)
{
    int off = 0;
    for (int i = 0; i < g_n_globals && &g_globals[i] != g; i++)
        if (g_globals[i].member == g->member && is_block_static(&g_globals[i]))
            off += g_globals[i].n_bytes;
    return off;
}

/* The members that own block statics, in first-seen order. */
int
block_members(const char **out, int max)
{
    int n = 0;
    for (int i = 0; i < g_n_globals; i++) {
        const char *m = g_globals[i].member;
        int j;
        if (!is_block_static(&g_globals[i])) continue;
        for (j = 0; j < n; j++)
            if (out[j] == m) break;
        if (j == n) {
            if (n == max) die(0, 0, "--libso: too many members with blocks");
            out[n++] = m;
        }
    }
    return n;
}

/* --emit-blocks: each member's block -- its statics in declaration order,
 * each with its offset, size and whether it has initial bytes -- as JSON:
 * the member-block layout fgx_ld lays libc.so's per-process data out from
 * (shared libc SP2).  Offsets follow n_bytes, as the template emission
 * does (emit_globals_section). */
void
blocks_emit(const char *path)
{
    FILE *f = fopen(path, "w");
    const char *mem[256];
    int n_mem = block_members(mem, 256);
    if (!f) { perror(path); return; }
    fprintf(f, "{\"members\": {");
    for (int j = 0; j < n_mem; j++) {
        int off = 0, first = 1;
        fprintf(f, "%s\n  \"%s\": {\"statics\": [", j ? "," : "", mem[j]);
        for (int i = 0; i < g_n_globals; i++) {
            Global *g = &g_globals[i];
            if (g->member != mem[j] || !is_block_static(g)) continue;
            fprintf(f, "%s\n    {\"name\": \"%s\", \"offset\": %d, \"bytes\": %d, "
                       "\"init\": %s}", first ? "" : ",", gname(g), off,
                    g->n_bytes, g->is_initialised ? "true" : "false");
            off += g->n_bytes;
            first = 0;
        }
        fprintf(f, "\n  ], \"size\": %d}", off);
    }
    fprintf(f, "\n}}\n");
    fclose(f);
}
