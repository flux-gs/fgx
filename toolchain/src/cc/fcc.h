#ifndef FCC_H
#define FCC_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "tword.h"
#include "ir.h"      /* ir_emitf (drop-in for fprintf(g_out,...)) + record/replay */

/* FCC_GROW — grow a dynamic parse-time table on demand instead of failing at a
 * fixed cap (why real compilers don't hit "too many X": their symbol tables
 * grow).  Reallocs (doubling) when (n) reaches (cap) and ZERO-FILLS the new
 * slots so callers keep the zero-init semantics the old static arrays had.
 * (arr) is a T*, (cap)/(n) are ints.  Indices stay valid across growth; only
 * element POINTERS held across an append would move — fcc never holds those
 * (it stores indices, e.g. init_values = tg - g_globals). */
#define FCC_GROW(arr, n, cap, T)                                            \
    do {                                                                    \
        if ((n) >= (cap)) {                                                 \
            int _oc = (cap);                                                \
            int _nc = (cap) ? (cap) * 2 : 256;                             \
            void *_p = realloc((arr), (size_t)_nc * sizeof(T));            \
            if (!_p) { fprintf(stderr, "fcc: out of memory growing "        \
                               #arr "\n"); exit(1); }                       \
            (arr) = (T *)_p; (cap) = _nc;                                   \
            memset((arr) + _oc, 0, (size_t)(_nc - _oc) * sizeof(T));        \
        }                                                                   \
    } while (0)

typedef enum {
    TOK_EOF = 0,
    TOK_INT_KW,        /* int    */
    TOK_RETURN_KW,     /* return */
    TOK_IDENT,         /* main, ... */
    TOK_INT_LIT,       /* 0..65535 */
    TOK_LPAREN,        /* ( */
    TOK_RPAREN,        /* ) */
    TOK_LBRACE,        /* { */
    TOK_RBRACE,        /* } */
    TOK_SEMI,          /* ; */
    TOK_PLUS,          /* + */
    TOK_MINUS,         /* - */
    TOK_STAR,          /* * */
    TOK_SLASH,         /* / */
    TOK_PERCENT,       /* % */
    TOK_EQ,            /* = */
    TOK_COMMA,         /* , */
    TOK_LT,            /* <  */
    TOK_GT,            /* >  */
    TOK_LE,            /* <= */
    TOK_GE,            /* >= */
    TOK_EQEQ,          /* == */
    TOK_NE,            /* != */
    TOK_IF_KW,         /* if    */
    TOK_ELSE_KW,       /* else  */
    TOK_WHILE_KW,      /* while */
    TOK_DO_KW,         /* do    */
    TOK_AMP,           /* &     */
    TOK_LBRACKET,      /* [     */
    TOK_RBRACKET,      /* ]     */
    TOK_CHAR_KW,       /* char  */
    TOK_VOID_KW,       /* void  */
    TOK_CHAR_LIT,      /* 'c'   */
    TOK_PLUSPLUS,      /* ++    */
    TOK_MINUSMINUS,    /* --    */
    TOK_STR_LIT,       /* "..." */
    TOK_SIZEOF_KW,     /* sizeof */
    TOK_STATIC_KW,     /* static (parsed, discarded) */
    TOK_STRUCT_KW,     /* struct  */
    TOK_UNION_KW,      /* union   */
    TOK_ENUM_KW,       /* enum    */
    TOK_TYPEDEF_KW,    /* typedef */
    TOK_DOT,           /* .       */
    TOK_ARROW,         /* ->      */
    TOK_COLON,         /* :       */
    TOK_SWITCH_KW,     /* switch  */
    TOK_CASE_KW,       /* case    */
    TOK_DEFAULT_KW,    /* default */
    TOK_BREAK_KW,      /* break   */
    TOK_CONTINUE_KW,   /* continue*/
    TOK_FOR_KW,        /* for     */
    TOK_GOTO_KW,       /* goto    */
    TOK_LONG_KW,       /* long    (M20) */
    TOK_FLOAT_KW,      /* float / double  (B-6; both -> BT_FLOAT) */
    TOK_FLOAT_LIT,     /* 3.14, 1e3, .5, 2.0f (B-6; value/value_hi = IEEE single
                        * bits; without an F suffix, is_dbl and the 64-bit
                        * value in dval) */
    TOK_QMARK,         /* ?       */
    TOK_PIPE,          /* |       */
    TOK_CARET,         /* ^       */
    TOK_TILDE,         /* ~       */
    TOK_LSHIFT,        /* <<      */
    TOK_RSHIFT,        /* >>      */
    TOK_AMPAMP,        /* &&      */
    TOK_PIPEPIPE,      /* ||      */
    TOK_BANG,          /* !       */
    TOK_PLUSEQ,        /* +=      */
    TOK_MINUSEQ,       /* -=      */
    TOK_STAREQ,        /* *=      */
    TOK_SLASHEQ,       /* /=      */
    TOK_PERCENTEQ,     /* %=      */
    TOK_AMPEQ,         /* &=      */
    TOK_PIPEEQ,        /* |=      */
    TOK_CARETEQ,       /* ^=      */
    TOK_LSHIFTEQ,      /* <<=     */
    TOK_RSHIFTEQ,      /* >>=     */
    TOK_ELLIPSIS,      /* ...     */
    TOK_SKIP           /* Increment 1: dead vector slot — next_tok/peek_tok
                        * skip it transparently.  Written by the G21/G41
                        * paren-lvalue re-dispatch to splice out a ')'. */
} TokKind;
typedef struct {
    TokKind kind;
    int     line;      /* 1-based */
    int     col;       /* 1-based */
    const char *file;  /* the source file this token was scanned from
                        * (interned; the umbrella's own path for its lines) */
    /* For INT_LIT / CHAR_LIT: numeric value (low 16 bits). */
    unsigned value;
    /* M20: high word for long literals.  is_long=1 iff literal had
     * L suffix or value > 65535. */
    unsigned value_hi;
    int      is_long;
    /* long long literals (the C99 extension): words 2 and 3, and whether the
     * literal is one -- an LL suffix, or a value no K&R rung can hold. */
    unsigned value2, value3;
    int      is_llong;
    /* A floating constant of type double or long double -- no F suffix (K&R
     * A.2.5.3) -- and its value as the host's IEEE double. */
    int      is_dbl;
    double   dval;
    /* A-1: literal had a U/u suffix (H2: `65528UL`-style constants). */
    int      is_unsigned;
    /* For IDENT: pointer into the source buffer (no NUL); len bytes. */
    const char *id_ptr;
    int         id_len;
    /* For STR_LIT: pointer + length into g_str_tok_buf. */
    const char *str_ptr;
    int         str_len;
    /* A lint VARARGSn comment directly before this token: n, else -1.  The
     * whole file is tokenized before parsing, so the marker rides on the
     * token that follows it rather than in a flag the lexer has long since
     * moved past. */
    int         lint_varargs;
} Tok;
#define PP_MAX_INCLUDE_DEPTH 16   /* #include recursion bound (stage c) */
/* Parser lookahead checkpoint (Increment 1).  The whole TU is tokenized up
 * front into g_toks[] (lex_tokenize_all), so a rewind is just a cursor
 * restore — it can no longer corrupt a macro/include frame, and token text is
 * interned so a saved id_ptr/str_ptr stays valid across any lookahead. */
typedef struct {
    int idx;    /* g_tok_idx */
    Tok cur;    /* g_cur */
} LexPeek;
void lex_peek_save(LexPeek *p);
void lex_peek_restore(const LexPeek *p);
/* Whole-TU token vector: g_cur == the last consumed token; g_tok_idx == index
 * of the NEXT token to consume (so peek_tok() == g_toks[g_tok_idx]). */
extern Tok *g_toks;
extern int  g_n_toks;
extern int  g_tok_idx;
extern int  g_cur_fn_idx;   /* function being compiled (Increment 4) */
extern int  g_declare_empty_parens; /* set by the declarator parser before
                                     * funcs_declare when THIS decl is a bare
                                     * `f()` (unspecified params).  An empty-
                                     * paren REdecl of a real prototype keeps
                                     * the prototype (C semantics) instead of
                                     * downgrading it to push-args-as-is —
                                     * the elvis config.h `extern void
                                     * *malloc();` -vs- wide stdlib.h case
                                     * (M-4 2026-07-17).  Consumed (reset)
                                     * by funcs_declare. */
extern int  g_fn_redecl_defined;  /* funcs_declare hit an already-DEFINED fn:
                                   * legal iff this declarator is a prototype
                                   * (redecl-after-definition, e.g. a header
                                   * re-included after the definition in a
                                   * merged pile TU); a second BODY dies. */
extern int  g_fn_kept_proto;      /* the redecl above was the empty-paren
                                   * KEEP branch: a bare `T f();' over a richer
                                   * entry.  Parameter info is kept, but the
                                   * RETURN type in this declarator is still
                                   * this TU's, and must be applied. */
void lex_tokenize_all(void);
/* Do g_toks[a, b) form exactly ONE postfix-expression (K&R A.7.3): an
 * identifier or a parenthesized group, then a run of .f / ->f / [..] / (..). */
int  lex_is_postfix_run(int a, int b);
/* The #define-line CAPTURE buffer size (raw body text, continuations already
 * spliced).  Was 256, which SILENTLY TRUNCATED a longer body mid-token and
 * left a garbled macro that died later as "expected type" at the cut -- joe's
 * screen.h `outatr' (a ~260-char rendering macro) is the case that found it.
 * The capture loop now dies loudly on overflow rather than truncating, so this
 * is a real ceiling, not a silent one; sized well past any real macro. */
#define PP_MAX_MACRO_BODY 2048
#define PP_MAX_FN_PARAMS  8
typedef struct {
    /* T2-1 rider: name and params are dedup-INTERNED pointers (the last
     * name arrays in the compiler) — lookups and param matches are
     * pointer compares. */
    const char *name;
    /* T2-2: the body is a TOKEN SLICE, tokenized once at #define time
     * (raw: no expansion, no directives).  Expansion is a token splice —
     * there is no body text and no rescan.  PP_MAX_MACRO_BODY bounds the
     * define-line CAPTURE buffer only (capture semantics unchanged). */
    Tok  *body_toks;
    int   n_body_toks;
    int   live;     /* 0 if #undef'd */
    /* Function-like macro support: when is_funclike, `name(a1, a2, ...)`
     * at the call site expands with arg substitution; bare `name` (no
     * paren) does not expand.  n_params is the count of NAMED params;
     * params[i] is the formal name.  is_variadic = 1 if the param list
     * ends in `...`; in that case n_args at call site must be >= n_params,
     * and any extras get joined comma-separated into __VA_ARGS__ in the
     * body substitution. */
    int   is_funclike;
    int   n_params;
    const char *params[PP_MAX_FN_PARAMS];
    int   is_variadic;
} PpMacro;
#define PP_MAX_COND_DEPTH 16
typedef struct {
    int active;          /* 1 = tokens flow; 0 = skip */
    int parent_active;
    int saw_else;
    int taken;           /* E-1: any arm of this if/elif chain taken yet */
} PpCond;
#define MAX_STR_TOK_LEN 4096       /* C89 floor 509 chars in a string literal */
struct str_lit_s {
    int offset;     /* into g_str_pool */
    int len;        /* including NUL */
    int no_pool;    /* char[]-init blob: bytes stream into the array's own
                       storage; skip pool emission AND the dedup scan */
};
#define MAX_LOCALS    512   /* C89 floor 127 block-scope identifiers */
#define MAX_DIMS      12     /* C89 floor 12 declarators modifying a type */
/* C89 2.2.4.1 floor is 31 significant characters; sized past it.
 * This constant also budgets the MANGLED symbol names emitted for static
 * locals (`<function>_sl_<name>`), so the worst case is roughly twice this
 * plus the decoration -- comfortably inside the assembler's 128-character
 * symbol ceiling.  An earlier revision left this at 32 on the stated grounds
 * that Merlin32 limited label length; that was wrong.  Measured: Merlin32 has
 * no length limit at all, and labels differing only at character 65 resolve
 * distinctly.  The only real ceiling was fas's, since unified and made loud. */
#define MAX_IDENT     64
/* The printf family is ordinary variadic C in libc; its args ride the
 * right-to-left hardware-stack ABI like every explicit-varargs call. */
typedef enum { LK_LOCAL, LK_PARAM, LK_GLOBAL } LocalKind;
typedef tword LocalType;
typedef struct {
    const char *name;      /* T2-1: canonical interned pointer (lex_intern_ident)
                            * — same spelling == same pointer, so lookups are
                            * pointer scans.  NUL-terminated, arena lifetime. */
    LocalKind  kind;
    LocalType  type;
    int        slot_first; /* first slot index (0-based) */
    int        slot_count; /* 1 for scalars/ptrs, N for arrays (or ceil(N/2) for char arrays) */
    int        struct_id;  /* -1 unless type is LT_STRUCT* (M8) */
    int        fn_sig_id;  /* -1 unless type is LT_FN_PTR (M18) */
    int        byte_size;  /* total bytes; = slot_count*2 for non-struct (M8) */
    int        array_bytes;  /* an array's elements' total bytes, sizeof's
                              * answer (K&R A.7.4.8); 0 for a non-array */
    int        n_dims;     /* M19: 1..MAX_DIMS; 1 for 1D / scalars / ptrs */
    int        dims[MAX_DIMS]; /* M19: per-axis sizes; dims[0] outermost */
    int        row_stride; /* M19: bytes per outermost-index step */
    int        is_unsigned;/* A-1: unsigned int/char/long */
    /* fcc2 P1.3-inc2 (local promotion): set when the local's address escapes
     * (emit_addr_of_local) or it is touched by a raw `n,S` stack access that
     * the structured IR can't track (emit_slot_lda16/sta16 during recording).
     * Either disqualifies the local from DP-IMG promotion. */
    int        addr_taken;
    int        raw_accessed;
    /* K&R A.11.1 block scope: set when the declaring `{...}` block ends, so
     * locals_lookup no longer finds this name (the outer same-name local
     * resumes).  The entry is KEPT (AST nodes hold Local* pointers and
     * g_total_slots is monotonic) -- only its lookup visibility is cleared. */
    int        scope_hidden;
    /* fcc2 P1.3-inc2: set when the var is accessed inside a loop (g_loop_depth>0).
     * Gates PARAM promotion — a param's entry-seed cost is only justified when
     * the param is loop-hot (locals have no seed, so they aren't gated). */
    int        loop_accessed;
    /* Use-before-set warning.  K&R 2nd ed 2.4, p.39: "External and static
     * variables are initialized to zero by default.  Automatic variables for
     * which is no explicit initializer have undefined (i.e., garbage) values."
     *
     * `n_stores' counts stores IN EMISSION ORDER as the body is walked, so a
     * read that finds it zero is a read with nothing written yet.  The verdict
     * waits for the end of the function (emit_warn_uninit_locals), where it is
     * known whether a store ever came at all.
     *
     * THE POSITION REPORTED IS THE DECLARATION'S, not the read's: emission
     * runs off the AST after the whole body is parsed, so `g_cur' is at the
     * closing brace by then and every warning would name the same line.  The
     * declaration is also where the fix goes. */
    int        n_stores;
    int        n_loads;
    int        use_before_set;  /* a read came before any store */
    int        ubs_in_loop;     /* ...and that read was inside a loop */
    int        decl_line;
    int        decl_col;
    /* A parameter copied at entry into a frame slot near S (params_home):
     * its index into g_param_byte_offsets, the slot the caller pushed.
     * -1 for everything else.  kind is LK_LOCAL once it is homed. */
    int        homed_from;
} Local;
#define MAX_SOFT_SLOTS  6144        /* per-frame slot cap (~12KB of 2-byte slots).  The 16KB
                                       soft-stack region it derived from is gone (P3-3 3.3); the
                                       real ceiling is now the bank-0 HW stack, sized per-binary
                                       + the STKGUARD prologue trap.  Recalibrating this value
                                       tracks with #42. */
/* No file-scope-variable cap either: g_globals is FCC_GROW'd.  Same story as
 * the typedef constant above -- the number here was decorative. */
#define MAX_INIT_VALUES 2048  /* per-global cap on brace-init list length.  Bumped
                               * for M21 struct-array init (fas's 246-entry OpRow
                               * × 3 fields = 738) and again for ntpplay's freq
                               * tables (freq_finetune = 1788 words). */
typedef struct {
    const char *name;      /* T2-1: canonical interned pointer (see Local) */
    LocalType  type;
    int        struct_id;        /* -1 unless type is LT_STRUCT* (M8) */
    int        fn_sig_id;        /* -1 unless type is LT_FN_PTR (M18) */
    int        n_bytes;
    int        n_elems;
    int        is_initialised;
    unsigned   init_value;
    unsigned   init_value_hi;    /* M20: high word for LT_LONG inits */
    unsigned   init_value_q;     /* bits 32-63 of an LT_LLONG init */
    int        init_str_label;   /* >=0 iff init is a string literal */
    int        init_func_idx;    /* B-7: >=0 iff fn-ptr global init = &g_funcs[idx] */
    int        init_global_idx;  /* >=0 iff scalar ptr init = address of g_globals[idx] (T *p = global / &global) */
    int        init_global_off;  /* byte displacement on that address: &g[k], &g.m, g+k (K&R A.7.19) */
    int        is_reloc_target;  /* 1 iff another global inits a pointer to this one (needs FGX2_EXPORT) */
    int        is_static;        /* multi-TU: file-scope static → name-mangled */
    int        is_extern;        /* multi-TU: extern decl only, no storage emit */
    int        is_local_static;  /* a function-local static (internal linkage,
                                  * hidden file-scope storage) */
    const char *member;          /* --libso: stem of the file that defines it
                                  * (the libc member); NULL otherwise */
    /* init-list: brace-initialised arrays.  n_init_values > 0 means the
     * global has an init list; values are 16-bit unsigned ints (for
     * LT_INT_ARRAY).  If shorter than n_elems, remainder zero-fills. */
    unsigned   init_values[MAX_INIT_VALUES];
    unsigned   init_values_hi[MAX_INIT_VALUES];  /* M20: high words for LT_LONG_ARRAY inits */
    unsigned  *init_values_q;    /* bits 32-63 of each long long init value;
                                  * NULL until one is stored (see init_q) */
    int        n_init_values;
    /* M22: init SLOTS per struct element (leaves, not fields -- see
     * struct_init_leaves).  Equals n_fields for an all-scalar struct; larger
     * when a member is an embedded struct or an array.  0 means "not a struct
     * init", and the emitter falls back to n_fields for anything written
     * before this existed. */
    int        init_slots_per_elem;
    int        n_dims;            /* M19 */
    int        dims[MAX_DIMS];    /* M19 */
    int        row_stride;        /* M19 */
    int        is_unsigned;       /* A-1: unsigned int/char/long */
} Global;
/* NB: a fixed cap, NOT FCC_GROW.  parse_struct_def holds `Struct *s =
 * &g_structs[sid]` across its field loop, which can recursively append nested
 * struct defs -- a realloc would dangle that pointer.  Converting to FCC_GROW
 * needs those holds re-fetched by index first; until then, size generously.
 * tcsh's sh.h chain declares >32 structs. */
/* A limit's value as a string literal, so a message naming it cannot drift
 * from the constant the check compares against. */
#define FCC_STR_(x) #x
#define FCC_STR(x)  FCC_STR_(x)

#define MAX_STRUCTS 512
/* C89 2.2.4.1 sets the translation limit at 127 members in one struct/union,
 * and K&R imposes no cap at all, so 32 was a conformance gap rather than a
 * design choice -- 4.3BSD-Reno's `struct vnodeops` has exactly 32 function
 * pointers and met it with nothing to spare.  Sized to the standard's floor.
 * Fixed cap for the same reason as MAX_STRUCTS above: parse_struct_def holds
 * a Field* across the loop that can append nested defs. */
#define MAX_FIELDS_PER_STRUCT 256
typedef struct {
    const char *name;      /* T2-1: canonical interned pointer (see Local) */
    LocalType  type;
    int        struct_id;     /* -1 unless type is LT_STRUCT* */
    int        fn_sig_id;     /* -1 unless type is LT_FN_PTR (M18) */
    int        n_elems;       /* 1 for scalars; TOTAL elements for arrays --
                              * the PRODUCT of the dimensions when >1 (K&R
                              * A.8.6.2: the declaration's first subscript
                              * "helps determine the amount of storage
                              * consumed") */
    int        n_dims;        /* M19b: 1..MAX_DIMS; 1 for 1D / scalars / ptrs */
    int        row_stride;    /* M19b: BYTES per outermost-index step, as
                              * Local.row_stride is; 0 when n_dims < 2 */
    int        byte_offset;   /* offset within the containing struct */
    int        byte_size;     /* size of this field in bytes */
    int        is_bit_field;
    int        bit_offset;    /* bit position within container word (0..15) */
    int        bit_width;     /* number of bits (1..16) */
    int        is_unsigned;   /* A-1: unsigned int/char/long field */
} Field;
typedef struct {
    const char *name;      /* T2-1: canonical interned pointer */
    Field fields[MAX_FIELDS_PER_STRUCT];
    int   n_fields;
    int   total_size;        /* bytes, padded to even */
    int   is_forward;        /* 1 if only forward-declared */
    int   is_union;          /* 1 if declared `union` (members overlap at 0) */
    int   scope_hidden;      /* 1 once its block closed -- see structs_lookup */
    int   scope_depth;       /* 0 = file scope; >0 = declared inside a block */
} Struct;
/* No typedef cap: g_typedefs is FCC_GROW'd.  A MAX_TYPEDEFS constant used to
 * sit here, unused by any code -- it read as a limit that did not exist and
 * cost a wrong diagnosis during the filesystem port.  Deleted rather than
 * raised. */
typedef struct {
    const char *name;      /* T2-1: canonical interned pointer */
    LocalType  base_type;
    int        struct_id;
    int        fn_sig_id;     /* -1 unless base_type is LT_FN_PTR (M18) */
    int        n_elems;
    int        is_unsigned;   /* apple/fgx#399.  base_type is a TWORD and a
                               * TWORD has no room for signedness, so without
                               * this `typedef unsigned int u_int' recorded
                               * LT_INT and nothing else -- every u_int,
                               * u_short and u_char in the tree compiled
                               * SIGNED.  It is silent until bit 15 is set and
                               * the value is widened or compared as something
                               * larger: `(off_t)msize < totsz' with msize
                               * 34185 took the signed widening helper, read
                               * -31351, and fsck(8) sent a filesystem that fit
                               * down the scratch-file path. */
} Typedef;
#define MAX_FN_SIGS 512   /* 64→128 (shared-libc pile), 128→512 (joe: b.c/ufile.c
                           * cross 128 distinct fn-ptr signatures in one TU) */
typedef struct {
    LocalType return_type;
    LocalType param_types[MAX_LOCALS];
    int       param_struct_ids[MAX_LOCALS];
    int       n_params;
    int       is_variadic;
    int       ret_unsigned;   /* A-1 closure: part of the dedup KEY, so
                               * signed/unsigned-returning ptr types don't
                               * alias; call-through results carry it. */
} FnSig;
typedef struct TypeSpec_s TypeSpec;
#define MAX_ENUM_CONSTS 512        /* C89 floor 127; sized well past it */
typedef struct {
    const char *name;      /* T2-1: canonical interned pointer */
    unsigned value;
} EnumConst;
#define MAX_STATIC_ALIASES 32
typedef struct { const char *name; /* T2-1 interned */ int global_idx; } StaticAlias;
#define MAX_USER_LABELS 256        /* no C89 floor; BSD sources use goto freely */
typedef struct {
    const char *name;   /* T2-1: canonical interned pointer */
    int  defined;       /* 1 once `name:` seen */
    int  referenced;    /* 1 once goto NAME; seen */
} UserLabel;
typedef struct {
    const char *name;      /* T2-1: canonical interned pointer (see Local) */
    int        n_params;
    LocalType  return_type;
    LocalType  param_types[MAX_LOCALS];
    int        param_struct_ids[MAX_LOCALS]; /* M8: -1 unless type is LT_STRUCT* */
    int        is_variadic;       /* M11: true if param list ends in '...' */
    int        is_variadic_expl;  /* RTL-ABI: EXPLICITLY declared varargs — an
                                    * empty-paren `f()` or `...` DECLARATION in
                                    * source (NOT the implicit-call fallback).
                                    * Preserved across prototype→definition
                                    * promotion.  Drives the right-to-left arg
                                    * ABI (callee param0→offset 0 + caller arg
                                    * reversal) so a K&R varargs callee (elvis
                                    * msg(fmt,...)) reads param0 from the fixed
                                    * shallow slot.  Implicit decls are NOT set
                                    * (a fixed-arity helper called before its
                                    * definition must not flip). */
    int        is_extern;         /* M11: true if no body (prototype-only) */
    int        is_from_sigs;      /* the entry came from --sigs and NOTHING in
                                    * this TU has declared the name.  A libc
                                    * signature is out-of-band knowledge, not a
                                    * declaration in the source, so a DEFINITION
                                    * here is this program's own function that
                                    * happens to share a name -- not a
                                    * redefinition.  Cleared the moment the TU
                                    * declares or defines it. */
    int        is_static;         /* multi-TU: file-scope static → name-mangled */
    int        n_fixed;           /* lint's VARARGSn on the definition: the
                                    * first n_fixed parameters are fixed and
                                    * the rest take whatever the call passes,
                                    * so a call does not NARROW an argument
                                    * into one of them (walk_call_args).  -1
                                    * when the definition carries no marker. */
    int        fn_sig_id;         /* M18: interned signature for fn-ptr rvalue */
    int        return_struct_id;  /* -1 unless return_type is LT_STRUCT*; lets
                                    * `f()->field` / `f()[i]` chain on the result */
    int        ret_unsigned;      /* A-1: `unsigned ...` return type — call
                                    * results carry it into g_expr_unsigned so
                                    * compares/div pick the unsigned helpers.
                                    * (FnSig deliberately does NOT carry it:
                                    * fn-POINTER call results stay a documented
                                    * signed-default residual.) */
} Func;
#define MAX_LOOP_CTX 32            /* C89 floor 15 nested iteration structures */
typedef struct {
    int break_label;
    int continue_label;   /* -1 if outermost ctx is a switch with no outer loop */
} LoopCtx;
#define MAX_CASES_PER_SWITCH 1024  /* C89 floor 257; sized well past it */
#define MAX_SWITCH_NESTING 32      /* C89 floor 15 nested selection structures */
typedef struct {
    unsigned value;
    unsigned value_hi;   /* high 16 of a LONG selector's case (else 0) */
    unsigned value2, value3;   /* words 2 and 3 of a LONG LONG selector's */
    int      label;
    int      line, col;
} SwitchCase;
typedef struct {
    SwitchCase cases[MAX_CASES_PER_SWITCH];
    int        n_cases;
    int        default_label;
    int        end_label;
} SwitchSave;
struct TypeSpec_s {
    LocalType base;       /* LT_INT / LT_CHAR / LT_VOID / LT_STRUCT / LT_FN_PTR */
    int       struct_id;  /* if base is LT_STRUCT; overloaded as fn_sig_id when base is LT_FN_PTR (M18) */
    int       is_static;  /* multi-TU: 'static' qualifier seen */
    int       is_extern;  /* multi-TU: 'extern' qualifier seen */
    int       is_unsigned;/* A-1: 'unsigned' qualifier seen (int/char/long) */
};

/* Declarator — the result of the ONE recursive declarator parser
 * (parse_declarator), conforming to the pcc K&R grammar
 * (examples/2.11BSD/usr/lib/mip/cgram.y; docs/history/plans/fcc-knr-grammar-reference.md).
 * A declarator applies a derivation chain (* pointer, [] array, () function,
 * ( ) grouping) to a base TypeSpec and yields the finished per-symbol type
 * bundle every context (cast, member, local, global, param, fn-def) needs.
 *
 * The declarator-refactor campaign (docs/history/plans/2026-07-22-fcc-
 * declarator-refactor.md) converts the contexts to this one parser
 * increment-by-increment, each byte-identical against the golden suite.
 * Increment 1 (casts) populates type/name/struct_id/is_unsigned for the
 * pointer+array cases; function/grouping (fn_sig_id in-band) land in the
 * later increments that exercise them (struct fn-ptr members, params). */
typedef struct {
    tword       type;        /* full derived tword: PTR/ARY over the base    */
    const char *name;        /* declared identifier; NULL for an abstract
                              * declarator (cast / sizeof / unnamed param)    */
    int         name_len;
    int         name_line;   /* source position of the NAME token (die() parity) */
    int         name_col;
    int         struct_id;   /* carried from the base spec when BTYPE==STRUCT */
    int         fn_sig_id;   /* interned FnSig when the declarator is/returns
                              * a function; -1 otherwise (later increments)   */
    int         n_dims;      /* array dimensionality (0 = not an array)       */
    int         dims[MAX_DIMS];
    int         row_stride;  /* multidim inner-dims product in ELEMENTS; callers
                              * scale by element size to bytes; 0 if <2 dims    */
    int         is_unsigned; /* threaded from the base spec                   */
    int         sizeless;    /* outer `[]` with no size: caller sizes from the
                              * initializer (locals prescan; globals defer)    */
    int         is_func_proto;/* a `(` follows the NAME (G27 function declaration):
                              * params NOT consumed -- the caller owns that path */
} Declarator;

/* Recursive declarator parser (parse_stmt.c).  Applies the leading `*`s and
 * trailing `[]`/`()`/grouping to `base`.  allow_abstract=1 permits a missing
 * name (casts, unnamed params).  See the campaign charter for the per-context
 * conversion order. */
Declarator parse_declarator(TypeSpec base, int allow_abstract);

/* ---- globals (extern) ---- */
extern const char *g_input_path;
extern int g_lint_varargs;          /* lexer: a VARARGSn comment not yet on a token */
extern int g_decl_lint_varargs;     /* parser: the current external declaration's */
void stack_census_emit(int frame_bytes, int is_variadic);
extern char        g_sys_inc_dir[256];
extern const char *g_extra_inc_dirs[8];
extern int         g_n_extra_inc_dirs;

/* --- Dependency tracking (-MD/-MF) -------------------------------------
 * fcc records every file it actually OPENS so a build system can rebuild on
 * header edges instead of a hand-maintained staleness list.  Recorded at the
 * single point where an include is really read (pp_read_file), so a header
 * that is probed-but-not-used never lands in the list and a header that IS
 * used cannot be missed.  Order is first-open order; duplicates suppressed.
 *
 * Without this, a ninja/make graph is confidently correct about what it knows
 * and blind to every #include -- exactly the bug class build.sh's hand-written
 * _*_stale() sets suffered from, but harder to see. */
void        pp_dep_add(const char *path);   /* record one opened file */
int         pp_dep_count(void);
const char *pp_dep_get(int i);
extern FILE *g_out;
extern const char *g_data_seg_path;
extern FILE       *g_data_out;
extern const char *g_commons_path;   /* --commons: tentative-def sidecar (K&R A.10.2) */
extern FILE       *g_commons_out;
extern int         g_far_calls;
extern int         g_pile;      /* T5-C C3: shared-libc pile TU */
extern int         g_sections;  /* --sections: mark units for fgx_gc */
extern int         g_signed_char; /* --signed-char: sign-extend non-unsigned chars */
extern int         g_fltused;   /* this TU generated floating point code */
/* apple/fgx#88: this TU is linked into a SINGLE-BANK image whose runtime bank
 * is not known at assembly (the far kernel bank).  Narrower than --pile on
 * purpose: a libc pile is also one segment, but a function pointer IT holds
 * can point at a USER callback outside the pile -- qsort's comparator, a
 * signal handler -- so the pile must keep taking the target bank from the
 * pointer.  Kernel C has no such caller. */
extern int         g_kernel_bank;
extern int         g_module_bank;
extern int         g_emit_safepoints; /* preemption P2': loop-top yield safepoints */
void emit_safepoint(void);   /* apple/fgx#371: inline fast path + slow-path call */
extern int         g_libso;          /* --libso: libc.so library mode */
extern int         g_libso_inplace;  /* --libso-inplace: blocks are their templates */
extern const char *g_libso_name;     /* --libso-name: the library's block cells
                                        are _<name>_blk_<member> */
extern const char *g_emit_blocks_path; /* --emit-blocks: member-block sidecar */
extern int         g_pile_far_extern; /* shared-pile onboarding 2026-07-17:
                                 * pile whose calls to functions NOT defined
                                 * in the pile emit FGX2_FARCALL instead of
                                 * near pile calls — lets a library pile
                                 * (termlib/curses) live OUTSIDE the libc
                                 * segment while still calling into it.
                                 * Forward refs to same-pile members also go
                                 * far (single-pass parse can't see them yet)
                                 * — correct, marginally slower. */
extern int         g_void_ctx_ok;   /* void fn call allowed (discarded for-init/step) */
extern int         g_addr_of_chain; /* '&' wants the chain's ADDRESS, not its value */
extern int         g_preincdec_chain; /* prefix ++/-- on a computed-base chain:
                                       * +1 = ++, -1 = --, 0 = none.  Consumed
                                       * once by build_postfix_value_chain. */
extern char g_tu_prefix[32];
extern const char *g_src;
extern size_t      g_src_len;
extern size_t      g_pos;
extern int         g_line;
extern int         g_col;
extern Tok         g_cur;            /* one-token lookahead */;
extern PpMacro *g_pp_macros;      /* dynamic (FCC_GROW); no fixed ceiling */
extern int      g_pp_macros_cap;
extern int     g_pp_n_macros;
extern PpCond g_pp_cond[PP_MAX_COND_DEPTH];
extern int    g_pp_cond_top;
extern char g_str_tok_buf[MAX_STR_TOK_LEN];
extern struct str_lit_s *g_str_lits;   /* dynamic */
extern int  g_str_lits_cap;
extern int  g_n_str_lits;
extern char *g_str_pool;               /* dynamic */
extern int  g_str_pool_cap;
extern int  g_str_pool_used;
extern Global *g_globals;              /* dynamic */
extern int    g_globals_cap;
extern int    g_n_globals;
extern Struct g_structs[MAX_STRUCTS];
extern int    g_n_structs;
extern int    g_tag_scope_depth;
extern Typedef *g_typedefs;      /* dynamic (FCC_GROW); no fixed ceiling */
extern int      g_typedefs_cap;
extern int     g_n_typedefs;
extern FnSig g_fn_sigs[MAX_FN_SIGS];
extern int   g_n_fn_sigs;
extern EnumConst g_enum_consts[MAX_ENUM_CONSTS];
extern int       g_n_enum_consts;
extern Local g_locals[MAX_LOCALS];
extern int   g_n_locals;
extern int   g_n_params;
extern int   g_n_local_decls;
extern int   g_total_slots;
#define MAX_SOFT_SCC 1024      /* tcsh's largest recursion component is 117 */
extern char *g_soft_scc[MAX_SOFT_SCC];
extern int   g_n_soft_scc;
extern int   g_fn_is_soft;
void emit_frame_bank_a(void);        /* A = frame bank (caller in 8-bit M) */
void emit_stage_frame_bank(const char *cell);  /* frame bank -> cell, own 8-bit window */     /* current function is a recursion-cycle member */
int  soft_scc_load(const char *path);
int  soft_scc_member(const char *name);
extern int   g_max_framesize;
extern int   g_n_datamac;   /* P3-5 I3: FGX2_* rows written to g_data_out (MODE + funnel) */
extern char  g_func_name[MAX_IDENT];   /* current function (set at decl) */;
extern StaticAlias g_static_aliases[MAX_STATIC_ALIASES];
extern int         g_n_static_aliases;
extern Local *g_main_argc_local;
extern Local *g_main_argv_local;
extern UserLabel g_user_labels[MAX_USER_LABELS];
extern int       g_n_user_labels;
extern LocalType g_expr_type;
extern int g_stmt_line, g_stmt_col;   /* the statement walk_stmt is emitting */
void require_long_from_ptr_cast(LocalType dst);
extern int g_expr_unsigned;
extern int g_expr_const_int;     /* #12: is the walked value a const int? */
int cast_operand_is_const(int n); /* #12: is this AST node a compile-time int? */
int arith_unsigned(LocalType lt, int lu, LocalType rt, int ru); /* A.6.5 */
int promoted_unsigned(LocalType t, int u);  /* A.6.1: unsigned char -> int */
void emit_itof_rt(void);            /* int -> float call, by g_expr_unsigned */
void emit_ltof_rt(void);            /* long -> float call, by g_expr_unsigned */
int ast_const_int(int n, long *out); /* ...and its VALUE, at target width */
extern int g_binop_unsigned;
extern int g_expr_struct_id;
/* When g_expr_type == LT_FN_PTR, the fn-ptr signature id of the current
 * expression value (>=0), so an indirect call through a computed/deref'd
 * fn-ptr — `(*tbl[i].fn)(args)` — can find the callee's parameter shape.
 * Set wherever an expression evaluates to a fn-ptr; -1 = unknown. */
extern int g_expr_fn_sig;
extern int g_param_byte_offsets[MAX_LOCALS];
extern int   g_s_delta;
extern int   g_loop_depth;

/* RTL-ABI: right-to-left call bookkeeping for one call site (T5-C C5: args
 * are simply WALKED in reverse order when active — see walk_call_args).
 * B2: `active` (arg ORDERING) is decoupled from `varargs` (is this a
 * not-fixed-arity/`...`/`()` callee).  Post-flip `active` is universally 1
 * (uniform R-to-L, K&R/2.11BSD-native); `varargs` alone gates the surviving
 * by-value-struct guard (a struct VALUE as a vararg is unproven vs va_arg). */
typedef struct {
    int active;
    int varargs;
    int has_struct;
} RtlArgs;
void rtl_begin(RtlArgs *r, int active, int varargs);
void rtl_note_struct(RtlArgs *r);
void rtl_finish(RtlArgs *r, int line, int col);

/* --- Increment 3a (IN PROGRESS, additive): per-function expression AST ---
 * build_* consume tokens into g_ast[] WITHOUT emitting; walk_expr replays the
 * historical emission byte-for-byte via the existing emit helpers (which keep
 * maintaining g_expr_* themselves — the globals survive 3a unchanged; see
 * docs/history/plans/2026-07-06-fcc-phase2-frontend.md §Increment 3).
 * NOTHING calls the builders yet: parse_expr() flips to build+walk only when
 * the whole expression grammar builds (primary/unary/assign included).  The
 * node->type fields are the builder's bottom-up typing; FCC_AST_CHECK=1 will
 * assert them against helper-maintained g_expr_type at walk time. */
typedef enum {
    N_NONE = 0,
    N_MUL_INLINE_CONST,   /* lhs * k (mul_const_inlineable) or /,% pow2 (divmod_pow2_inlineable) */
    N_MUL_CONST_LIBCALL,  /* bare-const RHS, not inlinable: LDX #k / STX _fcc_tmp_b / JSR helper */
    N_BINOP,              /* push lhs, walk rhs, emit_scalar_binop; op selects the
                           * emitter; == / != get the multi-bank ptr-as-long
                           * conversion per side (g_data_out && ISPTR, as parsed) */
    N_ADD_IPLUSP,         /* i + p: commute — scale A by rhs stride, add */
    N_ADD_PPLUSI,         /* p + i: bank-stash glue, scale by lhs stride, add */
    N_SUB_PTR_PTR,        /* p - q: sub, divide by stride, pop stashed bank */
    N_SUB_PTR_INT,        /* p - i: bank-stash glue, scale, sub */
    N_SHIFT_NOP,          /* x << 0 / x >> 0: no emission, result int */
    N_SHIFT_INLINE,       /* bare 1..15 const shift: emit_inline_shift */
    N_LOGIC_AND,          /* && short-circuit (labels allocated at walk) */
    N_LOGIC_OR,           /* || short-circuit */
    N_TERNARY,            /* a ? b : c */
    N_COMMA,              /* a , b — value of b */
    /* unary (3a-D) */
    N_SIZEOF,             /* LDA #val (size computed at build) */
    N_PREINC_MEMBER,      /* ++p->f / --p->f: emit_member_incdec prefix RMW */
    N_PREINC_GLOBAL,      /* ++g / --g: load, +/- stride, store back */
    N_PREINC_LOCAL,       /* ++l / --l */
    N_NEG, N_BNOT, N_LNOT,
    N_ADDR_FUNC,          /* &func (or bare func name value) */
    N_ADDR_ARROW_BARE,    /* &base->field: base value + field offset */
    N_ADDR_ARROW_ARRFIELD,/* &base->arrfield[i] */
    N_ADDR_CHAIN_IDX,     /* &base->f->...->p[i]: arrow-chain hops + index */
    N_ADDR_DOT_ARRFIELD,  /* &var.arrfield[i] */
    N_ADDR_DOT_BARE,      /* &var.field */
    N_ADDR_ARR_ELEM,      /* &arr[i](.field...)* — array base (2-byte push) */
    N_ADDR_ARR_ELEM_MD,   /* &arr[i][j]... — MULTI-DIM array base; the
                           * subscripts are kids and the offset is the
                           * per-level stride walk (apple/fgx#192) */
    N_ADDR_PTR_ELEM,      /* &ptr[i] — pointer-value base (4-byte push) */
    N_ADDR_VAR,           /* &var */
    N_DEREF_POSTINC,      /* *p++ / *p-- rvalue */
    N_FNPTR_DESIG,        /* *fp where fp is a fn-ptr: load value + sig */
    N_DEREF_FAST,         /* *local */
    N_DEREF_GENERAL,      /* *expr */
    /* primary, pre-IDENT arms (3a-E part 1) */
    N_CAST,               /* (type)expr — conversions selected at walk from
                           * runtime g_expr_type, target/sid/uns from build */
    N_CAST_FNPTR,         /* (T (*)(params))expr — reinterpret, no conversion */
    N_LIT_INT,            /* int literal (val; val_hi+is-long in op==TOK_LONG_KW hack? no: val_hi + b as flag) */
    N_LIT_LONG,           /* long literal (val/val_hi) */
    N_LIT_LLONG,          /* long long literal (val/val_hi/val2/val3) */
    N_LIT_FLOAT,          /* float literal (IEEE bits in val/val_hi), or a
                           * double one (type LT_DOUBLE, val..val3) */
    N_LIT_CHAR,           /* char literal */
    N_LIT_STR,            /* string literal (val = pool label) */
    N_IPV_READ,           /* value-base subscript read: a=base, b=index */
    N_IPV_STORE,          /* value-base subscript store: a=base, b=index, c=rhs */
    N_ARROW_CHAIN,        /* value-base '->' chain: a=base, hops in g_ast_fields */
    N_CALL_STASHED,       /* call through fn-ptr VALUE: a=callee, args=kid span */
    /* primary IDENT arm (3a-E part 2) */
    N_SETJMP,             /* setjmp(env): a=env */
    N_LONGJMP,            /* longjmp(env,val): a=env, b=val */
    N_SYSCALL,            /* __syscall[_db](num,...): val=num, kids=a,x,y[,bank] */
    N_SYSCALL_CELL,       /* __syscall_c()/__syscall_y(): val = 0 carry, 1 Y */
    N_CALL_FPVAR,         /* fp(args), fp a fn-ptr var: load-after-args */
    N_CALL_NAMED,         /* named/libc call: val=fn_idx, sym_lb, args=kids */
    N_CALL_FPFIELD,       /* obj.field(args): load-field-after-args */
    N_ENUM_CONST,         /* enum constant: LDA #val */
    N_VAR_LOAD,           /* plain var read / array decay / struct value */
    N_ARR_READ,           /* arr[i]... indexed read (air head/chain/tail) */
    N_ARR_POSTINC,        /* arr[i]++ / arr[i]-- address-based RMW */
    N_POSTINC_LOCAL,      /* l++ / l-- (old value) */
    N_POSTINC_GLOBAL,     /* g++ / g-- (old value) */
    N_POSTINC_MEMBER,     /* p->f++ / p->f-- (old value) */
    N_ELEM_ADDR,          /* &base[i](+cum): 2-byte push glue; A = elem addr */
    N_AV_ELEM_ADDR,       /* ->structval.leaf[j]: 4-byte push glue + elem load */
    N_ELEM_CHAR,          /* A=addr -> byte load (a = addr node) */
    N_ELEM_INT,           /* A=addr -> word load */
    N_ELEM_LONG,          /* A=addr -> 4-byte load via ptr-field loader */
    N_ELEM_FIELD,         /* A=addr -> emit_deref_ptr_field(f2) */
    N_SAF_IDX,            /* arr[i].field[j] char/int rvalue */
    N_SAF_IDXW,           /* arr[i].field[j] rvalue, WIDE element (apple/fgx#170):
                           * long, float or a pointer.  val_hi = the stride,
                           * type = what to load.  Separate from N_SAF_IDX so
                           * the char/int path keeps its exact emission and the
                           * goldens taken against it. */
    N_FIELD_DECAY,        /* A=elem addr -> + field off, decay to ptr */
    N_FIELD_DEREF,        /* A=elem addr -> emit_deref_ptr_field(f) */
    N_DOT_ARRAY_DECAY,    /* struct.arr bare decay: addr + cum */
    N_DOT_SCALAR,         /* struct.field... scalar leaf load (synth field) */
    N_G34_BANK,           /* .field-> chain bank refresh (single-bank PHK) */
    N_AV_DECAY,           /* ->structval.leaf array decay (load base + cum) */
    N_AV_SCALAR,          /* ->structval.leaf scalar: + cum, deref at 0 */
    N_ARROW_LOAD_CHAIN,   /* base->f(->g)*.leaf scalar chain (named base) */
    N_ELEM_PTRELEM,       /* A=addr -> 4-byte ptr elem load (val = elem type) */
    /* expression-context stores (3a-F) */
    N_DSTORE,             /* *p[++/--]? = rhs (deref-store classifier arm) */
    N_STORE_VAR,          /* IDENT = rhs */
    N_COMPOUND_VAR,       /* IDENT op= rhs */
    N_STORE_DOTFIELD,     /* IDENT.f... = rhs (scalar leaf) */
    N_STORE_PTRARR_ELEM,  /* IDENT->pf[i] = rhs (ptr-array field elem) */
    N_STORE_MEMBER,       /* IDENT->f = rhs (scalar/ptr leaf) */
    N_STORE_SARR_MEMBER,  /* IDENT[i].f = rhs (struct-array elem member, expr ctx) */
    N_STORE_ARR_ELEM,     /* IDENT[i] = rhs (1-D char/int array or ptr) */
    /* statements (3b phase 1) */
    S_LABEL,              /* IDENT ':' — user label definition */
    S_GOTO,               /* goto IDENT ';' */
    S_BREAK,              /* break ';' (loop-ctx read at walk) */
    S_CONTINUE,           /* continue ';' */
    S_RETURN,             /* return [expr] ';' (a = -1 for bare) */
    S_PREINC_DEREF,       /* ++*p ; / --*p ; deref-lvalue RMW */
    S_PREINC_STMT,        /* ++x ; / --x ; standalone prefix incdec */
    S_DSTORE_COMPOUND,    /* *p[++/--]? op= rhs ; (local ptr fast path) */
    S_DSTORE_LOCAL,       /* *p[++/--]? = rhs ; (walk decides promotable pair) */
    S_DSTORE_GENERAL,     /* *unary = rhs ; */
    S_DSTORE_STRUCT_COPY, /* *pd = <struct lvalue> ; whole-struct copy */
    S_STORE_DOT_ARRFIELD, /* IDENT.arr_field[i](.sub)? = rhs ; */
    S_COMPOUND_DOTFIELD,  /* IDENT.f... op= rhs ; */
    S_AV_STORE,           /* IDENT->structval.sub([j])? = rhs ; */
    S_CHAIN_STORE,        /* IDENT->a->...->f [op]= rhs ; (+ G32 f[i] =) */
    S_STORE_ARROW_ARRFIELD,/* IDENT->arr_field[i](.sub)? = rhs ; */
    S_STORE_PTRFIELD_IDX, /* IDENT->p[i] = rhs ; (G25, p a ptr field) */
    S_MEMBER_INCDEC_STMT, /* IDENT->f++ ; / -- ; (G31 statement RMW) */
    S_COMPOUND_MEMBER,    /* IDENT->f op= rhs ; */
    S_POSTINC_VAR_STMT,   /* IDENT++ ; / -- ; (discarded; global ptr ok) */
    S_SARR_FIELD_IDX,     /* arr[i].field[j] = rhs (bank re-establish store) */
    S_FIELD_STORE_AT,     /* <addr node>->field = rhs via push_ptr + dpfs */
    S_FIELD_INCDEC_AT,    /* <addr node> field ++/-- RMW (G31 twin) */
    S_FIELD_COMPOUND_AT,  /* <addr node> field op= rhs */
    S_ARR_STORE,          /* arr[i](...[j])* [op]= rhs — general N-D store */
    /* statements (3b phase 2: control flow as trees) */
    S_EMPTY,              /* ';' */
    S_EXPR,               /* expression statement (G20 paren form) */
    S_IF,                 /* if (a) b [else c] */
    S_WHILE,              /* while (a) b */
    S_DO,                 /* do b while (a); */
    S_FOR,                /* for (init; a; step) b — kids [init][step] */
    S_SWITCH,             /* switch (a) { kids } */
    S_CASE,               /* case VAL: (val = case value; val_hi = case idx) */
    S_DEFAULT,            /* default: */
    S_ASM,                /* __asm("line",...): kids = N_LIT_STR verbatim lines */
    S_BLOCK,              /* { kids } */
    S_DECL,               /* local decl: registration at build; kids = inits */
    S_DECL_ARRINIT,       /* local array brace init (kids = elems) */
    S_DECL_STRUCTINIT,    /* local struct brace init (kids = field inits) */

    /* Uniform lvalue-address walker (K&R-canonical; parse_lvalue.c).  A chain
     * of step nodes (linked via .a = next) computes an lvalue's ADDRESS into an
     * fpr; the head carries the base + leaf type.  See docs plan
     * 2026-07-23-fcc-uniform-lvalue-walker.md. */
    N_LV_STEP_DOT,        /* .field  : off += val (offset); no deref */
    N_LV_STEP_ARROW,      /* ->field : deref then off = val; type=field type */
    N_LV_STEP_INDEX,      /* [b]     : deref-if-ptr then + b*val (elem size) */
    N_LV_STEP_DEREF,      /* *       : deref (cur ptr -> pointee) */
    N_LV_CHAIN,           /* head: sym_lc/gv or a=computed-base; b=first step */
    S_LV_STORE,           /* stmt: chain [op]= rhs (op in .op; rhs in .c) */
    S_LV_INCDEC,          /* stmt: chain ++/-- (flags&AF_IS_INC) */
    N_LV_STORE_E,         /* expr: chain [op]= rhs, VALUE-leaving (op/.c as S_LV_STORE) */
    N_LV_INCDEC_E,        /* expr: chain ++/-- , VALUE-leaving (flags: AF_IS_INC, AF_RET_OLD) */
    N_ADDR_LV_E,          /* expr: &chain -- emit_lvalue_addr = the address (bank kept) */
    N_LV_LOAD_E           /* expr: chain READ -- emit_lvalue_addr then deref-load leaf */
} NodeKind;
typedef struct {
    NodeKind    kind;
    int         line, col;
    LocalType   type;         /* build-time result type (bottom-up) */
    int         struct_id;    /* -1 unless struct/struct-ptr valued */
    int         fn_sig;       /* -1 unless fn-ptr valued */
    int         is_unsigned;  /* A-1 result signedness */
    int         a, b, c;      /* child node indices; -1 = none */
    TokKind     op;
    unsigned    val, val_hi;  /* literal / constant payload */
    unsigned    val2, val3;   /* words 2 and 3 of a long long payload */
    const char *name;         /* interned symbol text (token vector arena) */
    int         name_len;
    /* resolved-symbol payloads (stable: static tables / per-function arrays
     * that outlive the expression) */
    Local  *sym_lc;
    Global *sym_gv;
    Field  *sym_f;
    Field  *sym_f2;           /* second field (elem .subfield etc.) */
    int     flags;            /* per-kind bit flags (AF_*) */
    int     kid0, n_kids;     /* g_ast_kids[] span (arg lists, hop lists) */
} Node;
#define MAX_AST_NODES 65536   /* whole-FUNCTION window (3c) */
#define MAX_AST_KIDS  32768
extern Node g_ast[MAX_AST_NODES];
extern int  g_n_ast;
extern int  g_ast_peak;     /* T2-0: TU-wide AST peak (Part-V memory measurement) */
extern int  g_intern_total; /* T2-0: intern arena bytes across all blocks */
extern int  g_ident_unique; /* T2-1: distinct identifiers (dedup-interned) */
const char *lex_intern_ident(const char *p, int len);  /* canonical ident ptr */
const char *cellp(const char *base);   /* T2-3: interned cell name (static-buf safe) */
const char *cellp2(const char *base);  /* T2-3: interned "<base>+2" hi-word form */
const char *cellpf(const char *fmt, ...);  /* T2-3: composed interned cell name */
extern int  g_ast_kids[MAX_AST_KIDS];
extern int  g_n_ast_kids;
extern Field *g_ast_fields[MAX_AST_KIDS];   /* arrow-chain hop lists */
extern int    g_n_ast_fields;
tword deref_result_expr_type(tword result);
void ast_reset(void);
int  ast_build_assign(void);
int  build_syscall_builtin(const char *name_ptr, int name_len, int line, int col);
int  ast_build_comma(void);
int  ast_build_unary(void);
void ast_build_call_args(int *kid0, int *n_kids);
void walk_stmt(int n);
int  walk_cio(int kid0, int n_kids, int n_dims, const int *dims, int row_stride);
/* Node.flags bits */
#define AF_BASE_LOAD   1   /* N_ELEM_ADDR: base is a loaded ptr value (else addr-of) */
#define AF_ADC_ALWAYS  2   /* N_ELEM_ADDR: emit CLC/ADC #cum even when cum == 0 */
#define AF_IS_BYTE     4   /* byte-sized element */
#define AF_IS_INC      8   /* ++ (else --) */
#define AF_RET_OLD    16   /* N_LV_INCDEC_E: postfix (value = old); else prefix (new) */
/* bit 32 free (was AF_PF_SPRINTF, retired with the N_CALL_PRINTF special
 * arm — T5-C C5) */
#define AF_IS_PTRSTORE 64  /* N_DSTORE: 4-byte far-pointer store */
#define AF_EL_PTR     128  /* N_STORE_ARR_ELEM: pointer base (load, not addr-of) */
#define AF_STMT_DISCARD 256 /* call in statement context: discard-A cleanup */
#define AF_SYSCALL_DB   512 /* N_SYSCALL: __syscall_db (DBR=bank around the call) */
#define AF_ROW         1024 /* N_SAF_IDX: a rank-2 member's ROW -- its address, not a load */


int  ast_new(NodeKind kind, int line, int col);
int  divmod_pow2_inlineable(unsigned k);
int  mul_const_inlineable(unsigned k);
void walk_expr(int n);
extern int   g_last_stmt_returned;
extern const char *g_emit_sigs_path;
extern const char *g_sigs_path;
void sigs_emit(const char *path);
void blocks_emit(const char *path);   /* --emit-blocks (--libso) */
void core_list_load(const char *path); /* --core-list (--libso) */
int  is_block_static(Global *g);       /* --libso: lives in a member block */
int  block_members(const char **out, int max);
void refuse_block_static(Global *g, const char *path);
void refuse_block_static_in_asm(const char *t, int tl, int line, int col);
int  block_offset(Global *g);
Global *block_static_named(const char *p, int n);
void sigs_load(const char *path);
extern const char *g_emit_defs_path;
void defs_emit(const char *path);
void defs_load(const char *path);
/* Dynamic (FCC_GROW); no fixed ceiling.  The INVERSE of the g_structs NB
 * above: converting this is safe because NOTHING holds a `Func *` across a
 * funcs_declare.  Verified site by site 2026-07-25 -- all 87 parse-time
 * accesses are `g_funcs[idx].field` with the index re-derived at each use, the
 * only appender (funcs_declare) is never called from the walk/emit phases, and
 * Increment 4 made promotion in-place so a handed-out index stays valid
 * forever.  KEEP IT THAT WAY: never hold a Func* across funcs_declare.
 *
 * It had to grow because the --sigs sidecar changed the scaling law from
 * per-TU to WHOLE-PROGRAM function count: tcsh's 279 exported signatures plus
 * its own declarations blew the old 512 cap in nearly every TU. */
extern Func *g_funcs;
extern int   g_funcs_cap;
extern int  g_n_funcs;
extern LoopCtx g_loop_ctx[MAX_LOOP_CTX];
extern int     g_loop_ctx_top;
extern SwitchCase g_sw_cases[MAX_CASES_PER_SWITCH];
extern int        g_n_sw_cases;
extern int        g_sw_default_label;
extern int        g_sw_end_label;
extern SwitchSave g_sw_stack[MAX_SWITCH_NESTING];
extern int        g_sw_top;
extern int g_paren_lvalue_skip_label;
extern int g_pp_eval_depth;
extern int g_pp_body_tok_bytes;   /* T2-2: malloc'd macro-body/expansion token bytes (Part-V stats) */
extern int g_label_n;
extern char g_gname_buf[64];
extern char g_fname_buf[64];
extern int g_anon_struct_n;

/* ---- prototypes ---- */
void
derive_tu_prefix(const char *path);
void
usage(void);
int
user_labels_lookup(const char *name, int name_len);
int
user_labels_intern(const char *name, int name_len, int line, int col);
void
user_labels_reset(void);
__attribute__((noreturn)) void
die(int line, int col, const char *msg);
void
warn_implicit_decl(const char *name, int name_len, int line, int col);
int
splice_line_continuations(char *buf, int len);
void
lex_set_source(const char *buf, int len, const char *path);
int
pp_macro_lookup(const char *name, int name_len);
void
pp_define_text(const char *name, int name_len, const char *body_text);
Tok
pp_next_tok(void);
int
peek_ch(void);
int
adv_ch(void);
void
skip_ws_and_comments(void);
int
is_ident_start(int c);
int
is_ident_cont(int c);
int
is_type_modifier_ident(const char *p, int n);
int
inline_is_specifier(void);
long
pp_apply_op(int op, long a, long b);
void
next_tok(void);
/* Non-destructive 1-token lookahead beyond g_cur (T1.2 constant lowering).
 * See the contract comment at its definition in lex_pp.c. */
Tok
peek_tok(void);
#ifdef FCC_LEX_TEST
void
lex_init_buffer(const char *src);
#endif
void
locals_reset(const char *fname, int fname_len);
void
locals_declare(const char *name, int name_len, LocalKind kind,
               LocalType type, int slot_count, int line, int col);
void
locals_layout(int first);
Local *
locals_lookup(const char *name, int name_len);
Global *
globals_lookup(const char *name, int name_len);
unsigned
init_q(const Global *g, int n);
void
init_put_q(Global *g, int n, long v);
int
structs_lookup(const char *name, int name_len);
int
typedefs_lookup(const char *name, int name_len);
int
enum_consts_lookup(const char *name, int name_len);
int
fn_sig_intern(LocalType ret, int n_params, LocalType *params,
              int *param_struct_ids, int is_variadic, int ret_unsigned);
Global *
globals_declare(const char *name, int name_len, LocalType type,
                int n_elems, int line, int col, int is_extern_decl);
int
funcs_declare(const char *name, int name_len, int n_params,
              int line, int col);
int
funcs_lookup(const char *name, int name_len);
int
new_label(void);
void
emit_file_header(void);
const char *
gname(Global *g);
const char *
fname(Func *fn);
void
emit_func_prologue(const char *name, int name_len);
void
emit_load_lit(unsigned value);
void
emit_load_lit_long(unsigned lo, unsigned hi);
void
emit_load_lit_float(unsigned lo, unsigned hi);
int
local_offset(Local *lc);
const char *
slot_addr_str(Local *lc, int extra);
/* P3-3 3.1b: the `; fccstk d= b=` stack-check annotation for an n,S access. */
const char *
slot_annot(Local *lc, int off);
/* G53: 1 iff a LOCAL frame slot needs the far (>255-byte) path; exposed for the
 * isel load-op fold (a foldable n,S leaf must lower to a single n,S instr). */
int
slot_needs_far(Local *lc, int extra);
/* G53: far frame-slot access for >255-byte frames (see emit.c). */
void
emit_warn_uninit_locals(void);
void
emit_slot_lda16(Local *lc, int extra);
void
emit_slot_sta16(Local *lc, int extra);
void
emit_load_local(Local *lc);
void
emit_assign_conv(LocalType dst);      /* A.7.17: long<->float, float->int */
void
emit_to_llong(void);                  /* value -> long long form (A:_fcc_long_hi:_fcc_q2:_fcc_q3) */
void
emit_to_quad(LocalType target);       /* value -> an 8-byte target's form */
void
refuse_double(const char *what);
void
emit_from_double(LocalType dst);      /* long double -> dst's form */
void
emit_d_call(const char *name);
void
emit_d_cmp(const char *br);
void
emit_test_double_zero(void);
void
emit_neg_double(void);
void
emit_double_add_unit(int is_inc);
void
emit_push_llong(void);
void
emit_pop_llong(void);
void
emit_stash_llong_to_b(void);
void
emit_ll_cmp(const char *br);
void
emit_ll_call(const char *name);
void
emit_llong_incdec(Local *lc, Global *gv, int is_inc, int return_old);
void
emit_llong_add_unit(int is_inc);
void
emit_fpr_deref_store_llong(int k, int off);
void
emit_test_llong_zero(void);
void
emit_store_local(Local *lc);
void
emit_incdec_store_local(Local *lc);   /* fcc2 P1.3-inc2: ++/-- store-back */
void
emit_incdec_local(Local *lc, int is_inc);   /* fcc2 P1.4: discarded ++/-- -> promotable INC/DEC */
void
emit_load_global(Global *g);
void
emit_store_global_int(Global *g);
void
emit_store_global_char(Global *g);
void
emit_long_incdec_global(Global *g, int is_inc, int return_old);
void
emit_long_incdec_local(Local *lc, int is_inc, int return_old);
void
emit_addr_of_global(Global *g);
void
emit_addr_of_func(Func *fn);
Field *
struct_field_lookup(int sid, const char *name, int name_len);

/* Flatten a struct into the LEAF slots a brace initializer fills one value
 * each for: an embedded struct VALUE member contributes its own leaves, a
 * non-char ARRAY member one per element, everything else one leaf.  For an
 * all-scalar struct the leaf list IS the field list, which is what keeps
 * existing initializer output byte-identical.  nest[] (may be NULL) records,
 * for each leaf, the aggregate it belongs to at each brace level, so a caller
 * can bound a nested brace group at any depth.  Returns the leaf count, or -1
 * if it exceeds `max`. */
/* A function pointer under zero or more pointer or array layers -- the
 * types whose symbol carries a call signature (fn_sig_id): `int (*fp)()',
 * `int (*tab[4])()', `int (**pp)()'. */
static inline int
fnptr_based(LocalType t)
{
    while (t != LT_FN_PTR && (ISPTR(t) || ISARY(t)))
        t = DECREF(t);
    return t == LT_FN_PTR;
}

/* The function pointer under `levels' further pointer layers. */
static inline LocalType
fnptr_ptr_type(int levels)
{
    LocalType t = LT_FN_PTR;
    while (levels-- > 0)
        t = INCREF(t, DERIV_PTR);
    return t;
}

#define MAX_STRUCT_INIT_LEAVES 96
/* Brace levels recorded per leaf.  nest[i][k] is the aggregate leaf i belongs
 * to at level k -- level 0 the top-level member, each deeper level a struct
 * member, an array row or an array element inside the one above -- or -1
 * where the leaf has no aggregate that deep.  A value is (id << 1) | is_array:
 * ids are unique, so two leaves share a level-k aggregate exactly when their
 * values are equal, and the low bit says whether it is an array (which a
 * string literal may initialize).  Deeper levels are not recorded. */
#define INIT_NEST 8
#define NEST_IS_ARRAY(v) ((v) >= 0 && ((v) & 1))
int
struct_init_leaves(int sid, Field *out, int (*nest)[INIT_NEST], int max);
int
struct_init_leaves_at(int sid, int base_off, Field *out,
                      int (*nest)[INIT_NEST], int max, int n, int *path,
                      int depth);
/* Strict-only member lookup by name+len (no global pun fallback). */
Field *
field_lookup_strict_named(int sid, const char *name, int name_len);
/* Member lookup for a '.' access: strict, because the K&R global pun is a
 * THROUGH-A-POINTER idiom and on '.' the operand's exact type is in hand
 * (apple/fgx#85).  Use struct_field_lookup for '->'. */
Field *
field_lookup_dot(int sid, const char *name, int name_len);
/* A synthetic Field standing for a RUN OF DOTS, carrying the accumulated
 * byte offset in place of any single member's.  Both member-chain readers and
 * the indexed store fold `a.b.c' into one of these, so every arm downstream
 * sees a single member at the cumulative offset and needs no depth of its own.
 * Its pool is per-function and bounded; see the definition. */
Field *
elem_synth_leaf(LocalType type, int off, int sid, int uns);
/* K&R global member-namespace lookup (A.7.3): resolve a member by its offset in
 * whichever struct defines it.  out_container_sid (nullable) gets that struct's
 * id, for coercing a non-struct base pointer to the punned struct type. */
Field *
field_lookup_global(const char *name, int name_len, int *out_container_sid);
void
emit_load_local_field(Local *lc, Field *f);
void
emit_load_global_field(Global *g, Field *f);
void
emit_store_local_field(Local *lc, Field *f);
void
emit_store_global_field(Global *g, Field *f);
void
emit_store_local_elem(Local *lc, int off, int es, LocalType vtype);
void
emit_deref_ptr_field(LocalType field_type, int field_offset);
void
emit_deref_ptr_field_store(LocalType field_type, int field_offset);
void
emit_member_incdec(Local *lc, Global *gv, Field *f, int is_inc, int is_prefix);
void
emit_long_unit_to_b(int is_inc);
void
emit_wide_incdec_at_fpr(int kd, int off, LocalType lt, int is_inc,
                        int return_old);
void
emit_long_incdec_at_fpr(int kd, int off, int is_inc, int return_old);
void
emit_wide_member_incdec(Local *lc, Global *gv, int off, LocalType lt,
                        int is_inc, int return_old);
void
emit_float_var_incdec(Local *lc, Global *gv, int is_inc, int return_old);
void
emit_long_member_incdec(Local *lc, Global *gv, int off, int is_inc,
                        int return_old);
void
emit_prologue_unconditional(void);
void
emit_epilogue_return(void);
void
emit_push_a(void);
void
emit_pop_a(void);
void
emit_push_ptr(void);
void
emit_struct_copy(int nbytes);
void
emit_load_value_bank(void);
void
emit_ptr_to_long_for_cmp(void);
void
emit_push_long(void);
void
emit_pop_long(void);
int
is_ptr_type(LocalType t);
int
is_ptr_array(LocalType t);
void
emit_call(const char *name, int name_len, int is_far);
void
prescan_static_funcs(void);   /* register file-scope static fn names for forward-ref mangling */
int
fgx2_libc_far(void);
void
emit_libc_call(const char *asm_name);
void
emit_call_indirect(int kc);
void
emit_drop_arg_bytes(int bytes, int discard);
void
emit_addr_of_local(Local *lc);
void
emit_fpr_load_ptr_at_fcc_ptr(int k);
void
emit_deref_result_via_fcc_ptr(tword result);
void
emit_deref_fast(Local *lc);
void
emit_deref_postinc_local(Local *lc, int is_inc, int stride);  /* fcc2 P1.4 B1c: *p++ walk idiom */
/* fcc2 P1.4 B1c-2a-step-2: `*p++ = RHS` walk-WRITE push-elision (statement context,
 * int/char/void pointee).  SETUP brackets the RHS open (load p + bump + store-back +
 * push); STORE brackets it closed (deref-store / collapsed img store). */
void
emit_walk_store_setup(Local *lc, int stride, int is_inc);
void
emit_walk_store(Local *lc, int stride, int is_inc);
/* fcc2 P1.4 B1b: a single-level int/char/void-pointee pointer local is promotable to
 * a DP-IMG pair (defined in ir.c).  Exposed so parse_stmt can route only that set
 * through the walk-store ops (the deref-store-deferral-safe set). */
int
ir_ptr_promotable(Local *lc);
void
emit_deref_general(void);
void
emit_deref_store(void);
void
emit_deref_store_long(tword target);
void
emit_deref_store_byte(void);
void
emit_deref_store_ptr(void);
void
emit_deref_store_dispatch(LocalType ptr_type);
void
emit_load_base(Local *lc);
/* Local-aggregate element store: on entry the element OFFSET is at 1,S and the
 * datum value is in A (MX %00).  Stages a bank-aware pointer in _fcc_ptr (offset
 * from 1,S, bank = 0 — the frame is on the bank-0 HW stack) and leaves the value
 * back in A so the caller can `STA [_fcc_ptr]` (M=8 byte / M=16 word).  Uses the
 * bank-aware indirect (not `STAL $000000,X`) so it stays correct when the array
 * is also touched via a far pointer. */
void
emit_soft_local_store_ptr(void);
int
ipv_elem_size(LocalType pt);
void
emit_ipv_scale_add(int es);
void
emit_ipv_read_elem(LocalType pt, int es);
void
emit_cio_scale(int stride);
int
air_row_stride(Local *lc);

/* The element size a multi-dim array's row stride is built from (#192). */
int
arr_row_elem_size(tword t);
int
emit_air_head(Local *lc);
int
emit_air_tail(Local *lc, int idx_snap, int consumed);
int
emit_airg_tail(Global *gv, int consumed);
void
emit_stash_rhs(void);
void
emit_promote_a_to_long(void);
void
emit_int_to_float(void);
void
emit_float_to_int(void);
void
emit_long_to_float(void);
void
emit_float_to_long(void);
void
emit_stash_long_to_b(void);
void
emit_stage_long_b(long k);
void
emit_long_binop_const(int lhs_unsigned, LocalType rhs_type, int rhs_unsigned,
                      long k, void (*fn)(void));
void
emit_scalar_binop(LocalType lhs_type, LocalType rhs_type,
                  int lhs_unsigned, int rhs_unsigned, void (*fn)(void));
void
emit_binop_add(void);
void
emit_binop_sub(void);
void
emit_unary_neg(void);
void
emit_unary_bnot(void);
void
emit_unary_lnot(void);
void
emit_binop_mul(void);
void
emit_binop_div(void);
void
emit_binop_mod(void);
void
emit_binop_shl(void);
void
emit_binop_shr(void);
/* T1.2: inline constant shift on A — ASL×k (<<) / LSR×k (unsigned >>). */
void
emit_inline_shift(TokKind op, int is_unsigned, unsigned k);
/* T1.2: inline constant multiply (pow2 -> ASL) / unsigned pow2 div-mod
 * (LSR / AND).  Each returns 1 if it emitted inline code, 0 to keep the libcall. */
int
emit_inline_mul_const(unsigned k);
int
emit_inline_divmod_pow2(TokKind op, unsigned k);
void
emit_inline_divs_pow2(unsigned k);
void
emit_inline_mods_pow2(unsigned k);

int  long_shift_inlineable(int is_lshift, int is_unsigned, unsigned k);
void emit_inline_long_shl(unsigned k);
void emit_inline_long_shr(int is_unsigned, unsigned k);
/* Tier-1: scale A by a constant array/struct element stride (subscript / pointer
 * arithmetic).  pow2 -> ASL; small non-pow2 -> shift-add; else _fcc_mul16. */
void
emit_index_scale(unsigned stride);
void
emit_binop_band(void);
void
emit_binop_bor(void);
void
emit_binop_bxor(void);
int
is_compound_op(TokKind k);
void
emit_binop_for_compound(TokKind op, int lhs_unsigned);
void emit_compound_op(TokKind op, int lhs_unsigned, LocalType lt);
void
emit_scale_compound_ptr(LocalType lhs_type, int struct_id, TokKind op);
void
emit_label(int n);
enum { IRC_BEQ, IRC_BNE, IRC_BCC, IRC_BCS, IRC_BMI, IRC_BPL, IRC_BVC,
       IRC_BVS };                                   /* T2-3: IR_BCOND conds */
void emit_br(int n, int is_brl);                   /* T2-3: BRA/BRL <tu>_Ln */
void emit_bcond(int cond, int n, int far);          /* T2-3: Bcc [<tu>_Ln | *+5+BRL] */
void emit_jsr_rt(const char *name);                 /* T2-3: JSR runtime helper */
int  fpr_is_sym(int k);                          /* &global+off, not yet built */
void fpr_sym_flush(int k);                       /* build it (A preserved) */
void fpr_sym_flush_live(void);
void fpr_sym_live_check(void);
void emit_fpr_add_index(int k, int idx, unsigned stride);                   /* die if one is live */
void emit_incdec_at_sym(int k, int stride, int is_inc, int is_prefix,
                        int is_ptr, tword rt, int rt_sid);
Local *param_addr_node(int n);   /* params_home: &param in the body */
void emit_restage_base_bank(Local *lc, Global *gv);   /* after an index that calls */
void emit_incdec_at_fpr(int k, int stride, int is_inc, int is_prefix,
                        int is_ptr, tword rt, int rt_sid);
void emit_ptr_incdec_into_fpr(int k, int off, int stride, int is_inc, int is_prefix);
void emit_m8(void);                                 /* T2-3: SEP #$20 / MX %10 */
void emit_m16(void);                                /* T2-3: REP #$20 / MX %00 */
void
emit_test_a_zero(void);
void emit_fpr_test_zero(int k);
void emit_test_long_zero(int is_float);
void walk_cond(int n);
void walk_cond_branch(int n, int label, int want_true);
void emit_cmp_branch(TokKind op, int is_unsigned, int label, int want_true);
void emit_cmp_zero_branch(TokKind op, int label, int want_true);
void
emit_beq_label(int n);
void
emit_bne_label(int n);
void
emit_bra_label(int n);
void
emit_brl_label(int n);
int
ptr_stride(LocalType t);
int
elem_size_for(LocalType t, int struct_id);
int
type_size_bytes(LocalType t, int n_elems);
/* sizeof(type) helpers (shared by the runtime and constant-expression paths). */
int  cur_begins_type(void);
long sizeof_type_value(void);
void emit_cmp_eq(void);
void emit_cmp_ne(void);
void emit_cmp_lt(void);
void emit_cmp_gt(void);
void emit_cmp_le(void);
void emit_cmp_ge(void);
void
expect(TokKind k, const char *what);
void
push_loop_ctx(int break_lab, int continue_lab);
void
pop_loop_ctx(void);
int
parse_struct_def(const char *tag_ptr, int tag_len, int is_union);
TypeSpec
parse_type_spec(void);
void long_double_or_die(void);
void consume_trailing_specifiers(LocalType *base, int *is_unsigned);   /* `long double' is double; `long float' dies */
LocalType
type_for_decl(TypeSpec t, int stars, int is_array);
/* C parameter adjustment: array-typed parameter -> pointer to element. */
LocalType
param_adjust_type(LocalType t);
int
parse_fn_ptr_declarator(TypeSpec base_t,
                        const char **out_name_ptr, int *out_name_len,
                        int *out_sig_id,
                            int *out_pp);
/* The `( params )' of a function-pointer declarator, as a signature. */
int parse_fnptr_sig(TypeSpec base_t, int ret_stars);
void
parse_unary(void);
void
parse_expr(void);
void
parse_comma(void);
void
parse_assign(void);
unsigned long
parse_case_const(void);   /* full 32-bit; the switch builder truncates
                             to 16 unless the selector is LONG */
void
parse_static_local(void);
void
parse_func_decl_with_spec(TypeSpec ret_t);
int
strlit_intern(const char *bytes, int n);
int
strlit_intern_blob(const char *bytes, int n);
void
emit_str_pool(void);
int
parse_nested_brace_init(Global *g, int *n_init_values,
                        int level, int n_dims, int *dims,
                        int max_init, LocalType at);
long
parse_const_atom(void);
long
parse_const_unary(void);
int
parse_const_prec(int kind);
long
parse_const_bin(int min_prec);
void
parse_global_decl(TypeSpec t);
void
emit_globals_section(void);
void
parse_typedef_def(void);
void
parse_enum_body(void);
void
parse_enum_def(void);
void
parse_program(void);
int
main(int argc, char **argv);

#endif /* FCC_H */

/* ===== P3-2 T1: far-pointer expression register (FPR) vocabulary =========
 * emit.c; inert until the P3-2.2 walker flip.  See the emit.c section
 * comment + docs/history/plans/2026-07-07-fcc-p32-pointer-model.md. */
int  fpr_alloc(void);
void fpr_free(int k);
void fpr_reset(void);
int  fpr_live(void);
void emit_fpr_lit(int k, unsigned off);
void emit_fpr_mov(int dst, int src);
void emit_fpr_bank_dbr(int k);
void emit_fpr_bank_pbr(int k);
void emit_fpr_addr_global(int k, Global *g);
void emit_fpr_addr_local_soft(int k, Local *lc);
const char *fpr_name(int k);   /* FPR cell name (T5-C ptr<->long cast funnel) */
void emit_fpr_from_carrier(int k);
void emit_fpr_from_carrier_a(int k);
void emit_fpr_to_carrier(int k);
void emit_fpr_deref_load(int k, tword pointee);
void emit_fpr_deref_store_word(int k, int off);
void emit_fpr_deref_store_byte(int k, int off);
void emit_fpr_add_a(int k);
void emit_fpr_push_lower(int k);
void emit_fpr_push(int k);
void emit_fpr_ret(int k);
/* #12: which bank an INTEGER takes when it materializes as a pointer.  No
 * default value and no default argument -- every materialization site must
 * choose, so a missed site fails to build instead of silently taking bank 0. */
typedef enum { BANK_ZERO, BANK_DBR, BANK_LONG_HI } BankSel;
#define BANK_OF_CONST(is_const) ((is_const) ? BANK_ZERO : BANK_DBR)
/* The bank a non-pointer RHS of type `t' takes when it becomes a pointer: a
 * LONG carries its own in its high word; an int takes the #12 rule. */
#define BANK_OF_RHS(t, is_const) ((t) == LT_LONG ? BANK_LONG_HI : BANK_OF_CONST(is_const))
void emit_long_hi_bank(void);
void emit_fpr_from_a(int k, BankSel bank);
void emit_fpr_add_const(int k, int n);
void emit_fpr_cmp(int k1, int k2, int is_ne);
void emit_fpr_deref_field(int k, tword t, int off);
void emit_fpr_store_local_4(Local *lc, int off, int k);
void emit_fpr_deref_store_long(int k, int off);
void emit_fpr_deref_store_ptr(int kd, int ks, int off);
void emit_fpr_load_global_ptr(int k, Global *g);
void emit_fpr_store_global_ptr(int k, Global *g);
void emit_fpr_lit_str(int k, int sidx);
void emit_fpr_addr_func(int k, Func *fn);
int  emit_fpr_spill_live(void);
void emit_fpr_restore_live(int n);
void emit_fpr_to_a(int k);
void emit_fpr_off_from_a(int k);
void emit_fpr_diff(int k1, int k2);
void emit_fpr_sub_a(int k);
void emit_fpr_incdec_home_global(int k, Global *g, int delta, int update_fpr);
void walk_expr_root(int n);
void walk_expr_stmt(int n);   /* statement context: ptr result dropped, not bridged */
void emit_fpr_load_field(int k, Local *lc, Global *g, Field *f);
void emit_fpr_struct_copy(int kd, int ks, int nbytes);
void emit_fpr_arg_window(int k, int nbytes);
/* P3-2.5a: FPR-native ptr-local value load/store (IR-structured; promotion
 * retargets to the img forms).  Load leaves A = offset word. */
void emit_fpr_load_ptr_local(int k, Local *lc);
void emit_fpr_store_ptr_local(int k, Local *lc);
/* P3-2.3: the walker FPR protocol, shared with the statement arms. */
void walk_val(int n);
int  walk_fpr(int n);
/* Uniform K&R lvalue-address walker (parse_stmt.c); reused by the expression
 * parser/walk for value-leaving lvalue stores/incdec (N_LV_STORE_E etc.). */
int  emit_lvalue_addr(int head);
int  emit_lvalue_addr_off(int head, int *offp);
void build_lvalue_suffixes(int head, LocalType cur, int cur_sid);
void require_assignable(LocalType t, TokKind op);
int  build_struct_var_store(Local *lc, Global *gv, int rhs, int line, int col);
int  build_postfix_value_chain(int base);
int  fpr_in(void);
void fpr_drop(int k);
int  fpr_load_sym(Local *lc, Global *gv);
void emit_incdec_at_fcc_ptr(int stride, int is_inc, int is_prefix, int is_ptr,
                            tword rt, int rt_sid);   /* in-place RMW at [_fcc_ptr] */
int  fpr_addr_sym(Local *lc, Global *gv);
