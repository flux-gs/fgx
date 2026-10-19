/* fas — FGX 65816 assembler.
 *
 * Mac-hosted v0; byte-eq target = Merlin32.
 *
 * M0: argv driver + file I/O + DFB-only echo.
 * M1: symbol table, expression evaluator, two-pass driver,
 *     ORG/EQU/DFB/DA/DS/HEX/ASC directives, label collection.
 * M2: opcode/mode table + arithmetic core; MX state tracking.
 * M3: branches (BEQ/BNE/BCC/BCS/BMI/BPL/BVC/BRA/BRL) PC-relative.
 * M4: JSR/JSL/JMP/JMP(abs)/RTL/PEA/MVN.
 * M5: transfer/stack/inc-dec/bare-A shifts + SEP/REP/COP.
 * M6: indirect addressing — (dp), [dp], (dp),Y, [dp],Y, (dp,X).
 * M7: indexed addressing (abs,X/abs,Y/dp,X/dp,Y/long,X), force-abs
 *     colon `LDA:`, long suffix LDAL/STAL family, LDX/LDY/STX/STY/
 *     CPX/CPY, BIT, memory-form INC/DEC/ASL/LSR/ROL/ROR.
 * M8: PUT/ASM file inclusion, ENT symbol export, @local labels
 *     scoped to enclosing global label.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*-------------------------------------------------------------------
 * Source state.
 *-----------------------------------------------------------------*/

static const char *g_src_path;
static char       *g_src;
static int         g_src_len;
static int         g_pos;
static int         g_line;
static int         g_col;

static const char *g_out_path;
static FILE       *g_out;

static int         g_pass;       /* 1 = layout, 2 = emit */
static int         g_pc;         /* current program counter (low 16 bits) */
static int         g_pc_bank;    /* bank byte of g_pc — side channel.
                                  * fcc int is 16-bit and full 24-bit
                                  * long math everywhere blew the 64K
                                  * single-bank limit. */
static int         g_last_bank;  /* bank byte from the last expression
                                  * (parse_int_lit / sym lookup).  Read
                                  * by the `^` operator. */

/* MX register-size state.  1 = 8-bit, 0 = 16-bit.  Native-mode entry
 * starts at MX %11 (both 8-bit) like emulation mode; REP/SEP + MX
 * directives flip it. */
static int         g_mx_m = 1;
static int         g_mx_x = 1;

/* Cleared in eval before each expression; eval_factor sets to 0 if it
 * touched an as-yet-undefined symbol.  Used by the dp/abs sizer to
 * pick conservatively. */
static int         g_eval_all_defined;

/* Set to 1 before each expression; eval_factor sets to 0 the moment it
 * sees ANY symbol reference (identifier, @local, or `*`/current-PC)
 * regardless of whether the symbol is yet defined.  Used by the dp/abs
 * sizer so we ONLY fold to direct-page when the source operand was a
 * pure literal (`STA $E8`) — symbol-resolved values that happen to fit
 * DP stay at ABS width.  FGX-shaped policy: DP is a scarce shared
 * resource (libc + fcc + args use specific slots, plus firmware/Toolbox
 * scratch); a STA against a symbol must hit the symbol's actual address,
 * not a DP slot that happens to share the low byte.  Merlin32-divergent
 * by design — see feedback_fcc_sweep_on_fas_gap.md. */
static int         g_eval_is_literal_only;

/* Most-recent global (column-1, non-@) label seen by parse_line.  Used
 * to mangle @local labels into "Global@local" symbol names so locals
 * in different functions don't collide. */
/* ONE symbol-name ceiling, used by the symbol table AND every parse buffer
 * that feeds it.  These used to disagree -- Symbol.name was 48, the parse
 * buffers 64, and the enclosing-global scope name only 32 -- so a name could
 * survive parsing and then be truncated on the way into the table, or into the
 * @local scope prefix, in both cases silently.  Two symbols sharing a prefix
 * then collapsed into one and the visible symptom was "layout did not
 * converge", which names nothing real.  Merlin32 has no length limit at all
 * (measured: labels differing only at character 65 resolve distinctly), so
 * this ceiling is ours alone.  Sized so nothing fcc emits can approach it;
 * a fixed array costs host memory only, self-hosting being deferred. */
#ifdef __FGX__
/* Self-hosted: MAX_SYMBOLS(560) * SYM_NAME_LEN must fit the data bank, and
 * 560 * 128 is 70 KB -- over the 64 KB ceiling, which is how this announced
 * itself (a build failure in fas_fgx.data.s, not a runtime surprise).  The
 * shorter ceiling is SAFE rather than merely smaller, because exceeding it is
 * now a diagnostic instead of a silent truncation; the self-hosted assembler
 * simply refuses names the host one accepts.  Interning is the fix when
 * self-hosting is picked back up. */
#define SYM_NAME_LEN 48
#else
#define SYM_NAME_LEN 128    /* must match the [N] in Symbol.name below */
#endif
static char        g_cur_global[SYM_NAME_LEN];

#ifndef __FGX__
/* --- PUT/ASM dependency tracking (-MD/-MF), HOST BUILD ONLY --------------
 * fas assembles a PUT closure -- one .link.s pulls in the whole libc/runtime
 * pile -- so without this a build graph sees a single source file and misses
 * every included .s.  That is the assembler-side half of the same blind spot
 * fcc's -MD closes; build.sh worked around it with a hand-written deps_of()
 * PUT scanner, which is exactly the sort of second, drifting model of the
 * graph this replaces.
 *
 * Excluded from the self-hosted FGX build (like --dump-symbols): the on-target
 * assembler has no build system to feed, and fas is tight against the 64 KB
 * code-bank cliff. */
#define DEP_MAX 512
static const char *g_deps[DEP_MAX];
static int         g_n_deps;

static void
dep_add(const char *path)
{
    int i;
    for (i = 0; i < g_n_deps; i = i + 1)
        if (strcmp(g_deps[i], path) == 0) return;   /* already recorded */
    if (g_n_deps >= DEP_MAX) return;                /* silently cap: a missing
                                                     * edge degrades the graph,
                                                     * a die() stops the build */
    g_deps[g_n_deps] = strdup(path);
    g_n_deps = g_n_deps + 1;
}
#endif

/* Input-file stack for PUT/ASM.  Push current source state, swap to
 * included file, parse to EOF, pop back.  Depth-16 limit mirrors
 * Merlin32.  Path/src live in PARALLEL top-level long-ptr arrays
 * rather than as struct fields, because fcc's in-struct char* is
 * 2 bytes (bank recovered via PHK at deref) — that's fine when
 * caller and pointer-target live in the same bank (single-bank
 * FGX1), but in multi-bank FGX2 args_input lives in DBR (seg1)
 * while in-struct deref uses PHK (PB, seg0) → garbage on pop. */
#define INPUT_STACK_MAX 16

typedef struct {
    int         src_len;
    int         pos;
    int         line;
    int         col;
} InputFrame;

static InputFrame   g_input_stack[INPUT_STACK_MAX];
static const char  *g_input_paths[INPUT_STACK_MAX];
static       char  *g_input_srcs[INPUT_STACK_MAX];
static int          g_input_depth;

static void
die(int line, int col, const char *msg)
{
    fprintf(stderr, "%s:%d:%d: error: %s\n", g_src_path, line, col, msg);
    exit(1);
}

#ifdef __FGX__
/* Per-byte fputc to /root/HI silently writes zeros — chasing the
 * root cause has been frustrating.  Workaround: buffer all output in
 * own-bank static and fwrite at end of pass 2.  fwrite's multi-byte
 * SYS_WRITE path is known to work (fprintf/faslog use it).
 *
 * Slab grown to 8 KB with the multi-bank FGX2 build (seg1 headroom). */
#define FAS_OUT_BUF_MAX 8192
static char *fas_out_buf;       /* malloc'd in main — a static slab kept
                                 * fas's FGX seg1 riding the 64KB cliff
                                 * (H1: the pile's dirent cells tipped it) */
static int  fas_out_pos;
#endif

static void
emit_byte(unsigned b)
{
#ifdef __FGX__
    if (g_pass == 2 && fas_out_pos < FAS_OUT_BUF_MAX) {
        fas_out_buf[fas_out_pos] = (char)(b & 0xFF);
        fas_out_pos = fas_out_pos + 1;
    }
#else
    if (g_pass == 2) fputc((int)(b & 0xFF), g_out);
#endif
    g_pc++;
}

/*-------------------------------------------------------------------
 * Symbol table.
 *-----------------------------------------------------------------*/

/* MAX_SYMBOLS sizes the static Symbol g_syms[] table.  Each Symbol
 * is char[48] name + 4× int (16-bit on FGX) = 56 B/entry.  Mac-host
 * uses 1024; FGX is capped at 560 by the 64KB seg1 ceiling (g_syms
 * shares seg1 with layout_prev_values, dpl_resolved, fas_src_buf,
 * fas_out_buf, g_op_table, libc_data, args_data, fcc_runtime_data —
 * and, since the P3-2.6 one-mode collapse, the TU string pool, which
 * moved from the code segment; 600 then overflowed by ~1.6KB).
 *
 * The previous 192 cap was a workaround for a layout-sensitive
 * heisenbug in fcc_runtime.s's scratch-global placement: multi-bank
 * DBR routing corrupted seg1 at offsets that happened to land inside
 * fas_src_buf for MAX_SYMBOLS in 243..257.  Fixed 2026-05-23 by
 * splitting fcc_runtime_data.s into seg1. */
#ifdef __FGX__
#define MAX_SYMBOLS 560
#else
#define MAX_SYMBOLS 1024
#endif

typedef struct {
    char name[SYM_NAME_LEN];   /* widened from 32 to fit Global@local mangling */
    int  value;                /* 16-bit only on FGX (fcc structs lack long).
                                * The 8-bit BANK byte is in g_syms_bank[i]. */
    int  defined;
    int  line;
    int  exported;      /* ENT marker — informational in v0 */
} Symbol;

static Symbol g_syms[MAX_SYMBOLS];
static int    g_n_syms;
/* Parallel "this symbol was defined via EQU" array.  EQU'd symbols are
 * compile-time constants (named literals — typically DP slots like
 * `_fcc_ptr EQU $E8`); they MAY participate in dp/abs folding when their
 * value < 256.  Label symbols (defined by DS / DA / DW or as code labels)
 * are runtime addresses and must NOT fold to DP — `STA label` where label
 * happens to resolve to a value < 256 would route to the wrong bank /
 * scratch slot.  See FGX DP-fold policy notes. */
static char   g_syms_is_equ[MAX_SYMBOLS];
/* Parallel bank-byte array.  fcc can't put `long` in a struct field so
 * Symbol.value is 16-bit; the bank byte lives here and is recombined
 * at lookup time to recover the 24-bit address. */
static char   g_syms_bank[MAX_SYMBOLS];

#ifdef __FGX__
/* Closed-loop diag: log markers to /root/faslog so the test harness
 * can read them back after MAME exits.  Open-append-close per write
 * so partial progress survives a crash mid-statement.  Defined early
 * (fcc parses top-down, no forward decls). */
static void
faslog(const char *msg, int a, int b)
{
    FILE *f;
    f = fopen("/root/faslog", "ab");
    if (f) { fprintf(f, "%s %d %d\r", msg, a, b); fclose(f); }
}
#endif

static int
syms_lookup(const char *name)
{
    for (int i = 0; i < g_n_syms; i++)
        if (strcmp(g_syms[i].name, name) == 0) return i;
    return -1;
}

static int
syms_define(const char *name, int value, int bank, int line)
{
    int i;
    i = syms_lookup(name);
    if (i < 0) {
        if (g_n_syms >= MAX_SYMBOLS) die(line, 1, "too many symbols");
        i = g_n_syms++;
        strncpy(g_syms[i].name, name, SYM_NAME_LEN - 1);
        g_syms[i].name[SYM_NAME_LEN - 1] = 0;
    }
    g_syms[i].value = value;
    g_syms_bank[i]  = (char)(bank & 0xFF);
    g_syms[i].defined = 1;
    g_syms[i].line = line;
    return i;
}

/*-------------------------------------------------------------------
 * Lex helpers.
 *-----------------------------------------------------------------*/

static int
at_eol(void)
{
    /* Decls upfront — fcc only emits a stack frame if the first
     * statement after `{` is a decl.  Mid-block decls silently
     * corrupt the return stack. */
    char c;
    if (g_pos >= g_src_len) return 1;
    c = g_src[g_pos];
    /* Accept both LF (Unix host) and CR (ProDOS).  Either terminates
     * a logical line. */
    return c == '\n' || c == '\r' || c == ';';
}

static void
skip_ws(void)
{
    while (g_pos < g_src_len &&
           (g_src[g_pos] == ' ' || g_src[g_pos] == '\t')) {
        g_pos++; g_col++;
    }
}

static void
skip_to_eol(void)
{
    /* Skip everything until LF or CR. */
    while (g_pos < g_src_len &&
           g_src[g_pos] != '\n' && g_src[g_pos] != '\r') {
        g_pos++; g_col++;
    }
    /* Consume the EOL.  Treat CR-LF as one logical line break. */
    if (g_pos < g_src_len && g_src[g_pos] == '\r') {
        g_pos++; g_col++;
    }
    if (g_pos < g_src_len && g_src[g_pos] == '\n') {
        g_pos++; g_col++;
    }
    g_line++;
    g_col = 1;
}

static int
is_ident_start(char c)
{
    return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '_';
}

static int
is_ident_cont(char c)
{
    return is_ident_start(c) || (c >= '0' && c <= '9');
}

static int
parse_ident(char *buf, int cap)
{
    int n = 0;
    while (g_pos < g_src_len && n < cap - 1 && is_ident_cont(g_src[g_pos])) {
        buf[n++] = g_src[g_pos];
        g_pos++; g_col++;
    }
    buf[n] = 0;
    if (g_pos < g_src_len && is_ident_cont(g_src[g_pos]))
        die(g_line, g_col, "identifier too long");
    return n;
}

/* Parse either a plain identifier or an @local label.  @local names
 * are mangled with the most recent global label so the canonical
 * symbol-table entry is "Global@local", scoping the local to its
 * enclosing global. */
static int
parse_symname(char *buf, int cap)
{
    if (g_pos < g_src_len && g_src[g_pos] == '@') {
        if (g_cur_global[0] == 0)
            die(g_line, g_col, "@local without enclosing global label");
        int gl = (int)strlen(g_cur_global);
        if (gl + 2 >= cap) die(g_line, g_col, "symbol name too long");
        memcpy(buf, g_cur_global, (size_t)gl);
        buf[gl] = '@';
        g_pos++; g_col++;
        int n = gl + 1;
        while (g_pos < g_src_len && n < cap - 1 && is_ident_cont(g_src[g_pos])) {
            buf[n++] = g_src[g_pos];
            g_pos++; g_col++;
        }
        buf[n] = 0;
        return n;
    }
    return parse_ident(buf, cap);
}

static int
parse_int_lit(void)
{
    /* Returns the LOW 16 bits.  The bank byte (bits 16-23 of the
     * parsed value) is stashed in g_last_bank for `^` to read.
     * Avoids long math which on fcc blows the 64K single-bank
     * binary budget. */
    int v    = 0;
    int bank = 0;     /* bits 16-23 of the parsed value */
    if (g_pos < g_src_len && g_src[g_pos] == '$') {
        g_pos++; g_col++;
        while (g_pos < g_src_len) {
            char c = g_src[g_pos];
            int  d;
            if (c >= '0' && c <= '9')      d = c - '0';
            else if (c >= 'A' && c <= 'F') d = c - 'A' + 10;
            else if (c >= 'a' && c <= 'f') d = c - 'a' + 10;
            else break;
            /* Manual 24-bit accumulate: v is low 16, bank is the
             * next 8.  Each iteration shifts the 24-bit value left
             * by 4 (one hex digit), carrying bits 12-15 of v into
             * bits 0-3 of bank. */
            int carry = (v >> 12) & 0xF;
            bank = ((bank << 4) | carry) & 0xFF;
            v    = ((v    << 4) | d    ) & 0xFFFF;
            g_pos++; g_col++;
        }
        g_last_bank = bank;
        return v;
    }
    if (g_pos < g_src_len && g_src[g_pos] == '\'') {
        /* Character literal: 'A' = 0x41 (low ASCII, no high bit). */
        g_pos++; g_col++;
        if (g_pos >= g_src_len)
            die(g_line, g_col, "unterminated char literal");
        v = (unsigned char)g_src[g_pos];
        g_pos++; g_col++;
        if (g_pos < g_src_len && g_src[g_pos] == '\'') {
            g_pos++; g_col++;
        }
        g_last_bank = 0;
        return v;
    }
    while (g_pos < g_src_len && g_src[g_pos] >= '0' && g_src[g_pos] <= '9') {
        v = v * 10 + (g_src[g_pos] - '0');
        g_pos++; g_col++;
    }
    g_last_bank = 0;
    return v;
}

/*-------------------------------------------------------------------
 * Expression evaluator.
 *
 * Merlin-style: left-to-right, no operator precedence.
 *     factor ::= int-lit | char-lit | ident | '*'
 *              | '<' factor | '>' factor | '^' factor | '-' factor
 *     expr   ::= factor (('+'|'-'|'*') factor)*
 *
 * In pass 1 a forward reference to an undefined symbol returns 0
 * (size estimate).  Pass 2 dies on undefined.
 *-----------------------------------------------------------------*/

static int eval_expr(void);

static int
eval_factor(void)
{
    skip_ws();
    if (g_pos >= g_src_len) {
        die(g_line, g_col, "expected expression");
    }
    char c = g_src[g_pos];
    if (c == '<') { g_pos++; g_col++; return eval_factor() & 0xFF; }
    if (c == '>') { g_pos++; g_col++; return (eval_factor() >> 8) & 0xFF; }
    /* `^` returns the bank byte from g_last_bank, which parse_int_lit
     * and the symbol-lookup path both write.  This sidesteps fcc's
     * 16-bit int (the obvious `(eval_factor() >> 16) & 0xFF` would
     * truncate to 0 because the operand can't hold the 24-bit value
     * to shift from). */
    if (c == '^') {
        g_pos++; g_col++;
        eval_factor();          /* consume the operand */
        return g_last_bank & 0xFF;
    }
    if (c == '-') { g_pos++; g_col++; return -eval_factor(); }
    if (c == '*') {
        g_pos++; g_col++;
        g_last_bank = g_pc_bank;
        g_eval_is_literal_only = 0;     /* PC is symbolic, not a literal */
        return g_pc;
    }
    if (c == '$' || c == '\'' || (c >= '0' && c <= '9'))
        return parse_int_lit();
    if (is_ident_start(c) || c == '@') {
        char name[SYM_NAME_LEN];
        parse_symname(name, sizeof name);
        int i = syms_lookup(name);
        if (i >= 0 && g_syms[i].defined) {
            /* EQU'd symbols (named literals) preserve fold-eligibility;
             * label symbols (runtime addresses) disqualify the operand
             * from DP folding regardless of resolved value. */
            if (!g_syms_is_equ[i])
                g_eval_is_literal_only = 0;
            g_last_bank = (int)g_syms_bank[i] & 0xFF;
            return g_syms[i].value;
        }
        /* Undefined or forward-ref: can't know if it's EQU yet.  Be
         * conservative — disqualify from fold (matches old behavior for
         * forward refs). */
        g_eval_is_literal_only = 0;
        if (g_pass == 2) die(g_line, g_col, "undefined symbol");
        g_eval_all_defined = 0;
        g_last_bank = 0;
        return 0;
    }
    die(g_line, g_col, "unexpected token in expression");
    return 0;
}

static int
eval_expr(void)
{
    int acc = eval_factor();
    for (;;) {
        skip_ws();
        if (g_pos >= g_src_len) break;
        char c = g_src[g_pos];
        if (c == '+') { g_pos++; g_col++; acc = acc + eval_factor(); }
        else if (c == '-') { g_pos++; g_col++; acc = acc - eval_factor(); }
        else if (c == '*') { g_pos++; g_col++; acc = acc * eval_factor(); }
        else break;
    }
    return acc;
}

/*-------------------------------------------------------------------
 * Directive handlers.
 *
 * Called after the directive mnemonic + whitespace; expression-parsing
 * helpers consume to end-of-line.
 *-----------------------------------------------------------------*/

static void
parse_two_hex(int *out)
{
    int v = 0;
    int n = 0;
    while (g_pos < g_src_len && n < 2) {
        char c = g_src[g_pos];
        int  d;
        if (c >= '0' && c <= '9')      d = c - '0';
        else if (c >= 'A' && c <= 'F') d = c - 'A' + 10;
        else if (c >= 'a' && c <= 'f') d = c - 'a' + 10;
        else break;
        v = v * 16 + d;
        n++;
        g_pos++; g_col++;
    }
    if (n == 0) die(g_line, g_col, "HEX needs two hex digits per byte");
    *out = v;
}

static void
do_org(void)
{
    g_pc      = eval_expr();
    g_pc_bank = g_last_bank;
}

static void
do_equ(const char *label)
{
    if (label[0] == 0) die(g_line, g_col, "EQU without label");
    int v = eval_expr();
    /* Re-define: the label was already provisionally defined to PC
     * in handle_label; EQU overrides with the expression value.  In
     * pass 1 the prior define call has already inserted the symbol;
     * just overwrite. */
    int i = syms_lookup(label);
    if (i < 0) {
        i = syms_define(label, v, g_last_bank, g_line);
    } else {
        g_syms[i].value   = v;
        g_syms_bank[i]    = (char)(g_last_bank & 0xFF);
        g_syms[i].defined = 1;
    }
    /* Mark as EQU so the dp/abs sizer treats this symbol as a named
     * constant (eligible for fold if value < 256), matching Merlin's
     * behavior for `_fcc_ptr EQU $E8`-style DP-slot declarations. */
    if (i >= 0) g_syms_is_equ[i] = 1;
}

static void
do_dfb(void)
{
    for (;;) {
        int v = eval_expr();
        emit_byte(v & 0xFF);
        skip_ws();
        if (g_pos < g_src_len && g_src[g_pos] == ',') {
            g_pos++; g_col++;
            skip_ws();
            continue;
        }
        break;
    }
}

static void
do_da(void)
{
    for (;;) {
        int v = eval_expr();
        emit_byte(v & 0xFF);
        emit_byte((v >> 8) & 0xFF);
        skip_ws();
        if (g_pos < g_src_len && g_src[g_pos] == ',') {
            g_pos++; g_col++;
            skip_ws();
            continue;
        }
        break;
    }
}

static void
do_ds(void)
{
    int n = eval_expr();
    int fill = 0;
    skip_ws();
    if (g_pos < g_src_len && g_src[g_pos] == ',') {
        g_pos++; g_col++;
        fill = eval_expr() & 0xFF;
    }
    for (int i = 0; i < n; i++) emit_byte(fill);
}

static void
do_hex(void)
{
    skip_ws();
    while (!at_eol()) {
        int v;
        parse_two_hex(&v);
        emit_byte(v);
        skip_ws();
        if (g_pos < g_src_len && g_src[g_pos] == ',') {
            g_pos++; g_col++;
            skip_ws();
        }
    }
}

static void
do_asc(void)
{
    /* ASC accepts a comma-separated list of items.  Each item is
     * either:
     *   - a quoted string ('...' = low-ASCII, "..." = high-ASCII)
     *   - a bare expression (single byte, no high-bit modification)
     * Mixed forms (e.g. `ASC $1B,'[H',$00`) are routine in real
     * Merlin sources. */
    for (;;) {
        skip_ws();
        if (g_pos >= g_src_len) die(g_line, g_col, "ASC needs content");
        char c = g_src[g_pos];
        if (c == '\'' || c == '"') {
            int high_bit = (c == '"') ? 0x80 : 0x00;
            g_pos++; g_col++;
            while (g_pos < g_src_len && g_src[g_pos] != c) {
                emit_byte((unsigned char)g_src[g_pos] | high_bit);
                g_pos++; g_col++;
            }
            if (g_pos < g_src_len) { g_pos++; g_col++; }
        } else if (c == ';' || c == '\n' || c == '\r') {
            break;
        } else {
            int v = eval_expr();
            emit_byte(v & 0xFF);
        }
        skip_ws();
        if (g_pos < g_src_len && g_src[g_pos] == ',') {
            g_pos++; g_col++;
            continue;
        }
        break;
    }
}

/* File-scope so the local frame for do_put_load stays under the
 * 65816's 8-bit stack-relative displacement (256 B).  Non-reentrant
 * but PUT/ASM is sequential anyway. */
static char dpl_resolved[512];

/* (The FGX-only fas_src_buf static slab is gone — its reason, non-bank-
 * aware reads, was fixed when c_fread went bulk-DBR; both host and FGX
 * now malloc the source buffer, and fas's seg1 stops riding the 64KB
 * data-bank cliff.) */

/* Push current input frame; load `path` (resolved relative to the
 * current frame's directory) onto g_src; parse to EOF; pop. */
static void
do_put_load(const char *raw_name)
{
    if (g_input_depth >= INPUT_STACK_MAX)
        die(g_line, g_col, "PUT/ASM nesting too deep");

    /* Resolved path lives at file scope (dpl_resolved); see comment
     * there.  Alias here for readability.  Note: capacity check uses
     * the file-scope array's known size since `sizeof resolved` on the
     * alias yields the pointer size, not the array size. */
    char *resolved = dpl_resolved;
#define DPL_CAP (int)(sizeof dpl_resolved)
    const char *cur = g_src_path;
    int prefix_len = 0;
    {
        int k;
        for (k = 0; cur[k]; k = k + 1) {
            if (cur[k] == '/') prefix_len = k + 1;
        }
    }
    int rn_len = (int)strlen(raw_name);
    if (prefix_len + rn_len + 4 >= DPL_CAP)
        die(g_line, g_col, "PUT path too long");
    memcpy(resolved, cur, (size_t)prefix_len);
    memcpy(resolved + prefix_len, raw_name, (size_t)rn_len);
    resolved[prefix_len + rn_len] = 0;

    /* Merlin appends `.S` automatically.  Try literal first, then .S
     * suffix, then .s. */
    FILE *fp = fopen(resolved, "rb");
    if (!fp) {
        strcat(resolved, ".S");
        fp = fopen(resolved, "rb");
    }
    if (!fp) {
        resolved[prefix_len + rn_len] = 0;
        strcat(resolved, ".s");
        fp = fopen(resolved, "rb");
    }
    if (!fp) die(g_line, g_col, "PUT/ASM: cannot open included file");

#ifndef __FGX__
    /* Record the RESOLVED path -- the one actually opened after the literal /
     * .S / .s probing above, not the raw PUT operand, which usually carries no
     * extension and would not name a real file for the build system. */
    dep_add(resolved);
#endif

    fseek(fp, 0, SEEK_END);
    long len = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    char *buf = (char *)malloc((size_t)len + 1);
    if (!buf) { fclose(fp); die(g_line, g_col, "PUT: out of memory"); }
    fread(buf, 1, (size_t)len, fp);
    buf[len] = 0;
    fclose(fp);

    /* Push current state. */
    g_input_paths[g_input_depth] = g_src_path;
    g_input_srcs[g_input_depth]  = g_src;
    g_input_stack[g_input_depth].src_len = g_src_len;
    g_input_stack[g_input_depth].pos     = g_pos;
    g_input_stack[g_input_depth].line    = g_line;
    g_input_stack[g_input_depth].col     = g_col;
    g_input_depth++;

    /* Swap to included source. */
    char *resolved_dup = (char *)malloc((size_t)strlen(resolved) + 1);
    strcpy(resolved_dup, resolved);
    g_src_path = resolved_dup;
    g_src      = buf;
    g_src_len  = (int)len;
    g_pos      = 0;
    g_line     = 1;
    g_col      = 1;
}

static void
do_put_pop(void)
{
    if (g_input_depth <= 0)
        die(g_line, g_col, "internal: PUT pop with empty stack");
    free(g_src);
    free((void *)g_src_path);
    g_input_depth--;
    g_src_path = g_input_paths[g_input_depth];
    g_src      = g_input_srcs[g_input_depth];
    g_src_len  = g_input_stack[g_input_depth].src_len;
    g_pos      = g_input_stack[g_input_depth].pos;
    g_line     = g_input_stack[g_input_depth].line;
    g_col      = g_input_stack[g_input_depth].col;
}

/* Read a filename token: everything from current position up to
 * whitespace, comment, or EOL.  No quoting needed per Merlin. */
static void
parse_filename_token(char *buf, int cap)
{
    skip_ws();
    int n = 0;
    while (g_pos < g_src_len && n < cap - 1 &&
           g_src[g_pos] != ' ' && g_src[g_pos] != '\t' &&
           g_src[g_pos] != '\n' && g_src[g_pos] != ';' &&
           g_src[g_pos] != '\r') {
        buf[n++] = g_src[g_pos];
        g_pos++; g_col++;
    }
    buf[n] = 0;
    if (n == 0) die(g_line, g_col, "PUT/ASM needs a filename");
}

static void
do_put(void)
{
    char fname[256];
    parse_filename_token(fname, sizeof fname);
    skip_to_eol();
    do_put_load(fname);
    /* Parse-to-EOF of included file is done by the caller's main
     * loop; we just leave g_src pointing at the new file.  When the
     * caller's outer loop hits g_pos >= g_src_len, it calls
     * do_put_pop_if_active() to fall back to the parent frame. */
}

static void
do_ent(const char *label)
{
    if (label[0] == 0) die(g_line, g_col, "ENT needs a label");
    int i = syms_lookup(label);
    if (i < 0) {
        /* Pass-1 first iteration may not have seen the label yet if
         * ENT precedes the definition; force-create. */
        i = syms_define(label, 0, 0, g_line);
        g_syms[i].defined = 0;  /* don't pretend it's defined yet */
    }
    g_syms[i].exported = 1;
}

static void
do_mx(void)
{
    skip_ws();
    if (g_pos >= g_src_len || g_src[g_pos] != '%')
        die(g_line, g_col, "MX needs a %bb binary literal");
    g_pos++; g_col++;
    int v = 0;
    int n = 0;
    while (g_pos < g_src_len && (g_src[g_pos] == '0' || g_src[g_pos] == '1')) {
        v = v * 2 + (g_src[g_pos] - '0');
        g_pos++; g_col++;
        n++;
    }
    if (n != 2) die(g_line, g_col, "MX needs exactly 2 binary digits");
    g_mx_m = (v >> 1) & 1;
    g_mx_x = v & 1;
}

/*-------------------------------------------------------------------
 * Opcode table + instruction emitter.
 *
 * Each row encodes (mnemonic, addressing-mode, opcode-byte).  The
 * parser classifies the operand into a mode; find_op() matches the
 * pair against this table.  Operand bytes are emitted by emit_instr()
 * based on the mode (and MX state for AM_IMM).
 *-----------------------------------------------------------------*/

/* Split 'typedef enum { ... } AddrMode;' into an enum block and a
 * separate typedef so fcc (which doesn't yet handle the combined form)
 * can compile this source.  Behaviour-equivalent in C: AddrMode is
 * still int, the constants still enter the global scope. */
enum {
    AM_IMPL,            /* no operand */
    AM_IMM,             /* #expr (size from MX) */
    AM_IMM_BYTE,        /* #expr — always 1 byte (SEP/REP/COP/WDM) */
    AM_DP,              /* expr, value fits 1 byte */
    AM_ABS,             /* expr, 2-byte operand */
    AM_ABS24,           /* expr, 3-byte operand (JSL) */
    AM_ABS_IND,         /* (expr) — 2-byte operand, JMP indirect */
    AM_DP_IND,          /* (dp) — 1-byte DP, indirect */
    AM_DP_IND_L,        /* [dp] — 1-byte DP, long indirect */
    AM_DP_IND_Y,        /* (dp),Y — 1-byte DP, indirect post-Y */
    AM_DP_IND_L_Y,      /* [dp],Y — 1-byte DP, long indirect post-Y */
    AM_DP_X_IND,        /* (dp,X) — 1-byte DP, pre-X indirect */
    AM_DP_X,            /* dp,X — 1-byte DP indexed */
    AM_DP_Y,            /* dp,Y — 1-byte DP indexed (LDX/STX) */
    AM_ABS_X,           /* abs,X — 2-byte abs indexed */
    AM_ABS_Y,           /* abs,Y — 2-byte abs indexed */
    AM_ABS24_X,         /* long,X — 3-byte long indexed (LDAL,X / STAL,X) */
    AM_ABS_X_IND,       /* (abs,X) — 2-byte abs, JMP/JSR pre-X indirect */
    AM_MVN,             /* src,dst — two byte operands, wire order dst src */
    AM_S_REL,           /* expr,S */
    AM_BRANCH_SHORT,    /* expr — 1-byte signed PC-relative (PC+2 base) */
    AM_BRANCH_LONG      /* expr — 2-byte signed PC-relative (PC+3 base, BRL) */
};
typedef int AddrMode;

typedef struct {
    const char *mnem;
    AddrMode    mode;
    int         opcode;
} OpRow;

static const OpRow g_op_table[] = {
    /* LDA */
    {"LDA",  AM_IMM,        0xA9},
    {"LDA",  AM_DP,         0xA5},
    {"LDA",  AM_ABS,        0xAD},
    {"LDA",  AM_S_REL,      0xA3},
    {"LDA",  AM_DP_IND,     0xB2},
    {"LDA",  AM_DP_IND_L,   0xA7},
    {"LDA",  AM_DP_IND_Y,   0xB1},
    {"LDA",  AM_DP_IND_L_Y, 0xB7},
    {"LDA",  AM_DP_X_IND,   0xA1},
    {"LDA",  AM_DP_X,       0xB5},
    {"LDA",  AM_ABS_X,      0xBD},
    {"LDA",  AM_ABS_Y,      0xB9},
    {"LDAL", AM_ABS24,      0xAF},
    {"LDAL", AM_ABS24_X,    0xBF},
    /* STA */
    {"STA",  AM_DP,         0x85},
    {"STA",  AM_ABS,        0x8D},
    {"STA",  AM_S_REL,      0x83},
    {"STA",  AM_DP_IND,     0x92},
    {"STA",  AM_DP_IND_L,   0x87},
    {"STA",  AM_DP_IND_Y,   0x91},
    {"STA",  AM_DP_IND_L_Y, 0x97},
    {"STA",  AM_DP_X_IND,   0x81},
    {"STA",  AM_DP_X,       0x95},
    {"STA",  AM_ABS_X,      0x9D},
    {"STA",  AM_ABS_Y,      0x99},
    {"STAL", AM_ABS24,      0x8F},
    {"STAL", AM_ABS24_X,    0x9F},
    /* ADC */
    {"ADC",  AM_IMM,        0x69},
    {"ADC",  AM_DP,         0x65},
    {"ADC",  AM_ABS,        0x6D},
    {"ADC",  AM_S_REL,      0x63},
    {"ADC",  AM_DP_IND,     0x72},
    {"ADC",  AM_DP_IND_L,   0x67},
    {"ADC",  AM_DP_IND_Y,   0x71},
    {"ADC",  AM_DP_IND_L_Y, 0x77},
    {"ADC",  AM_DP_X_IND,   0x61},
    {"ADC",  AM_DP_X,       0x75},
    {"ADC",  AM_ABS_X,      0x7D},
    {"ADC",  AM_ABS_Y,      0x79},
    {"ADCL", AM_ABS24,      0x6F},
    {"ADCL", AM_ABS24_X,    0x7F},
    /* SBC */
    {"SBC",  AM_IMM,        0xE9},
    {"SBC",  AM_DP,         0xE5},
    {"SBC",  AM_ABS,        0xED},
    {"SBC",  AM_S_REL,      0xE3},
    {"SBC",  AM_DP_IND,     0xF2},
    {"SBC",  AM_DP_IND_L,   0xE7},
    {"SBC",  AM_DP_IND_Y,   0xF1},
    {"SBC",  AM_DP_IND_L_Y, 0xF7},
    {"SBC",  AM_DP_X_IND,   0xE1},
    {"SBC",  AM_DP_X,       0xF5},
    {"SBC",  AM_ABS_X,      0xFD},
    {"SBC",  AM_ABS_Y,      0xF9},
    {"SBCL", AM_ABS24,      0xEF},
    {"SBCL", AM_ABS24_X,    0xFF},
    /* CMP */
    {"CMP",  AM_IMM,        0xC9},
    {"CMP",  AM_DP,         0xC5},
    {"CMP",  AM_ABS,        0xCD},
    {"CMP",  AM_S_REL,      0xC3},
    {"CMP",  AM_DP_IND,     0xD2},
    {"CMP",  AM_DP_IND_L,   0xC7},
    {"CMP",  AM_DP_IND_Y,   0xD1},
    {"CMP",  AM_DP_IND_L_Y, 0xD7},
    {"CMP",  AM_DP_X_IND,   0xC1},
    {"CMP",  AM_DP_X,       0xD5},
    {"CMP",  AM_ABS_X,      0xDD},
    {"CMP",  AM_ABS_Y,      0xD9},
    {"CMPL", AM_ABS24,      0xCF},
    {"CMPL", AM_ABS24_X,    0xDF},
    /* AND */
    {"AND",  AM_IMM,        0x29},
    {"AND",  AM_DP,         0x25},
    {"AND",  AM_ABS,        0x2D},
    {"AND",  AM_S_REL,      0x23},
    {"AND",  AM_DP_IND,     0x32},
    {"AND",  AM_DP_IND_L,   0x27},
    {"AND",  AM_DP_IND_Y,   0x31},
    {"AND",  AM_DP_IND_L_Y, 0x37},
    {"AND",  AM_DP_X_IND,   0x21},
    {"AND",  AM_DP_X,       0x35},
    {"AND",  AM_ABS_X,      0x3D},
    {"AND",  AM_ABS_Y,      0x39},
    {"ANDL", AM_ABS24,      0x2F},
    {"ANDL", AM_ABS24_X,    0x3F},
    /* ORA */
    {"ORA",  AM_IMM,        0x09},
    {"ORA",  AM_DP,         0x05},
    {"ORA",  AM_ABS,        0x0D},
    {"ORA",  AM_S_REL,      0x03},
    {"ORA",  AM_DP_IND,     0x12},
    {"ORA",  AM_DP_IND_L,   0x07},
    {"ORA",  AM_DP_IND_Y,   0x11},
    {"ORA",  AM_DP_IND_L_Y, 0x17},
    {"ORA",  AM_DP_X_IND,   0x01},
    {"ORA",  AM_DP_X,       0x15},
    {"ORA",  AM_ABS_X,      0x1D},
    {"ORA",  AM_ABS_Y,      0x19},
    {"ORAL", AM_ABS24,      0x0F},
    {"ORAL", AM_ABS24_X,    0x1F},
    /* EOR */
    {"EOR",  AM_IMM,        0x49},
    {"EOR",  AM_DP,         0x45},
    {"EOR",  AM_ABS,        0x4D},
    {"EOR",  AM_S_REL,      0x43},
    {"EOR",  AM_DP_IND,     0x52},
    {"EOR",  AM_DP_IND_L,   0x47},
    {"EOR",  AM_DP_IND_Y,   0x51},
    {"EOR",  AM_DP_IND_L_Y, 0x57},
    {"EOR",  AM_DP_X_IND,   0x41},
    {"EOR",  AM_DP_X,       0x55},
    {"EOR",  AM_ABS_X,      0x5D},
    {"EOR",  AM_ABS_Y,      0x59},
    {"EORL", AM_ABS24,      0x4F},
    {"EORL", AM_ABS24_X,    0x5F},
    /* LDX/LDY/STX/STY/CPX/CPY (M7) */
    {"LDX",  AM_IMM,        0xA2},
    {"LDX",  AM_DP,         0xA6},
    {"LDX",  AM_ABS,        0xAE},
    {"LDX",  AM_DP_Y,       0xB6},
    {"LDX",  AM_ABS_Y,      0xBE},
    {"LDY",  AM_IMM,        0xA0},
    {"LDY",  AM_DP,         0xA4},
    {"LDY",  AM_ABS,        0xAC},
    {"LDY",  AM_DP_X,       0xB4},
    {"LDY",  AM_ABS_X,      0xBC},
    {"STX",  AM_DP,         0x86},
    {"STX",  AM_ABS,        0x8E},
    {"STX",  AM_DP_Y,       0x96},
    {"STY",  AM_DP,         0x84},
    {"STY",  AM_ABS,        0x8C},
    {"STY",  AM_DP_X,       0x94},
    {"STZ",  AM_DP,         0x64},
    {"STZ",  AM_ABS,        0x9C},
    {"STZ",  AM_DP_X,       0x74},
    {"STZ",  AM_ABS_X,      0x9E},
    {"CPX",  AM_IMM,        0xE0},
    {"CPX",  AM_DP,         0xE4},
    {"CPX",  AM_ABS,        0xEC},
    {"CPY",  AM_IMM,        0xC0},
    {"CPY",  AM_DP,         0xC4},
    {"CPY",  AM_ABS,        0xCC},
    {"BIT",  AM_IMM,        0x89},
    {"BIT",  AM_DP,         0x24},
    {"BIT",  AM_ABS,        0x2C},
    {"BIT",  AM_DP_X,       0x34},
    {"BIT",  AM_ABS_X,      0x3C},
    /* Memory shift/rotate + inc/dec (M7) */
    {"ASL",  AM_DP,         0x06},
    {"ASL",  AM_ABS,        0x0E},
    {"ASL",  AM_DP_X,       0x16},
    {"ASL",  AM_ABS_X,      0x1E},
    {"LSR",  AM_DP,         0x46},
    {"LSR",  AM_ABS,        0x4E},
    {"LSR",  AM_DP_X,       0x56},
    {"LSR",  AM_ABS_X,      0x5E},
    {"ROL",  AM_DP,         0x26},
    {"ROL",  AM_ABS,        0x2E},
    {"ROL",  AM_DP_X,       0x36},
    {"ROL",  AM_ABS_X,      0x3E},
    {"ROR",  AM_DP,         0x66},
    {"ROR",  AM_ABS,        0x6E},
    {"ROR",  AM_DP_X,       0x76},
    {"ROR",  AM_ABS_X,      0x7E},
    {"INC",  AM_DP,         0xE6},
    {"INC",  AM_ABS,        0xEE},
    {"INC",  AM_DP_X,       0xF6},
    {"INC",  AM_ABS_X,      0xFE},
    {"DEC",  AM_DP,         0xC6},
    {"DEC",  AM_ABS,        0xCE},
    {"DEC",  AM_DP_X,       0xD6},
    {"DEC",  AM_ABS_X,      0xDE},
    {"TRB",  AM_DP,         0x14},
    {"TRB",  AM_ABS,        0x1C},
    {"TSB",  AM_DP,         0x04},
    {"TSB",  AM_ABS,        0x0C},
    /* Implied — flags */
    {"CLC", AM_IMPL,  0x18},
    {"SEC", AM_IMPL,  0x38},
    {"CLI", AM_IMPL,  0x58},
    {"SEI", AM_IMPL,  0x78},
    {"CLD", AM_IMPL,  0xD8},
    {"SED", AM_IMPL,  0xF8},
    {"CLV", AM_IMPL,  0xB8},
    /* Implied — returns */
    {"RTS", AM_IMPL,  0x60},
    {"RTL", AM_IMPL,  0x6B},
    {"RTI", AM_IMPL,  0x40},
    /* Implied — transfers (M5) */
    {"TAX", AM_IMPL,  0xAA},
    {"TAY", AM_IMPL,  0xA8},
    {"TXA", AM_IMPL,  0x8A},
    {"TYA", AM_IMPL,  0x98},
    {"TXY", AM_IMPL,  0x9B},
    {"TYX", AM_IMPL,  0xBB},
    {"TCD", AM_IMPL,  0x5B},
    {"TDC", AM_IMPL,  0x7B},
    {"TCS", AM_IMPL,  0x1B},
    {"TSC", AM_IMPL,  0x3B},
    {"TSX", AM_IMPL,  0xBA},
    {"TXS", AM_IMPL,  0x9A},
    {"XBA", AM_IMPL,  0xEB},
    {"XCE", AM_IMPL,  0xFB},
    /* Implied — stack (M5) */
    {"PHA", AM_IMPL,  0x48},
    {"PLA", AM_IMPL,  0x68},
    {"PHX", AM_IMPL,  0xDA},
    {"PLX", AM_IMPL,  0xFA},
    {"PHY", AM_IMPL,  0x5A},
    {"PLY", AM_IMPL,  0x7A},
    {"PHB", AM_IMPL,  0x8B},
    {"PLB", AM_IMPL,  0xAB},
    {"PHD", AM_IMPL,  0x0B},
    {"PLD", AM_IMPL,  0x2B},
    {"PHK", AM_IMPL,  0x4B},
    {"PHP", AM_IMPL,  0x08},
    {"PLP", AM_IMPL,  0x28},
    /* Implied — inc/dec (M5) */
    {"INX", AM_IMPL,  0xE8},
    {"INY", AM_IMPL,  0xC8},
    {"DEX", AM_IMPL,  0xCA},
    {"DEY", AM_IMPL,  0x88},
    {"INC", AM_IMPL,  0x1A},   /* bare = accumulator */
    {"DEC", AM_IMPL,  0x3A},   /* bare = accumulator */
    /* Implied — bare-A shifts (M5) */
    {"ASL", AM_IMPL,  0x0A},
    {"LSR", AM_IMPL,  0x4A},
    {"ROL", AM_IMPL,  0x2A},
    {"ROR", AM_IMPL,  0x6A},
    /* Implied — misc (M5) */
    {"NOP", AM_IMPL,  0xEA},
    {"WAI", AM_IMPL,  0xCB},
    {"STP", AM_IMPL,  0xDB},
    {"WDM", AM_IMM_BYTE, 0x42},
    /* Mode-change (M5) — always 1-byte immediate. */
    {"SEP", AM_IMM_BYTE, 0xE2},
    {"REP", AM_IMM_BYTE, 0xC2},
    /* COP: Merlin32 v1.1.10 rejects `COP #$nn`; we follow suit to keep
     * fas byte-eq with the oracle.  No FGX user code emits COP today.
     * If a future caller needs it, re-add with Merlin's preferred form
     * once that's known. */
    {"BRK", AM_IMPL,     0x00},
    /* Jumps + calls (M4) */
    {"JSR", AM_ABS,     0x20},
    {"JSL", AM_ABS24,   0x22},
    {"JMP", AM_ABS,       0x4C},
    {"JMP", AM_ABS_IND,   0x6C},
    {"JMP", AM_ABS_X_IND, 0x7C},
    {"JML", AM_ABS24,     0x5C},
    {"JSR", AM_ABS_X_IND, 0xFC},
    {"PEA", AM_ABS,         0xF4},
    {"PEI", AM_DP_IND,      0xD4},
    {"PER", AM_BRANCH_LONG, 0x62},
    {"MVN", AM_MVN,       0x54},
    {"MVP", AM_MVN,       0x44},
    /* Branches — short (1-byte signed PC-rel) and long (2-byte LE). */
    {"BEQ", AM_BRANCH_SHORT, 0xF0},
    {"BNE", AM_BRANCH_SHORT, 0xD0},
    {"BCC", AM_BRANCH_SHORT, 0x90},
    {"BCS", AM_BRANCH_SHORT, 0xB0},
    {"BMI", AM_BRANCH_SHORT, 0x30},
    {"BPL", AM_BRANCH_SHORT, 0x10},
    {"BVC", AM_BRANCH_SHORT, 0x50},
    {"BRA", AM_BRANCH_SHORT, 0x80},
    {"BRL", AM_BRANCH_LONG,  0x82},
    /* sentinel */
    {NULL, 0, 0}
};

static int
find_op(const char *mnem, AddrMode mode)
{
    for (int i = 0; g_op_table[i].mnem; i++) {
        if (strcmp(g_op_table[i].mnem, mnem) == 0 &&
            g_op_table[i].mode == mode) return i;
    }
    return -1;
}

static int
is_known_mnem(const char *mnem)
{
    for (int i = 0; g_op_table[i].mnem; i++)
        if (strcmp(g_op_table[i].mnem, mnem) == 0) return 1;
    return 0;
}

static void
emit_instr(const char *mnem, int force_abs)
{
    skip_ws();
    AddrMode mode;
    int      value = 0;
    int      value_bank = 0;

    /* Branches have exactly one encoding (short or long).  If the
     * mnemonic appears in the table as a branch, the operand is a
     * single absolute target expression. */
    int br_short_idx = find_op(mnem, AM_BRANCH_SHORT);
    int br_long_idx  = find_op(mnem, AM_BRANCH_LONG);
    if (br_short_idx >= 0 || br_long_idx >= 0) {
        int target = eval_expr();
        int idx = (br_short_idx >= 0) ? br_short_idx : br_long_idx;
        int short_branch = (br_short_idx >= 0);
        emit_byte(g_op_table[idx].opcode);
        if (short_branch) {
            /* PC after this instr = opcode_addr + 2.  After emit_byte
             * above, g_pc = opcode_addr + 1, so next_pc = g_pc + 1. */
            int delta_s = target - (g_pc + 1);
            if (g_pass == 2 && (delta_s < -128 || delta_s > 127))
                die(g_line, g_col, "branch out of range — use BRL");
            emit_byte(delta_s & 0xFF);
        } else {
            /* BRL: PC after = opcode_addr + 3 = g_pc + 2. */
            int delta_l = target - (g_pc + 2);
            emit_byte(delta_l & 0xFF);
            emit_byte((delta_l >> 8) & 0xFF);
        }
        return;
    }

    if (at_eol()) {
        mode = AM_IMPL;
    } else if (g_src[g_pos] == '#') {
        g_pos++; g_col++;
        value = eval_expr(); value_bank = g_last_bank;
        /* SEP/REP/COP/WDM are always 1-byte immediate (MX-insensitive). */
        mode = (find_op(mnem, AM_IMM_BYTE) >= 0) ? AM_IMM_BYTE : AM_IMM;
    } else if (g_src[g_pos] == '(') {
        /* Indirect forms:
         *   (dp,X)   pre-indexed-X indirect
         *   (dp)     plain DP indirect
         *   (dp),Y   post-indexed-Y indirect
         *   (abs)    JMP indirect (2-byte operand) — disambiguated by
         *            mnemonic (JMP has AM_ABS_IND row, LDA does not). */
        g_pos++; g_col++;
        value = eval_expr(); value_bank = g_last_bank;
        skip_ws();
        if (g_pos < g_src_len && g_src[g_pos] == ',') {
            g_pos++; g_col++;
            skip_ws();
            char idx = g_pos < g_src_len ? g_src[g_pos] : 0;
            if (idx != 'X' && idx != 'x')
                die(g_line, g_col, "expected ',X' inside ()");
            g_pos++; g_col++;
            skip_ws();
            if (g_pos >= g_src_len || g_src[g_pos] != ')')
                die(g_line, g_col, "expected ')'");
            g_pos++; g_col++;
            /* JMP/JSR (abs,X) take 2-byte operand (AM_ABS_X_IND).
             * LDA-family (dp,X) take 1-byte operand (AM_DP_X_IND). */
            if (find_op(mnem, AM_ABS_X_IND) >= 0)
                mode = AM_ABS_X_IND;
            else
                mode = AM_DP_X_IND;
        } else {
            if (g_pos >= g_src_len || g_src[g_pos] != ')')
                die(g_line, g_col, "expected ')'");
            g_pos++; g_col++;
            skip_ws();
            if (g_pos < g_src_len && g_src[g_pos] == ',') {
                g_pos++; g_col++;
                skip_ws();
                char idx = g_pos < g_src_len ? g_src[g_pos] : 0;
                if (idx != 'Y' && idx != 'y')
                    die(g_line, g_col, "expected ',Y' after ()");
                g_pos++; g_col++;
                mode = AM_DP_IND_Y;
            } else if (find_op(mnem, AM_ABS_IND) >= 0) {
                mode = AM_ABS_IND;
            } else {
                mode = AM_DP_IND;
            }
        }
    } else if (g_src[g_pos] == '[') {
        /* Long indirect:  [dp]  or  [dp],Y . */
        g_pos++; g_col++;
        value = eval_expr(); value_bank = g_last_bank;
        skip_ws();
        if (g_pos >= g_src_len || g_src[g_pos] != ']')
            die(g_line, g_col, "expected ']'");
        g_pos++; g_col++;
        skip_ws();
        if (g_pos < g_src_len && g_src[g_pos] == ',') {
            g_pos++; g_col++;
            skip_ws();
            char idx = g_pos < g_src_len ? g_src[g_pos] : 0;
            if (idx != 'Y' && idx != 'y')
                die(g_line, g_col, "expected ',Y' after []");
            g_pos++; g_col++;
            mode = AM_DP_IND_L_Y;
        } else {
            mode = AM_DP_IND_L;
        }
    } else if (strcmp(mnem, "MVN") == 0 || strcmp(mnem, "MVP") == 0) {
        /* MVN/MVP srcbank,dstbank.  Wire order: opcode dst src. */
        int src = eval_expr();
        skip_ws();
        if (g_pos >= g_src_len || g_src[g_pos] != ',')
            die(g_line, g_col, "MVN/MVP needs src,dst");
        g_pos++; g_col++;
        int dst = eval_expr();
        int idx = find_op(mnem, AM_MVN);
        emit_byte(g_op_table[idx].opcode);
        emit_byte(dst & 0xFF);
        emit_byte(src & 0xFF);
        return;
    } else {
        g_eval_all_defined = 1;
        g_eval_is_literal_only = 1;
        value = eval_expr(); value_bank = g_last_bank;
        skip_ws();
        if (g_pos < g_src_len && g_src[g_pos] == ',') {
            g_pos++; g_col++;
            skip_ws();
            char idx = g_pos < g_src_len ? g_src[g_pos] : 0;
            /* DP-fold gate: operand must be a pure literal (no symbols,
             * no `*`) AND fit in 1 byte.  Symbol refs always go ABS so
             * `STA name` never accidentally hits a DP slot. */
            int fits_dp = (g_eval_is_literal_only && (value & 0xFFFF00) == 0);
            if (idx == 'S' || idx == 's') {
                g_pos++; g_col++;
                mode = AM_S_REL;
            } else if (idx == 'X' || idx == 'x') {
                g_pos++; g_col++;
                if (!force_abs && fits_dp && find_op(mnem, AM_DP_X) >= 0) {
                    mode = AM_DP_X;
                } else if (find_op(mnem, AM_ABS_X) >= 0) {
                    mode = AM_ABS_X;
                } else if (find_op(mnem, AM_ABS24_X) >= 0) {
                    mode = AM_ABS24_X;
                } else {
                    die(g_line, g_col, "no ,X encoding for this mnemonic");
                    return;
                }
            } else if (idx == 'Y' || idx == 'y') {
                g_pos++; g_col++;
                if (!force_abs && fits_dp && find_op(mnem, AM_DP_Y) >= 0) {
                    mode = AM_DP_Y;
                } else if (find_op(mnem, AM_ABS_Y) >= 0) {
                    mode = AM_ABS_Y;
                } else {
                    die(g_line, g_col, "no ,Y encoding for this mnemonic");
                    return;
                }
            } else {
                die(g_line, g_col, "expected ,X / ,Y / ,S");
                return;
            }
        } else {
            /* dp vs abs: pick dp only if the operand was a pure literal
             * (no symbol refs, no `*`) AND fits in 1 byte.  Symbol refs
             * always go ABS regardless of resolved value — FGX policy:
             * DP is a scarce shared resource (libc/fcc/args use specific
             * DP slots, plus firmware) so `STA name` must hit the
             * symbol's actual address, never a DP slot that happens to
             * share the low byte.  Force-abs colon `LDA:` still bypasses
             * dp selection entirely (kept for backward compat). */
            if (!force_abs && g_eval_is_literal_only && (value & 0xFFFF00) == 0 &&
                find_op(mnem, AM_DP) >= 0) {
                mode = AM_DP;
            } else {
                mode = AM_ABS;
            }
            /* JSL/JML/LDAL etc. have no AM_ABS row — only the 3-byte
             * long absolute. */
            if (mode == AM_ABS && find_op(mnem, AM_ABS) < 0 &&
                find_op(mnem, AM_ABS24) >= 0) {
                mode = AM_ABS24;
            }
        }
    }

    int idx = find_op(mnem, mode);
    if (idx < 0) {
        char buf[64];
        snprintf(buf, sizeof buf, "no %s encoding for this operand", mnem);
        die(g_line, g_col, buf);
    }
    emit_byte(g_op_table[idx].opcode);

    switch (mode) {
        case AM_IMPL:
            break;
        case AM_IMM: {
            /* X-index ops (LDX/LDY/CPX/CPY) take operand sized by
             * g_mx_x; everything else uses g_mx_m.  LDX/LDY/CPX/CPY
             * arrive in M7. */
            int x_op = (strcmp(mnem, "LDX") == 0 ||
                        strcmp(mnem, "LDY") == 0 ||
                        strcmp(mnem, "CPX") == 0 ||
                        strcmp(mnem, "CPY") == 0);
            int sz = (x_op ? g_mx_x : g_mx_m) ? 1 : 2;
            for (int i = 0; i < sz; i++)
                emit_byte((value >> (8 * i)) & 0xFF);
            break;
        }
        case AM_IMM_BYTE:
            emit_byte(value & 0xFF);
            break;
        case AM_DP:
        case AM_S_REL:
        case AM_DP_IND:
        case AM_DP_IND_L:
        case AM_DP_IND_Y:
        case AM_DP_IND_L_Y:
        case AM_DP_X_IND:
        case AM_DP_X:
        case AM_DP_Y:
            emit_byte(value & 0xFF);
            break;
        case AM_ABS:
        case AM_ABS_IND:
        case AM_ABS_X:
        case AM_ABS_Y:
        case AM_ABS_X_IND:
            emit_byte(value & 0xFF);
            emit_byte((value >> 8) & 0xFF);
            break;
        case AM_ABS24:
        case AM_ABS24_X:
            emit_byte(value & 0xFF);
            emit_byte((value >> 8) & 0xFF);
            /* Bank byte from g_last_bank side channel (fcc int is
             * 16-bit, so `value >> 16` always gives 0). */
            emit_byte(value_bank & 0xFF);
            break;
        case AM_MVN:
        case AM_BRANCH_SHORT:
        case AM_BRANCH_LONG:
            /* unreachable — handled inline above */
            break;
    }
}

/*-------------------------------------------------------------------
 * Line dispatcher.
 *-----------------------------------------------------------------*/

static int
read_op(char *op, int cap)
{
    int n = 0;
    while (g_pos < g_src_len && n < cap - 1 &&
           ((g_src[g_pos] >= 'A' && g_src[g_pos] <= 'Z') ||
            (g_src[g_pos] >= 'a' && g_src[g_pos] <= 'z'))) {
        op[n++] = g_src[g_pos];
        g_pos++; g_col++;
    }
    op[n] = 0;
    for (int i = 0; i < n; i++)
        if (op[i] >= 'a' && op[i] <= 'z') op[i] -= 32;
    return n;
}

static void
parse_line(void)
{
    /* Skip blank lines and full-line comments fast. */
    if (g_pos >= g_src_len) return;
    if (g_src[g_pos] == '\n' || g_src[g_pos] == '\r') {
        /* Eat one or both halves of a CR / LF / CRLF terminator. */
        if (g_src[g_pos] == '\r') { g_pos++; g_col++; }
        if (g_pos < g_src_len && g_src[g_pos] == '\n') {
            g_pos++; g_col++;
        }
        g_line++; g_col = 1;
        return;
    }
    if (g_src[g_pos] == ';') { skip_to_eol(); return; }
    /* Merlin-style full-line comment: `*` at column 1. */
    if (g_src[g_pos] == '*' && g_col == 1) { skip_to_eol(); return; }

    /* Column-1 label.  If the first character on the line is not
     * whitespace, the line begins with a label. */
    char label[SYM_NAME_LEN];
    label[0] = 0;
    if (g_src[g_pos] != ' ' && g_src[g_pos] != '\t') {
        if (!is_ident_start(g_src[g_pos]) && g_src[g_pos] != '@')
            die(g_line, g_col, "expected label or indented opcode");
        /* Plain (global) labels update g_cur_global *before* mangling
         * so @local references on the same line see the new scope.
         * @-prefixed labels keep the current scope. */
        if (g_src[g_pos] != '@') {
            char tmp[SYM_NAME_LEN];
            int save_pos = g_pos, save_line = g_line, save_col = g_col;
            parse_ident(tmp, sizeof tmp);
            g_pos = save_pos; g_line = save_line; g_col = save_col;
            strncpy(g_cur_global, tmp, sizeof(g_cur_global) - 1);
            g_cur_global[sizeof(g_cur_global) - 1] = 0;
        }
        parse_symname(label, sizeof label);
        if (g_pass == 1) {
            syms_define(label, g_pc, g_pc_bank, g_line);
        }
    }

    skip_ws();
    if (at_eol()) {
        /* Label-only line. */
        skip_to_eol();
        return;
    }

    char op[8];
    int  n = read_op(op, sizeof op);
    if (n == 0) {
        die(g_line, g_col, "expected opcode or directive");
    }

    /* Force-abs colon `LDA:` immediately after mnemonic — no
     * whitespace between letters and `:`.  Skips dp/abs auto-select
     * for the abs-side, always picks AM_ABS / AM_ABS_X / AM_ABS_Y. */
    int force_abs = 0;
    if (g_pos < g_src_len && g_src[g_pos] == ':') {
        force_abs = 1;
        g_pos++; g_col++;
    }

    skip_ws();

    if (strcmp(op, "ORG") == 0)  {
        do_org(); skip_to_eol(); return;
    }
    if (strcmp(op, "EQU") == 0)  { do_equ(label); skip_to_eol(); return; }
    if (strcmp(op, "DFB") == 0)  { do_dfb(); skip_to_eol(); return; }
    if (strcmp(op, "DA")  == 0)  { do_da();  skip_to_eol(); return; }
    if (strcmp(op, "DS")  == 0)  { do_ds();  skip_to_eol(); return; }
    if (strcmp(op, "HEX") == 0)  { do_hex(); skip_to_eol(); return; }
    if (strcmp(op, "ASC") == 0)  { do_asc(); skip_to_eol(); return; }
    {
        int _r = strcmp(op, "MX");
        if (_r == 0)  {
            do_mx();  skip_to_eol(); return;
        }
    }
    if (strcmp(op, "PUT") == 0)  { do_put(); return; }
    if (strcmp(op, "ASM") == 0)  { do_put(); return; }   /* alias of PUT in v0 */
    if (strcmp(op, "ENT") == 0)  { do_ent(label); skip_to_eol(); return; }
    /* No-op link/listing directives (Merlin wrappers use these; fas
     * derives the output name from -o, not DSK). */
    if (strcmp(op, "TYP") == 0)  { skip_to_eol(); return; }
    if (strcmp(op, "DSK") == 0)  { skip_to_eol(); return; }
    if (strcmp(op, "LST") == 0)  { skip_to_eol(); return; }
    if (strcmp(op, "XC")  == 0)  { skip_to_eol(); return; }
    if (strcmp(op, "REL") == 0)  { skip_to_eol(); return; }

    if (is_known_mnem(op)) {
        emit_instr(op, force_abs);
        skip_to_eol();
        return;
    }

    die(g_line, g_col, "unknown opcode or directive");
}

/*-------------------------------------------------------------------
 * Driver.
 *-----------------------------------------------------------------*/

static void
run_pass(int pass)
{
    /* Decls upfront — fcc requires the first stmt of a function
     * to be a decl in order to emit the SBC #FRAMESIZE prologue. */
    int _line_cnt = 0;
    g_pass = pass;
    g_pos  = 0;
    g_line = 1;
    g_col  = 1;
    g_pc   = 0;
    g_mx_m = 1;
    g_mx_x = 1;
    g_cur_global[0] = 0;
    while (g_input_depth > 0) do_put_pop();
    for (;;) {
        while (g_pos < g_src_len) {
            parse_line();
            _line_cnt = _line_cnt + 1;
        }
        if (g_input_depth == 0) break;
        do_put_pop();
    }
}

/* Run pass 1 in a loop until symbol values stabilize.  Instructions
 * can only shrink across iterations (forward refs sized as abs in iter
 * N may shrink to dp in iter N+1 once the symbol's value is known), so
 * this is guaranteed to converge.  Cap at 8 iterations as a sanity
 * brake. */
/* prev_values lives at file scope so the local frame for layout_passes
 * doesn't exceed the 65816 stack-relative addressing limit (1-byte
 * displacement = 256 bytes max).  MAX_SYMBOLS=1024 ints = 2048 B. */
static int layout_prev_values[MAX_SYMBOLS];

static void
layout_passes(void)
{
    printf("layout");
    int prev_n_syms = -1;
    for (int iter = 0; iter < 8; iter++) {
        printf(".");
        run_pass(1);
        int stable = (g_n_syms == prev_n_syms);
        if (stable) {
            for (int i = 0; i < g_n_syms; i++) {
                if (g_syms[i].value != layout_prev_values[i]) { stable = 0; break; }
            }
        }
        if (stable) {
#ifdef __FGX__
            faslog("lp:stable", 0, 0);
#endif
            printf(" stable\n");
            return;
        }
        for (int i = 0; i < g_n_syms; i++) layout_prev_values[i] = g_syms[i].value;
        prev_n_syms = g_n_syms;
    }
    printf("\nfas: layout did not converge after 8 iterations\n");
    exit(1);
}

int
main(int argc, char **argv)
{
#ifdef __FGX__
    /* First thing: wipe and write a marker so we know fas at least
     * reached main.  faslog opens /root/faslog with "ab" so the
     * caller must wipe first. */
    { FILE *_w = fopen("/root/faslog", "wb"); if (_w) fclose(_w); }
#endif
    if (argc < 2) {
        fprintf(stderr, "usage: fas input.s [-o output.bin]\n");
        return 1;
    }
    g_src_path = argv[1];
    g_out_path = "a.out";
#ifndef __FGX__
    int dump_syms = 0;
    const char *dep_path = 0;    /* -MF <file>; 0 = derive from -o */
    int         dep_out  = 0;    /* -MD */
#endif
    for (int i = 2; i < argc; i = i + 1) {
        const char *ai = argv[i];
        if (strcmp(ai, "-o") == 0 && i + 1 < argc) {
            i = i + 1;
            g_out_path = argv[i];
        }
#ifndef __FGX__
        else if (strcmp(ai, "--dump-symbols") == 0) {
            dump_syms = 1;
        }
        else if (strcmp(ai, "-MD") == 0) {
            dep_out = 1;
        }
        else if (strcmp(ai, "-MF") == 0 && i + 1 < argc) {
            i = i + 1;
            dep_path = argv[i];
            dep_out = 1;             /* -MF implies -MD, as in cc */
        }
#endif
    }

    FILE *fp = fopen(g_src_path, "rb");
    if (!fp) { fprintf(stderr, "fas: cannot open %s\n", g_src_path); return 1; }
    fseek(fp, 0, SEEK_END);
    g_src_len = (int)ftell(fp);
    fseek(fp, 0, SEEK_SET);
    g_src = (char *)malloc(g_src_len + 1);
    if (!g_src) { fprintf(stderr, "out of memory\n"); return 1; }
    fread(g_src, 1, g_src_len, fp);
    g_src[g_src_len] = 0;
    fclose(fp);
#ifdef __FGX__
    fas_out_buf = (char *)malloc(FAS_OUT_BUF_MAX);
    if (!fas_out_buf) { fprintf(stderr, "out of memory\n"); return 1; }
#endif
#ifdef __FGX__
    /* wipe prior faslog */
    {
        FILE *_w = fopen("/root/faslog", "wb");
        if (_w) { fclose(_w); }
    }
#endif
    fprintf(stdout, "fas: %s (%d bytes)\n", g_src_path, g_src_len);
    /* Pass 1: iterative layout — converge on dp/abs sizing. */
    layout_passes();
#ifdef __FGX__
    faslog("main:layout done", 0, 0);
#endif

    /* Pass 2: emit. */
#ifdef __FGX__
    fas_out_pos = 0;
#endif
    g_out = fopen(g_out_path, "wb");
    if (!g_out) { fprintf(stderr, "fas: cannot create %s\n", g_out_path); return 1; }
    printf("emit");
    run_pass(2);
    printf(" done\n");
#ifdef __FGX__
    fwrite(fas_out_buf, 1, fas_out_pos, g_out);
    fprintf(stdout, "fas: wrote %d bytes -> %s\n", fas_out_pos, g_out_path);
#else
    long _bytes = ftell(g_out);
    fprintf(stdout, "fas: wrote %ld bytes -> %s\n",
            (_bytes < 0) ? 0L : _bytes, g_out_path);
#endif
    fclose(g_out);
#ifndef __FGX__
    /* Depfile: written only here, after pass 2 completed and g_out closed.
     * Emitting it alongside a failed assembly would let the build system mark
     * the target up to date against an object that was never produced -- and
     * fas die()s on error, so reaching this point IS the success signal. */
    if (dep_out) {
        char derived[1024];
        const char *dp = dep_path;
        if (!dp) {
            snprintf(derived, sizeof derived, "%s.d", g_out_path);
            dp = derived;
        }
        FILE *df = fopen(dp, "w");
        if (!df) {
            fprintf(stderr, "fas: cannot create depfile %s\n", dp);
            return 1;
        }
        fprintf(df, "%s:", g_out_path);
        /* The top-level source is read by main(), not through do_put(), so it
         * is never in the recorded list. */
        fprintf(df, " \\\n  %s", g_src_path);
        for (int d = 0; d < g_n_deps; d = d + 1)
            fprintf(df, " \\\n  %s", g_deps[d]);
        fputc('\n', df);
        fclose(df);
    }
    if (dump_syms) {
        for (int i = 0; i < g_n_syms; i++) {
            fprintf(stderr, "%06lX %s\n",
                    g_syms[i].value & 0xFFFFFFL, g_syms[i].name);
        }
    }
#endif
    return 0;
}
