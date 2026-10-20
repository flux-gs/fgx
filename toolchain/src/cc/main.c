#include "fcc.h"
#include "peephole.h"
#include <fcntl.h>
#include <sys/wait.h>
#include <unistd.h>

/* Build-time version string.  The host Makefile injects the real value via
 * -DFCC_VERSION from `git describe --tags --match 'v*' --always --dirty`.
 * The constant default keeps any non-Makefile build deterministic. */
#ifndef FCC_VERSION
#define FCC_VERSION "unknown"
#endif

/* P3-5 I2: toolchain-contract stamp.  fcc writes `FGX2_MODE <this>` at the
 * top of BOTH outputs (code .s + data .s); fgx_ld fails any link whose
 * listings carry a different (or, for FGX3 output, absent) value — the
 * Layer2Gate that catches a stale pre-flip .s staged into a post-flip link.
 * Bump on any incompatible codegen/ABI contract change.  Keep in sync:
 * fgx_ld.py FGX_ABI_CURRENT, include/loader.s FGX_ABI_CURRENT (FGX side). */
#define FGX_MODE_CURRENT 2

/* P3-5 I3: count listing-significant FGX2_* macro rows in the final asm
 * text — the post-peephole GROUND TRUTH for the FGX2_RELOC_COUNT trailer.
 * A row = [optional label token] FGX2_* mnemonic; comment lines (';'/'*')
 * never count.  Must mirror fgx_ld's _is_ld_macro recognizer. */
static int
count_fgx2_rows(const char *text)
{
    int n = 0;
    const char *p = text;
    while (*p) {
        const char *t0;
        int t0len = 0;
        /* token 0 */
        while (*p == ' ' || *p == '\t') p++;
        t0 = p;
        while (*p && *p != ' ' && *p != '\t' && *p != '\n') { p++; t0len++; }
        if (t0len > 0 && t0[0] != ';' && t0[0] != '*') {
            if (strncmp(t0, "FGX2_", 5) == 0) {
                n++;
            } else {
                /* labelled row: token 1 may be the macro */
                while (*p == ' ' || *p == '\t') p++;
                if (strncmp(p, "FGX2_", 5) == 0) n++;
            }
        }
        while (*p && *p != '\n') p++;
        if (*p) p++;
    }
    return n;
}

/* --sections, data half: rewrite the finished data segment with each data
 * item in FGX_SECT <label> ... FGX_ENDS.  An item is what fcc writes for one
 * global, static, string or relocation cell: a column-1 label and its
 * indented continuation rows, preceded by its FGX2_EXPORT row when it has
 * one.  A blank line, a column-0 comment or the MODE/RELOC_COUNT rows close
 * the open item and stay outside any section.  A section fcc delimited
 * itself -- a --libso block template, whose statics sit at offsets the code
 * has compiled in -- passes through whole.  The code half is marked where
 * each function is emitted (emit_func_prologue, and after its STKGUARD). */
static int
dsec_is_label(const char *l)
{
    return *l && *l != ' ' && *l != '\t' && *l != ';' && *l != '*' &&
           *l != '\n';
}

static int
dsec_starts(const char *l, const char *word)
{
    while (*l == ' ' || *l == '\t') l++;
    return strncmp(l, word, strlen(word)) == 0;
}

static void
data_sections(const char *path)
{
    FILE *f;
    char *buf, **ln = NULL;
    long len;
    int n = 0, cap = 0, open = 0, verbatim = 0;

    fflush(g_data_out);
    f = fopen(path, "r");
    if (!f) { perror(path); exit(1); }
    fseek(f, 0, SEEK_END);
    len = ftell(f);
    rewind(f);
    buf = malloc((size_t)len + 1);
    if (!buf || fread(buf, 1, (size_t)len, f) != (size_t)len) {
        fprintf(stderr, "fcc: --sections: cannot read %s\n", path);
        exit(1);
    }
    buf[len] = '\0';
    fclose(f);
    for (char *p = buf; *p; ) {
        if (n == cap) {
            cap = cap ? cap * 2 : 1024;
            ln = n ? realloc(ln, (size_t)cap * sizeof *ln)
                   : malloc((size_t)cap * sizeof *ln);
        }
        ln[n++] = p;
        while (*p && *p != '\n') p++;
        if (*p) *p++ = '\0';
    }
    fclose(g_data_out);
    g_data_out = fopen(path, "w");
    if (!g_data_out) { perror(path); exit(1); }
    for (int i = 0; i < n; i++) {
        const char *l = ln[i];
        const char *lab = NULL;
        if (verbatim) {
            fprintf(g_data_out, "%s\n", l);
            if (dsec_starts(l, "FGX_ENDS"))
                verbatim = 0;
            continue;
        }
        if (dsec_starts(l, "FGX_SECT")) {
            if (open)
                fprintf(g_data_out, "                FGX_ENDS\n");
            open = 0;
            verbatim = 1;
            fprintf(g_data_out, "%s\n", l);
            continue;
        }
        if (dsec_is_label(l))
            lab = l;
        else if (dsec_starts(l, "FGX2_EXPORT") && i + 1 < n &&
                 dsec_is_label(ln[i + 1]))
            lab = ln[i + 1];
        if (lab) {
            int k = 0;
            while (lab[k] && lab[k] != ' ' && lab[k] != '\t') k++;
            if (open)
                fprintf(g_data_out, "                FGX_ENDS\n");
            fprintf(g_data_out, "                FGX_SECT %.*s\n", k, lab);
            open = 1;
            fprintf(g_data_out, "%s\n", l);
            if (lab != l) fprintf(g_data_out, "%s\n", ln[++i]);
            continue;
        }
        if (!*l || *l == ';' || *l == '*' || dsec_starts(l, "FGX2_MODE") ||
            dsec_starts(l, "FGX2_RELOC_COUNT")) {
            if (open)
                fprintf(g_data_out, "                FGX_ENDS\n");
            open = 0;
        }
        fprintf(g_data_out, "%s\n", l);
    }
    if (open)
        fprintf(g_data_out, "                FGX_ENDS\n");
    fflush(g_data_out);
    free(ln);
    free(buf);
}

void
usage(void)
{
    fprintf(stderr, "usage: fcc <input.c> [-o <output.s>] [-I dir]... "
                    "[-Dname[=value]]... [-include <file>]...\n"
                    "       [-MD] [-MF <depfile>]   emit a make/ninja depfile\n"
                    "       [--libso] [--emit-blocks <file>]   libc.so library mode\n"
                    "       [--libso-name <name>]   a library's name (block cells _<name>_blk_)\n");
    exit(1);
}

int
is_type_modifier_ident(const char *p, int n)
{
    return (n == 8 && memcmp(p, "unsigned", 8) == 0)
        || (n == 6 && memcmp(p, "signed",   6) == 0)
        || (n == 5 && memcmp(p, "short",    5) == 0)
        || (n == 5 && memcmp(p, "const",    5) == 0)
        || (n == 6 && memcmp(p, "extern",   6) == 0)
        || (n == 8 && memcmp(p, "register", 8) == 0)
        || (n == 4 && memcmp(p, "auto",     4) == 0)
        || (n == 8 && memcmp(p, "volatile", 8) == 0)
        || (n == 6 && memcmp(p, "inline",   6) == 0);
}

int
local_offset(Local *lc)
{
    /* (The RTL-ABI raw-bake latch that lived here is gone — T5-C C5: a
     * right-to-left call now WALKS its args in reverse order instead of
     * record-and-reverse, so every n,S offset — raw IR_TEXT bake or
     * structured-op u0 snapshot — is taken at its true stack depth.) */
    if (lc->kind == LK_LOCAL) {
        return 2 * lc->slot_first + 1 + g_s_delta;
    }
    /* Param offset *excluding* the frame.  Callers that emit stack-rel
     * addressing for params must wrap with FRAMESIZE — see slot_addr_str()
     * which formats the operand symbolically.
     * Return-address size above the params: a far FGX2_FARCALL = JSL pushes 3
     * (PCL/PCH/PB); under --far-calls every user fn is JSL-reached, so params
     * sit 1 byte deeper (off-mode keeps retn=2). */
    int retn  = 3;                    /* JSL frame: PCL/PCH/PB (one-mode) */
    int j     = lc->slot_first;
    return retn + 1 + g_param_byte_offsets[j] + g_s_delta;
}

const char *
slot_addr_str(Local *lc, int extra)
{
    static char buf[64];
    int off = local_offset(lc) + extra;
    /* Locals: frame-pointer slot offset (also the n,S base once converted at
     * 3.1b+); no FRAMESIZE term. */
    if (lc->kind == LK_LOCAL) {
        snprintf(buf, sizeof buf, "%d", off);
        return buf;
    }
    /* P3-3 FP-repoint: params sit ABOVE the hardware-stack frame plus the
     * saved-FP word, so their n,S displacement gains FRAMESIZE + 2.  FRAMESIZE
     * is the symbolic per-function EQU (patched at function end); Merlin
     * resolves the forward reference, including inside the DO far-gate. */
    snprintf(buf, sizeof buf, "%d+%s_FRAMESIZE", off + 2, g_func_name);
    return buf;
}

int
is_ptr_type(LocalType t)
{
    return ISPTR(t);   /* B-3: any depth of pointer (incl. fn-ptr PTR<FTN>) */
}

int
is_ptr_array(LocalType t)
{
    return ISARY(t) && ISPTR(DECREF(t));
}

int
is_compound_op(TokKind k)
{
    return k == TOK_PLUSEQ || k == TOK_MINUSEQ ||
           k == TOK_STAREQ || k == TOK_SLASHEQ ||
           k == TOK_PERCENTEQ ||
           k == TOK_AMPEQ  || k == TOK_PIPEEQ  ||
           k == TOK_CARETEQ ||
           k == TOK_LSHIFTEQ || k == TOK_RSHIFTEQ;
}

int
ptr_stride(LocalType t)
{
    if (!ISPTR(t) && !ISARY(t)) return 0;   /* not a pointer/array */
    tword pointee = DECREF(t);
    if (ISPTR(pointee)) return 4;           /* pointee is itself a pointer */
    switch (BTYPE(pointee)) {
        case BT_CHAR: return 1;
        case BT_VOID: return 1;             /* void* stride 1 (existing) */
        case BT_INT:  return 2;
        case BT_LONG: return 4;
        case BT_FLOAT: return 4;            /* B-6: float* stride 4 */
        case BT_LLONG: return 8;
        case BT_DOUBLE: return 8;
        default:      return 0;             /* struct handled by elem_size_for */
    }
}

int
elem_size_for(LocalType t, int struct_id)
{
    tword pointee = DECREF(t);
    if (BTYPE(pointee) == BT_STRUCT && !ISPTR(pointee)) {  /* struct* / struct[] */
        if (struct_id < 0)
            die(0, 0, "internal: struct-pointer stride with unknown struct id "
                      "(struct_id lost on the way to pointer arithmetic)");
        /* AN INCOMPLETE STRUCT HAS A REAL ID AND A ZERO SIZE, so the id check
         * above does not catch it and the round-up yields 0 -- which every
         * scaler then treats as "no scaling", emitting base + index.  That is
         * the same silent wild pointer apple/fgx#163 was, arriving by a
         * different door.  K&R A.8.3: a structure is incomplete until its
         * member list is given, and pointer arithmetic needs the size, so the
         * program is ill-formed rather than merely unusual -- say so instead
         * of emitting a stride nobody asked for. */
        if (g_structs[struct_id].total_size == 0)
            die(0, 0, "pointer arithmetic on a pointer to an INCOMPLETE struct "
                      "(its size is not known here, so the index cannot be "
                      "scaled)");
        return (g_structs[struct_id].total_size + 1) & ~1;
    }
    int s = ptr_stride(t);
    return s ? s : 0;
}

int
type_size_bytes(LocalType t, int n_elems)
{
    if (ISPTR(t)) return 4;                 /* long ptr: 3B payload + 1B pad */
    if (ISARY(t)) {
        tword elem = DECREF(t);
        if (ISPTR(elem)) return 4 * n_elems;
        switch (BTYPE(elem)) {
            case BT_CHAR: return n_elems;
            case BT_INT:  return 2 * n_elems;
            case BT_LONG: return 4 * n_elems;
            case BT_FLOAT: return 4 * n_elems;   /* B-6 */
            case BT_LLONG: return 8 * n_elems;
            case BT_DOUBLE: return 8 * n_elems;
            default:      return 2 * n_elems;
        }
    }
    switch (BTYPE(t)) {
        case BT_CHAR: return 1;
        case BT_LONG: return 4;
        case BT_FLOAT: return 4;            /* B-6: float == 32-bit single */
        case BT_LLONG: return 8;
        case BT_DOUBLE: return 8;
        default:      return 2;             /* int / void / struct-by-id elsewhere */
    }
}

void
expect(TokKind k, const char *what)
{
    if (g_cur.kind != k) {
        char buf[128];
        snprintf(buf, sizeof buf, "expected %s", what);
        die(g_cur.line, g_cur.col, buf);
    }
    next_tok();
}

void
push_loop_ctx(int break_lab, int continue_lab)
{
    if (g_loop_ctx_top >= MAX_LOOP_CTX)
        die(g_cur.line, g_cur.col, "loops/switches nested too deep (max " FCC_STR(MAX_LOOP_CTX) ")");
    g_loop_ctx[g_loop_ctx_top].break_label    = break_lab;
    g_loop_ctx[g_loop_ctx_top].continue_label = continue_lab;
    g_loop_ctx_top++;
}

void
pop_loop_ctx(void)
{
    g_loop_ctx_top--;
}

LocalType
type_for_decl(TypeSpec t, int stars, int is_array)
{
    /* B-3 (TWORD): `stars` is the pointer-indirection count (was a 0/1
     * is_ptr flag — still backward-compatible with 0/1 callers).  Builds
     * base + `stars` PTR groups + optional outer ARY.  t.base is a bare
     * TWORD base (LT_INT/CHAR/VOID/STRUCT/LONG == BT_*), so it is used
     * directly.  `char *arr[]` builds ARY<PTR<CHAR>> (== old
     * LT_CHAR_PTR_ARRAY); `int *arr[]` builds ARY<PTR<INT>> (B-5, was a
     * reject). */
    if (stars > TW_MAX_DERIV)
        die(g_cur.line, g_cur.col, "pointer indirection too deep");
    tword base = t.base;
    if (base == TW_VOID && stars == 0)
        die(g_cur.line, g_cur.col, "void declarator must be 'void *p'");
    tword ty = base;
    for (int i = 0; i < stars; i++) ty = INCREF(ty, DERIV_PTR);
    if (is_array) ty = INCREF(ty, DERIV_ARY);
    return ty;
}

/* C parameter adjustment (K&R A.10.1; pcc cgram.y does this in `arg_param`):
 * a parameter DECLARED with array type has type "pointer to element".
 *
 * The syntactic forms (`T p[]`, `T *p[]`) are decayed where the `[` is
 * parsed.  This catches the form whose array-ness arrives inside a TYPEDEF,
 * where there is no `[` at the use site at all -- the 2.11BSD Bourne shell's
 *     typedef struct sysnod SYSTAB[];
 *     syslook(w, syswds)  SYSTAB syswds;
 * Left unadjusted, the param is a real array OBJECT, so reading it decays to
 * the address of its own parameter SLOT (bank 0) instead of the pointer the
 * caller pushed -- sh's builtin and reserved-word tables then scan the stack
 * and never match, killing every builtin and every shell keyword. */
LocalType
param_adjust_type(LocalType t)
{
    return ISARY(t) ? INCREF(DECREF(t), DERIV_PTR) : t;
}

/* collect_switch_cases: RETIRED by Increment 3b — the switch builder
 * gathers case values in one pass and the walker allocates labels in
 * encounter order (same numbering as the old pre-scan). */

/* own_defs_prepass: run this fcc over the same TU with the same input flags
 * and --emit-defs, then load the names and signatures of what it defines, so
 * a --sigs entry that conflicts with this TU's own definition is dropped
 * (symtab.c, defs_load).  The
 * outputs of the pass go to /dev/null and its diagnostics are dropped: the
 * real pass reports the same ones.  If it fails, no list is loaded and the
 * sidecar applies as it did before. */
static void
own_defs_prepass(int argc, char **argv)
{
    char tmpl[] = "/tmp/fcc_defs_XXXXXX";
    char sp[sizeof tmpl + 8];
    char *cargv[256];
    int fd, n = 0, st;
    pid_t pid;

    if ((fd = mkstemp(tmpl)) < 0) { perror("mkstemp"); return; }
    close(fd);
    cargv[n++] = argv[0];
    for (int i = 1; i < argc && n < 248; i++) {
        const char *a = argv[i];
        if (!strcmp(a, "-o") || !strcmp(a, "--data-segment") ||
            !strcmp(a, "--commons") || !strcmp(a, "--emit-sigs") ||
            !strcmp(a, "--emit-defs") || !strcmp(a, "--sigs") ||
            !strcmp(a, "-MF")) {
            i++;                        /* and the path that follows */
            continue;
        }
        if (!strcmp(a, "-MD"))
            continue;
        cargv[n++] = argv[i];
    }
    cargv[n++] = "--emit-defs";
    cargv[n++] = tmpl;
    cargv[n++] = "-o";
    cargv[n++] = "/dev/null";
    cargv[n++] = "--data-segment";
    cargv[n++] = "/dev/null";
    cargv[n] = NULL;
    fflush(NULL);
    if ((pid = fork()) < 0) { perror("fork"); unlink(tmpl); return; }
    if (pid == 0) {
        int nul = open("/dev/null", O_WRONLY);
        if (nul >= 0) { dup2(nul, 1); dup2(nul, 2); }
        unsetenv("FCC_STACK_CENSUS");   /* the real pass is the one counted */
        execvp(argv[0], cargv);
        _exit(127);
    }
    snprintf(sp, sizeof sp, "%s.sigs", tmpl);
    if (waitpid(pid, &st, 0) == pid && WIFEXITED(st) && WEXITSTATUS(st) == 0)
        defs_load(tmpl);
    unlink(tmpl);
    unlink(sp);
}

int
main(int argc, char **argv)
{
    const char *out_path = NULL;
    const char *dep_path = NULL;    /* -MF <file>; NULL = derive from -o */
    int         dep_out  = 0;       /* -MD */
    const char *cli_defines[64];       /* -D name / name=value, verbatim */
    const char *cli_includes[8];       /* -include files, in order */
    int n_cli_includes = 0;
    int         n_cli_defines = 0;
    int i;

    /* Bank-0 stack campaign 1.3: the recursion-SCC member list.  Environment
     * variable, not a flag -- the same delivery the stack census uses; the
     * build sets it per tool (gen.py, rule fcc_c).  Absent or empty ->
     * nothing is soft, codegen unchanged.
     *
     * SET BUT UNUSABLE IS FATAL.  soft_scc_load returns 0 for a path it cannot
     * open, and "0 members" is indistinguishable from "no list requested" --
     * so a build that asked for soft frames and silently got none would look
     * exactly like a passing build: a relative path read from another
     * directory is enough to do it.  An empty list from an existing file is
     * fatal for the same reason: the generator writes no file at all when a
     * binary has no cycles. */
    {
        const char *scc = getenv("FCC_SOFT_SCC");
        if (scc != NULL && *scc != '\0' && soft_scc_load(scc) == 0) {
            fprintf(stderr, "fcc: FCC_SOFT_SCC=%s names no readable soft-frame "
                            "list -- refusing to compile with soft frames "
                            "silently disabled.  If the path is relative, the "
                            "build script may have cd'd away from it.\n", scc);
            exit(1);
        }
    }

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-o") == 0) {
            if (++i >= argc) usage();
            out_path = argv[i];
        } else if (strcmp(argv[i], "--data-segment") == 0) {
            /* P3-2.6 one-mode: the data segment is ALWAYS emitted; this
             * flag only overrides its output path (default: derived from
             * -o as <out>.data.s).  --far-calls retired with the mode
             * collapse — far-call + stored-bank emission is the only
             * lowering. */
            if (++i >= argc) usage();
            g_data_seg_path = argv[i];
        } else if (strcmp(argv[i], "--commons") == 0) {
            /* K&R A.10.2 tentative-def coalescing: route tentative-def globals
             * to a sidecar record file for the gen_commons link pass (multi-TU
             * builds where a K&R-common global -- no `extern` -- appears in
             * several TUs).  Absent = single-TU path (byte-identical). */
            if (++i >= argc) usage();
            g_commons_path = argv[i];
        } else if (strcmp(argv[i], "--emit-sigs") == 0) {
            /* K&R cross-TU signature sidecar (write side).  See --sigs. */
            if (++i >= argc) usage();
            g_emit_sigs_path = argv[i];
        } else if (strcmp(argv[i], "--emit-defs") == 0) {
            /* This TU's defined function names, for the --sigs pre-pass
             * (symtab.c, defs_load). */
            if (++i >= argc) usage();
            g_emit_defs_path = argv[i];
        } else if (strcmp(argv[i], "--sigs") == 0) {
            /* K&R cross-TU signature sidecar (read side).
             *
             * K&R C has no prototypes, so a call to a function DEFINED IN
             * ANOTHER TU is compiled with no parameter types and each argument
             * is pushed at its OWN width.  That is invisible on a PDP-11,
             * where sizeof(int) == sizeof(char *) == 2, and wrong on FGX,
             * where a far pointer is 4.  The classic bite is a bare `0` passed
             * for a pointer parameter: the caller pushes 2 bytes, the callee
             * reads 4, and EVERY LATER ARGUMENT IS SHIFTED.
             *
             * 2.11BSD sh hits exactly this in its backtick path --
             * execute(t, 0, 0, pv) vs execute(TREPTR, INT, INT *, INT *) --
             * so the child read a garbage pipe vector, its dup2 failed
             * silently, and command substitution captured nothing.
             *
             * Fed the sidecar, fcc pre-declares those signatures and the
             * existing declared-param path does the right thing (it already
             * materialises an int-valued arg for a pointer param as a 4-byte
             * NULL).  Absent = unchanged behaviour. */
            if (++i >= argc) usage();
            g_sigs_path = argv[i];
        } else if (strcmp(argv[i], "--sections") == 0) {
            g_sections = 1;
        } else if (strcmp(argv[i], "--pile") == 0) {
            g_pile = 1;                /* T5-C C3: shared-libc pile TU */
        } else if (strcmp(argv[i], "--kernel-bank") == 0) {
            g_kernel_bank = 1;         /* apple/fgx#88: single-bank image,
                                        * runtime bank unknown at assembly AND
                                        * at load -- nothing can ever write it,
                                        * so PHK is the only answer.  The KERNEL
                                        * FAR BANK only; see --module-bank. */
        } else if (strcmp(argv[i], "--module-bank") == 0) {
            g_module_bank = 1;         /* apple/fgx#173: an FGXM module.  Also a
                                        * single-bank image, but unlike the far
                                        * bank its runtime bank IS knowable --
                                        * PHK at mod_init yields it -- so a
                                        * &function cell gets a REAL bank byte
                                        * and an indirect call reads it.  K&R
                                        * A.7.4.2: "the result is a pointer to
                                        * the ... function referred to", which a
                                        * bare offset is not once a second bank
                                        * exists. */
        } else if (strcmp(argv[i], "-fno-safepoints") == 0) {
            g_emit_safepoints = 0;   /* P2': omit loop-top yield safepoints
                                      * (perf A/B; a compute-only leaf with no
                                      * loops that can spin unbounded) */
        } else if (strcmp(argv[i], "--libso") == 0) {
            g_libso = 1;               /* libc.so library mode */
        } else if (strcmp(argv[i], "--libso-name") == 0) {
            /* A library other than libc names its block cells
             * _<name>_blk_<member>, so each library has its own. */
            if (++i >= argc) usage();
            g_libso = 1;
            g_libso_name = argv[i];
        } else if (strcmp(argv[i], "--libso-inplace") == 0) {
            g_libso = 1;               /* implies --libso */
            g_libso_inplace = 1;       /* each block cell points at its own
                                        * template: one process's blocks live
                                        * in its own data segment */
        } else if (strcmp(argv[i], "--emit-blocks") == 0 && i + 1 < argc) {
            g_emit_blocks_path = argv[++i];
        } else if (strcmp(argv[i], "--core-list") == 0 && i + 1 < argc) {
            core_list_load(argv[++i]);
        } else if (strcmp(argv[i], "--pile-far-extern") == 0) {
            g_pile = 1;                /* implies --pile */
            g_pile_far_extern = 1;     /* extern calls go FGX2_FARCALL — a
                                        * library pile that can live outside
                                        * the libc segment (2026-07-17) */
        } else if (strcmp(argv[i], "--version") == 0) {
            printf("fcc %s\n", FCC_VERSION);
            return 0;
        } else if (strcmp(argv[i], "-MD") == 0) {
            /* Emit a Makefile/ninja depfile as a SIDE EFFECT of compiling
             * (GCC semantics: -MD compiles as normal, unlike -M which stops
             * after preprocessing).  Without this a build graph cannot see
             * header edges at all. */
            dep_out = 1;
        } else if (strcmp(argv[i], "-MF") == 0) {
            if (++i >= argc) usage();
            dep_path = argv[i];
            dep_out = 1;            /* -MF implies -MD, as in cc */
        } else if (strncmp(argv[i], "-I", 2) == 0) {
            /* Accept both spaced ("-I dir") and glued ("-Idir") forms. */
            const char *dir;
            if (argv[i][2] != '\0') {
                dir = argv[i] + 2;
            } else {
                if (++i >= argc) usage();
                dir = argv[i];
            }
            if (g_n_extra_inc_dirs >= 8)
                fprintf(stderr, "fcc: too many -I dirs\n"), exit(1);
            g_extra_inc_dirs[g_n_extra_inc_dirs++] = dir;
        } else if (strcmp(argv[i], "-include") == 0) {
            /* Force-include a header BEFORE the main TU (standard cc
             * behavior).  Delivery vehicle for prototypes into K&R port
             * sources that never #include the libc headers (elvis gets
             * `-include stdlib.h` so the WIDE malloc prototype precedes
             * config.h's `extern void *malloc();`).  Implemented as a
             * synthetic `#include "file"` line prepended to the source
             * buffer, so main-TU error line numbers shift by the number
             * of -include flags. */
            if (++i >= argc) usage();
            if (n_cli_includes >= 8)
                fprintf(stderr, "fcc: too many -include files\n"), exit(1);
            cli_includes[n_cli_includes++] = argv[i];
        } else if (strncmp(argv[i], "-D", 2) == 0) {
            /* Command-line macro: "-Dname" (body 1) or "-Dname=value".
             * Accept spaced ("-D name") and glued ("-Dname") forms.  Drives
             * config.h-style feature selection (the port build passes the
             * platform + feature flags this way; matches cc/gcc -D). */
            const char *def;
            if (argv[i][2] != '\0') {
                def = argv[i] + 2;
            } else {
                if (++i >= argc) usage();
                def = argv[i];
            }
            if (n_cli_defines >= 64)
                fprintf(stderr, "fcc: too many -D defines\n"), exit(1);
            cli_defines[n_cli_defines++] = def;
        } else if (argv[i][0] == '-') {
            usage();
        } else {
            if (g_input_path) usage();
            g_input_path = argv[i];
        }
    }
    if (!g_input_path) usage();
    if (g_libso && g_pile) {
        /* libc.so's banks are relocated when it loads, so every call is a
         * JSL; a pile's relocation-free call sequence has no place in it. */
        fprintf(stderr, "fcc: --libso and --pile are exclusive\n");
        exit(1);
    }
    /* Validate -MD/-o BEFORE compiling.  Checking this at emission time (after
     * the work is done) meant `-MD` with no -o compiled to stdout and only
     * then failed -- output already emitted, exit code 1.  A flag combination
     * that cannot possibly work should cost nothing to reject. */
    if (dep_out && !dep_path && !out_path) {
        fprintf(stderr, "fcc: -MD needs -o (or an explicit -MF <file>)\n");
        return 1;
    }
    if (!g_data_seg_path) {
        /* Derive <out>.data.s from -o (one-mode: data segment always
         * emitted).  Stdout output has nowhere to derive from. */
        static char derived[512];
        size_t n;
        if (!out_path) {
            fprintf(stderr, "fcc: -o or --data-segment required "
                            "(the data segment is always emitted)\n");
            return 1;
        }
        n = strlen(out_path);
        if (n > 2 && strcmp(out_path + n - 2, ".s") == 0)
            snprintf(derived, sizeof derived, "%.*s.data.s",
                     (int)(n - 2), out_path);
        else
            snprintf(derived, sizeof derived, "%s.data.s", out_path);
        g_data_seg_path = derived;
    }

    /* Derive system include directory from argv[0] = dirname(argv[0])/include.
     * Lets fcc find <stdio.h> etc. regardless of cwd. */
    {
        const char *exe = argv[0];
        const char *slash = NULL;
        for (const char *p = exe; *p; p++)
            if (*p == '/' || *p == '\\') slash = p;
        if (slash != NULL) {
            int dlen = (int)(slash - exe);
            if (dlen + (int)sizeof("/include") + 1 < (int)sizeof g_sys_inc_dir) {
                memcpy(g_sys_inc_dir, exe, (size_t)dlen);
                g_sys_inc_dir[dlen] = '\0';
                strcat(g_sys_inc_dir, "/include");
            }
        } else {
            strcpy(g_sys_inc_dir, "include");
        }
    }

    derive_tu_prefix(g_input_path);

    FILE *in = fopen(g_input_path, "r");
    if (!in) { perror(g_input_path); return 1; }

    /* fcc 2.0 Track 2: FCC_NO_REGALLOC=1 disables the IR regalloc pass —
     * bisection toggle isolating op-lifting byte-identity from the optimization. */
    if (getenv("FCC_NO_REGALLOC")) ir_set_opt(0);

    /* fcc 2.0 Track 1: buffer all emitted asm in memory via a memstream so
     * peephole_optimize() can rewrite it before it reaches the real output.
     * emit.c is unchanged — it still fprintf()s to g_out. */
    char  *asm_buf = NULL;
    size_t asm_len = 0;
    g_out = open_memstream(&asm_buf, &asm_len);
    if (!g_out) { perror("open_memstream"); return 1; }
    {
        g_data_out = fopen(g_data_seg_path, "w");
        if (!g_data_out) { perror(g_data_seg_path); return 1; }
        fprintf(g_data_out, ";---------------------------------------\n");
        fprintf(g_data_out, "; fcc 0.0 — data segment for %s\n", g_input_path);
        fprintf(g_data_out, ";---------------------------------------\n");
        fprintf(g_data_out, "                FGX2_MODE %d\n", FGX_MODE_CURRENT);
        g_n_datamac++;               /* P3-5 I3: MODE row counts in the trailer */
    }
    if (g_sigs_path) {
        own_defs_prepass(argc, argv);
        sigs_load(g_sigs_path);
    }
    if (g_commons_path) {
        g_commons_out = fopen(g_commons_path, "w");
        if (!g_commons_out) { perror(g_commons_path); return 1; }
        /* One record per non-extern global (see emit_globals_section):
         *   TENT <name> <size> <reloc>   -- a tentative def (redirected here)
         *   DEF  <name>                  -- a real (initialized) def in .data.s
         * gen_commons.py merges TENTs across TUs (max size), dropping any name
         * that has a DEF anywhere (K&R A.10.2: a real definition wins). */
        fprintf(g_commons_out, "# fcc commons sidecar for %s\n", g_input_path);
    }

    /* Slurp input into memory, with any -include files as synthetic
     * `#include "file"` lines PREPENDED (main-TU line numbers shift by
     * n_cli_includes — documented at the flag). */
    if (fseek(in, 0, SEEK_END) != 0) { perror(g_input_path); return 1; }
    long endpos = ftell(in);
    if (endpos < 0) { perror(g_input_path); return 1; }
    rewind(in);
    size_t prelude_len = 0;
    for (int ii = 0; ii < n_cli_includes; ii++)
        prelude_len += strlen(cli_includes[ii]) + sizeof("#include \"\"\n");
    char *buf = malloc((size_t)endpos + prelude_len + 1);
    if (!buf) { fprintf(stderr, "out of memory\n"); return 1; }
    {
        char *w = buf;
        for (int ii = 0; ii < n_cli_includes; ii++)
            w += sprintf(w, "#include <%s>\n", cli_includes[ii]);
        if (fread(w, 1, (size_t)endpos, in) != (size_t)endpos) {
            fprintf(stderr, "short read on %s\n", g_input_path);
            return 1;
        }
        w[endpos] = '\0';
        endpos += (long)(w - buf);
    }
    endpos = splice_line_continuations(buf, (int)endpos);
    lex_set_source(buf, (int)endpos, g_input_path);

    /* Pre-define __FGX__ so source files can branch on the target via
     * #ifdef __FGX__.  Useful for source that needs to keep a Mac-gcc
     * build path too. */
    pp_define_text("__FGX__", 7, "1");

    /* -D command-line defines: object-like macros `name` (body "1") or
     * `name=value` (body "value").  Appended after __FGX__ so the port build
     * can select a config.h profile (e.g. -DUNIXV=1 -DTINYSTACK=1). */
    for (int di = 0; di < n_cli_defines; di++) {
        const char *d   = cli_defines[di];
        const char *eq  = strchr(d, '=');
        int         nl  = eq ? (int)(eq - d) : (int)strlen(d);
        const char *bod = eq ? eq + 1 : "1";
        if (nl <= 0 || nl >= 32) {
            fprintf(stderr, "fcc: bad -D name '%s'\n", d);
            return 1;
        }
        pp_define_text(d, nl, bod);   /* grows g_pp_macros dynamically */
    }

    lex_tokenize_all();  /* Increment 1: whole-TU token vector (pp runs here) */
    prescan_static_funcs();  /* register file-scope static fns for forward-ref label mangling */
    next_tok();          /* prime lookahead */
    parse_program();

    /* Emit the FGX1 stack-pages hint so the loader sizes the bank-0 user
     * stack to the program's largest frame instead of the 256-byte default.
     * pages = ceil((max_frame + 256) / 256) = (frame's own pages) + 1 page of
     * headroom for the call chain above it + the syscall/interrupt frame,
     * clamped to [1, 16] (TASK_STACK_MAX_PAGES = 4 KB).  A program whose
     * largest single frame exceeds ~256 bytes (e.g. a big local array) would
     * otherwise overrun the default 1-page stack and crash.  The link file's
     * FGX1 header references this symbol at offset 14. */
    {
        /* pages = ceil((max_frame + 128) / 256): enough pages for the largest
         * single frame plus 128 bytes of headroom for the call chain above it
         * (return addresses + the crt0 argv frame + a syscall/IRQ frame).  A
         * program whose largest frame is <=128 bytes keeps the default 1 page;
         * a big local array (e.g. g53's 300-byte buf) grows the stack so it
         * doesn't overrun the 256-byte default and crash.  Clamp to
         * [1,16] = TASK_STACK_MAX_PAGES (4 KB). */
        int sp = (g_max_framesize + 128 + 255) / 256;
        if (sp > 16) sp = 16;
        if (sp <= 1) sp = 0;       /* 0 = loader default (1 page); keeps the
                                    * header byte $00 so small programs' goldens
                                    * don't churn now that the link file
                                    * references this symbol. */
        /* fcc_stack_pages (FGX1 single-bank header field) retired with the
         * mode collapse: output is always multi-segment FGX2-shaped. */
        (void)sp;
    }

    /* T2-0 (Part-V self-host memory measurement): FCC_MEM_STATS=1 prints
     * the front-end's peak memory shape to stderr — token vector, intern
     * arena, per-function AST peak.  The self-host BUDGET decision reads
     * these numbers off the largest elvis TU (no budget exists yet). */
    if (getenv("FCC_MEM_STATS")) {
        if (g_n_ast > g_ast_peak) g_ast_peak = g_n_ast;  /* last fn's tree */
        fprintf(stderr,
                "fcc-mem: toks=%d (%luB) intern=%dB idents=%d mtoks=%dB ast_peak=%d/%d (%luB) %s\n",
                g_n_toks, (unsigned long)((size_t)g_n_toks * sizeof(Tok)),
                g_intern_total, g_ident_unique, g_pp_body_tok_bytes,
                g_ast_peak, MAX_AST_NODES,
                (unsigned long)((size_t)g_ast_peak * sizeof(g_ast[0])),
                g_input_path);
    }

    fclose(g_out);               /* flush emitted asm into asm_buf */
    g_out = NULL;

    /* P3-5 I3: data-segment reloc-count trailer.  The data stream has no
     * peephole, so the funnel counter (g_n_datamac: MODE + LONG_PTR +
     * data-side EXPORT rows) is exact. */
    fprintf(g_data_out, "                FGX2_RELOC_COUNT %d\n", g_n_datamac);
    if (g_sections)
        data_sections(g_data_seg_path);
    if (g_commons_out) { fclose(g_commons_out); g_commons_out = NULL; }
    if (g_emit_sigs_path) sigs_emit(g_emit_sigs_path);
    if (g_emit_blocks_path) blocks_emit(g_emit_blocks_path);
    if (g_emit_defs_path) defs_emit(g_emit_defs_path);

    {
        /* FCC_NO_PEEPHOLE=1: emit the raw pre-peephole text (debugging aid —
         * pairs with FCC_NO_REGALLOC for the IR pass). */
        char *optimized = getenv("FCC_NO_PEEPHOLE")
                              ? strdup(asm_buf) : peephole_optimize(asm_buf);
        FILE *dst;
        if (!optimized) { fprintf(stderr, "fcc: peephole OOM\n"); free(asm_buf); return 1; }
        free(asm_buf);
        dst = out_path ? fopen(out_path, "w") : stdout;
        if (!dst) { perror(out_path ? out_path : "stdout"); free(optimized); return 1; }
        /* P3-5 I2: contract stamp first — written directly to dst (not via
         * g_out) so the peephole never sees it and it is ALWAYS line 1. */
        fprintf(dst, "                FGX2_MODE %d\n", FGX_MODE_CURRENT);
        fputs(optimized, dst);
        /* P3-5 I3: reloc-count trailer — declared count = rows in the final
         * text (+1 for the MODE line above, which the scan can't see).
         * fgx_ld recounts per source file and fails the link on mismatch,
         * closing the silent-skip listing-row hole (g_op_table-$0000 class). */
        fprintf(dst, "                FGX2_RELOC_COUNT %d\n",
                count_fgx2_rows(optimized) + 1);
        /* THE fltused MARKER.  2.11BSD, libc/pdp/stdio/fltpr.s: "If the
         * compiler notices any floating point type stuff going on in a C
         * object, it automatically outputs a reference to the symbol
         * "fltused" to force loading of this portion of the doprnt support.
         * If fltused is not defined the references ... will be satisfied by
         * ffltpr.s (fake floating print)."  Here a static link (fgx_static)
         * finds the name and keeps libc's fltpr for printf's %e/%f/%g;
         * otherwise it links lib/ffltpr.c, which prints `?' as ffltpr.s does.
         *
         * NARROWER THAN BSD'S TRIGGER, and exact: a float reaches printf
         * only as an argument no parameter is declared for, and every such
         * call is in some translation unit of the program, so marking those
         * units selects fltpr for every program that can print a float.
         * Marking all floating point would load it into tcsh, whose floats
         * are `limit' arithmetic and never printed, and tcsh's libc bank has
         * no room for it.  A Merlin variable,
         * because each translation unit of a program may define it and a
         * variable can be set more than once.  Not in a libc pile: libc's
         * own float code is not a program asking for a float printer. */
        if (g_fltused && !g_pile)
            fprintf(dst, "]__lc_fltused   =       1\n");
        if (out_path) fclose(dst);
        free(optimized);
    }

    /* --- -MD/-MF: emit the depfile ------------------------------------
     * Written only on a SUCCESSFUL compile, and only here at the end: a
     * depfile produced alongside a failed compile would let the build system
     * mark the target up to date against an output that was never written.
     *
     * Format is the make/ninja convention -- `target: prereq...`, one target,
     * prerequisites space-separated with `\` continuations.  ninja reads this
     * with `deps = gcc` + `depfile = $out.d`.
     *
     * The target must be the -o path exactly as the build system spells it,
     * or ninja treats the depfile as describing a different edge and silently
     * ignores it. */
    if (dep_out) {
        char derived[512];
        const char *dp = dep_path;
        if (!dp) {
            /* -MD without -MF: <output>.d, as cc does.  out_path is known
             * non-NULL here -- validated up front, before any compilation. */
            snprintf(derived, sizeof derived, "%s.d", out_path);
            dp = derived;
        }
        FILE *df = fopen(dp, "w");
        if (!df) {
            perror(dp);
            free(buf); fclose(in); return 1;
        }
        fprintf(df, "%s:", out_path ? out_path : "-");
        /* The TU itself is a prerequisite and is read by main(), not through
         * pp_read_file, so it is never in the recorded list. */
        fprintf(df, " \\\n  %s", g_input_path);
        for (int d = 0; d < pp_dep_count(); d++)
            fprintf(df, " \\\n  %s", pp_dep_get(d));
        fputc('\n', df);
        fclose(df);
    }

    free(buf);
    fclose(in);
    return 0;
}
