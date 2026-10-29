#include "fcc.h"

int g_lint_varargs = -1;
int g_decl_lint_varargs = -1;
const char *g_input_path = NULL;

/* Shared helpers relocated from main.c so the lexer/parser unit tests
 * (test-lex, test-peephole) link without pulling in main(). */
/* The file a diagnostic at `line' belongs to: the current token's, when the
 * diagnostic is about it (an #include'd file's line numbers are its own),
 * else the translation unit's. */
static const char *
diag_file(int line)
{
    return (g_cur.file && g_cur.line == line) ? g_cur.file : g_input_path;
}

__attribute__((noreturn)) void
die(int line, int col, const char *msg)
{
    fprintf(stderr, "%s:%d:%d: error: %s\n",
            diag_file(line), line, col, msg);
    exit(1);
}

/* T5-C: implicit function declarations default to int return, so a
 * far-pointer return silently loses its bank (the caller rebuilds the
 * pointer from A with bank 0).  Fail-loud, once per name per TU. */
void
warn_implicit_decl(const char *name, int name_len, int line, int col)
{
    static char warned[64][32];
    static int  n_warned = 0;
    if (name_len > 31) name_len = 31;
    for (int i = 0; i < n_warned; i++)
        if (strncmp(warned[i], name, name_len) == 0 &&
            warned[i][name_len] == '\0')
            return;
    if (n_warned < 64) {
        memcpy(warned[n_warned], name, name_len);
        warned[n_warned][name_len] = '\0';
        n_warned++;
    }
    fprintf(stderr, "%s:%d:%d: warning: implicit declaration of '%.*s' "
            "(int return assumed; a far-pointer return loses its bank)\n",
            diag_file(line), line, col, name_len, name);
}

int
is_ident_start(int c)
{
    return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '_';
}

int
is_ident_cont(int c)
{
    return is_ident_start(c) || (c >= '0' && c <= '9');
}

char        g_sys_inc_dir[256] = "";   /* derived from argv[0] in main */

const char *g_extra_inc_dirs[8];

int         g_n_extra_inc_dirs = 0;

FILE *g_out = NULL;

const char *g_data_seg_path = NULL;

/* K&R A.10.2 tentative-definition coalescing (multi-TU link): --commons routes
 * this TU's tentative-def globals (uninit, file-scope, no `extern`) to a sidecar
 * record file instead of a per-TU `<name> DS` label; the toolchain gen_commons
 * pass merges them across all TUs into ONE definition (or drops them where a
 * real initialized definition exists).  NULL (default) = the single-TU path,
 * byte-identical to before. */
const char *g_commons_path = NULL;
FILE       *g_commons_out  = NULL;
const char *g_emit_sigs_path = NULL;   /* --emit-sigs (K&R cross-TU sigs) */
const char *g_sigs_path      = NULL;   /* --sigs */
const char *g_emit_defs_path = NULL;   /* --emit-defs (this TU's own names) */

/* T5-C C3: --pile — compiling a TU destined for the shared-libc segment.
 * Every call stays NEAR (a FARCALL would emit a reloc row; the pile must
 * take zero loader patches to stay byte-identical across binaries). */
int g_pile = 0;
/* --sections: FGX_SECT/FGX_ENDS around each function and data item, for
 * fgx_gc (toolchain/src/ld/fgx_gc.py) to keep or drop as units. */
int g_sections = 0;
/* --signed-char: a char not declared unsigned holds -128..127.  fcc's
 * default keeps every char 0..255; the 68000 compilers a port comes from
 * (and K&R's PDP-11) sign-extend, and code that writes `signed char' or
 * tests a char for < 0 depends on it. */
int g_signed_char = 0;
/* This translation unit passes a floating value where no parameter is
 * declared for it, as a printf call does: main.c then marks its output with
 * `]__lc_fltused'.  In a static link (fgx_static) the marker keeps libc's
 * float printer (fltpr.c); without it the link takes ffltpr's `?' printer.
 * libc.so always has the real printer, so a dynamic link ignores it.
 * 2.11BSD's cc does the same with a reference to `fltused'
 * (libc/pdp/stdio/fltpr.s), for any floating point at all. */
int g_fltused = 0;
int g_kernel_bank = 0;
int g_module_bank = 0;
int g_emit_safepoints = 1;      /* P2': on by default; -fno-safepoints disables */
int g_pile_far_extern = 0;
int g_libso = 0;
int g_libso_inplace = 0;
const char *g_libso_name = "libc";
const char *g_emit_blocks_path = NULL;

FILE       *g_data_out      = NULL;

/* SP4 far-call ABI: emit cross-bank-ready code (JSL/RTL user calls, strings
 * in the data bank).  Off by default -> single-bank FGX1 output unchanged.
 * Requires g_data_seg_path (--data-segment). */

/* Set while parsing an expression whose value is DISCARDED (a for-init/step
 * clause), so a void-returning function call is allowed there — elvis's
 * ChangeText = for((beforedo(FALSE)),bavar=1; ...; (afterdo()),bavar=0).
 * Value-consuming contexts (assignment RHS, arithmetic) keep it 0 so
 * `x = voidfn()` still errors. */
int g_void_ctx_ok = 0;
int g_addr_of_chain = 0;
int g_preincdec_chain = 0;

char g_tu_prefix[32] = "_tu";

const char *g_src = NULL;     /* whole file in memory */

size_t      g_src_len = 0;

size_t      g_pos = 0;        /* byte offset into g_src */

int         g_line = 1;

/* Increment 4: the function currently being compiled — explicit identity,
 * replacing the historical "current function = last g_funcs slot" invariant
 * (which forced prototype-promotion renumbering and the G42 swap). */
int         g_cur_fn_idx = -1;
int         g_declare_empty_parens = 0;
int         g_fn_redecl_defined = 0;
int         g_fn_kept_proto = 0;

int         g_col = 1;

Tok         g_cur;            /* one-token lookahead */

/* Dynamic parse-time tables (grow on demand, like g_toks) — no fixed program-
 * size ceiling.  Start NULL/0; FCC_GROW reallocs (doubling) and zero-fills new
 * entries to preserve the old static arrays' zero-init semantics. */
PpMacro *g_pp_macros = NULL;
int      g_pp_macros_cap = 0;

int     g_pp_n_macros = 0;

PpCond g_pp_cond[PP_MAX_COND_DEPTH] = {{1, 1, 0, 1}};

int    g_pp_cond_top = 0;

char g_str_tok_buf[MAX_STR_TOK_LEN];

struct str_lit_s *g_str_lits = NULL;
int  g_str_lits_cap = 0;

int  g_n_str_lits   = 0;

char *g_str_pool = NULL;
int   g_str_pool_cap = 0;

int  g_str_pool_used = 0;

Global *g_globals = NULL;
int     g_globals_cap = 0;

int    g_n_globals = 0;

Struct g_structs[MAX_STRUCTS];

int    g_n_structs = 0;
/* K&R A.11.1: a tag declared inside a function is scoped to its block.  Depth
 * 0 is file scope; a function body and every nested block push one. */
int    g_tag_scope_depth = 0;

Typedef *g_typedefs = NULL;   /* dynamic (FCC_GROW); no fixed ceiling */
int      g_typedefs_cap = 0;

int     g_n_typedefs = 0;

FnSig g_fn_sigs[MAX_FN_SIGS];

int   g_n_fn_sigs = 0;

EnumConst g_enum_consts[MAX_ENUM_CONSTS];

int       g_n_enum_consts = 0;

Local g_locals[MAX_LOCALS];

int   g_n_locals = 0;     /* total entries in g_locals[] (params + locals) */

int   g_n_params = 0;     /* count of LK_PARAM entries */

int   g_n_local_decls = 0;/* count of LK_LOCAL entries (drives prologue size) */

int   g_total_slots = 0;  /* sum of slot_count across LK_LOCAL decls */
/* Bank-0 stack campaign 1.3: the recursion-SCC member list, and whether the
 * function being compiled is on it.  A cycle member puts ALL its locals in the
 * task's DATA bank -- all-or-nothing per function, which is why one slot space
 * still suffices: FRAMESIZE goes to 0 and SOFTSIZE takes its value. */
char *g_soft_scc[MAX_SOFT_SCC];
int   g_n_soft_scc = 0;
int   g_fn_is_soft = 0;
int   g_max_framesize = 0;  /* max function frame (bytes) across the TU; sizes the FGX1 stack hint */
int   g_n_datamac    = 0;   /* P3-5 I3: FGX2_* macro rows in the data stream (MODE + funnel) */

char  g_func_name[MAX_IDENT];   /* current function (set at decl) */

StaticAlias g_static_aliases[MAX_STATIC_ALIASES];

int         g_n_static_aliases = 0;

Local *g_main_argc_local = NULL;

Local *g_main_argv_local = NULL;

UserLabel g_user_labels[MAX_USER_LABELS];

int       g_n_user_labels = 0;

LocalType g_expr_type = LT_INT;
int g_stmt_line, g_stmt_col;

int g_expr_unsigned  = 0;

/* apple/fgx#12: is the int rvalue the last walk produced a compile-time
 * constant?  1 = constant (NULL, `(char*)-1`, `(char*)0xC000`) and the bank word
 * stays 0; 0 = a RUNTIME integer, which under FGX's model addresses the task
 * DATA bank (DBR) -- K&R A.6.6 leaves the int->pointer mapping to the
 * implementation and this is ours.
 *
 * Set by walk_expr() for EVERY walk (parse_expr.c), so it always describes the
 * expression just walked and can never go stale.  Its predecessor
 * g_rhs_const_int was published at only two store arms and never reset, which
 * meant a store path that did not publish inherited a previous arm's answer;
 * that is why the second #12 attempt could not be made coherent. */
int g_expr_const_int = 1;

int g_binop_unsigned = 0;

int g_expr_struct_id = -1;
int g_expr_fn_sig    = -1;

int g_param_byte_offsets[MAX_LOCALS];

int   g_s_delta = 0;
int   g_loop_depth = 0;   /* fcc2 P1.3-inc2: >0 while parsing a loop (for/while/do) */

int   g_last_stmt_returned = 0;

Func *g_funcs      = NULL;   /* dynamic (FCC_GROW) */
int   g_funcs_cap  = 0;

int  g_n_funcs = 0;

LoopCtx g_loop_ctx[MAX_LOOP_CTX];

int     g_loop_ctx_top = 0;

SwitchCase g_sw_cases[MAX_CASES_PER_SWITCH];

int        g_n_sw_cases       = 0;

int        g_sw_default_label = -1;

int        g_sw_end_label     = -1;

SwitchSave g_sw_stack[MAX_SWITCH_NESTING];

int        g_sw_top = 0;

int g_paren_lvalue_skip_label = 0;

int g_pp_eval_depth = 0;

int g_label_n = 0;

char g_gname_buf[64];

char g_fname_buf[64];

int g_anon_struct_n = 0;
