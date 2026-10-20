#include "fcc.h"

/* --- T2-2: pp as a token pass ---------------------------------------
 * Macro bodies are TOKEN SLICES (tokenized once at #define time, raw);
 * expansion is a token splice driven by pp_next_tok() below; the #if
 * evaluator walks tokens.  There is no body text and no rescan — the
 * textual-substitution machinery (pp_push_macro / pp_push_macro_funclike
 * / the char-level pp_eval_*) is deleted.  The pp frame stack now holds
 * FILES only (root + #include). */
static const char *intern_bytes(const char *p, int len);
static Tok *pp_tokenize_text(const char *text, int len, int *out_n);
static void pp_macro_set_body(PpMacro *m, const char *text, int len);
static long pp_eval_expr_text(const char *s);
static void pp_tokenize_buffer(void);

/* Raw tokenize mode: scan_tok() emits tokens with NO directive processing
 * and NO frame pop at EOF (used for #define bodies, #if expressions, and
 * funclike-call argument texts). */
static int g_pp_raw_mode = 0;

int g_pp_body_tok_bytes = 0;   /* Part-V stats: malloc'd body/expansion toks */

void
derive_tu_prefix(const char *path)
{
    const char *base = path;
    for (const char *p = path; *p; p++) {
        if (*p == '/' || *p == '\\') base = p + 1;
    }
    /* Strip only the EXTENSION -- i.e. cut at the LAST dot, not the first.
     * Cutting at the first dot made every TU whose basename shares a pre-dot
     * prefix derive the SAME prefix: tcsh's ed.chared.c, ed.screen.c,
     * ed.defns.c and ed.refresh.c all became `_ed`, so their data labels
     * (_ed_S0, ...) collided.  Nothing diagnosed it at compile time -- it
     * surfaced only as merlin32 "Found label name '_ed_S0' in both source
     * files" when the data segments were linked together.  Interior dots
     * become '_' in the loop below, so ed.chared -> _ed_chared.
     * For an ordinary single-dot name the last dot IS the first, so every
     * existing prefix is unchanged. */
    int end = 0;
    for (int i = 0; base[i]; i++) if (base[i] == '.') end = i;
    if (end == 0) { for (int i = 0; base[i]; i++) end = i + 1; }  /* no dot */
    if (end > 26) end = 26;  /* leave room for '_<name>' */
    g_tu_prefix[0] = '_';
    int j = 1;
    for (int i = 0; i < end; i++) {
        char c = base[i];
        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
            (c >= '0' && c <= '9'))
            g_tu_prefix[j++] = c;
        else
            g_tu_prefix[j++] = '_';
    }
    g_tu_prefix[j] = '\0';
}

/* T2-2 stage c: the pp frame stack is DELETED — #include nesting is
 * C-stack recursion in pp_tokenize_buffer(), and the scanner state is
 * just the g_src globals plus the current file path (for relative
 * include resolution) and the depth counter. */
static const char *g_cur_path = "<input>";
static int         g_inc_depth = 0;

void
lex_set_source(const char *buf, int len, const char *path)
{
    g_src     = buf;
    g_src_len = (size_t)len;
    g_pos     = 0;
    g_line    = 1;
    g_col     = 1;
    /* Interned: an include passes its path in a stack buffer that dies when
     * the include returns, and every token keeps a pointer to it. */
    g_cur_path = path ? intern_bytes(path, (int)strlen(path)) : path;
}

/* K&R A.12.2: "Lines that end with the backslash character \\ are folded by
 * deleting the backslash and the following newline character."  Each newline
 * so deleted is put back after the folded line's own newline, so every later
 * line keeps its number in diagnostics.  In place: a fold removes two
 * characters and puts back one. */
int
splice_line_continuations(char *buf, int len)
{
    int r = 0, w = 0, folded = 0;
    while (r < len) {
        if (buf[r] == '\\' && r + 1 < len &&
            (buf[r + 1] == '\n' ||
             (buf[r + 1] == '\r' && r + 2 < len && buf[r + 2] == '\n'))) {
            r += (buf[r + 1] == '\r') ? 3 : 2;   /* skip backslash + newline */
            folded++;
            continue;
        }
        buf[w++] = buf[r++];
        if (buf[w - 1] == '\n')
            for (; folded; folded--)
                buf[w++] = '\n';
    }
    buf[w] = '\0';
    return w;
}

/* --- Dependency list (-MD/-MF) ----------------------------------------
 * Grown on demand; never freed (fcc is a one-shot process).  Linear dedup is
 * fine: a TU pulls in tens of headers, not thousands. */
static const char **g_deps;
static int          g_n_deps, g_cap_deps;

void
pp_dep_add(const char *path)
{
    for (int i = 0; i < g_n_deps; i++)
        if (strcmp(g_deps[i], path) == 0) return;   /* already recorded */
    if (g_n_deps == g_cap_deps) {
        int ncap = g_cap_deps ? g_cap_deps * 2 : 32;
        const char **n = (const char **)realloc((void *)g_deps,
                                                (size_t)ncap * sizeof *n);
        if (!n) return;            /* OOM: drop the dep rather than kill the
                                    * compile -- a missing edge degrades the
                                    * build graph, a dead compiler stops it. */
        g_deps = n; g_cap_deps = ncap;
    }
    g_deps[g_n_deps++] = strdup(path);
}

int         pp_dep_count(void)      { return g_n_deps; }
const char *pp_dep_get(int i)       { return (i >= 0 && i < g_n_deps) ? g_deps[i] : NULL; }

/* Load + line-splice an include file.  Same error messages as the old
 * pp_push_file; the caller owns (and frees) the returned buffer. */
static char *
pp_read_file(const char *path, int *out_len)
{
    FILE *f = fopen(path, "r");
    if (!f) {
        char msg[128];
        snprintf(msg, sizeof msg, "cannot open include '%s'", path);
        die(g_line, g_col, msg);
    }
    /* Record AFTER the open succeeds: the include search probes candidate
     * paths with fopen and discards the misses, so recording at the probe
     * sites would list headers that were never used and make every -I dir a
     * false rebuild edge. */
    pp_dep_add(path);
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    if (sz < 0) { fclose(f); die(g_line, g_col, "include ftell failed"); }
    rewind(f);
    char *buf = (char *)malloc((size_t)sz + 1);
    if (!buf) { fclose(f); die(g_line, g_col, "out of memory"); }
    if (fread(buf, 1, (size_t)sz, f) != (size_t)sz) {
        free(buf); fclose(f);
        die(g_line, g_col, "short read on include");
    }
    buf[sz] = '\0';
    fclose(f);
    sz = splice_line_continuations(buf, (int)sz);
    *out_len = (int)sz;
    return buf;
}

int
pp_macro_lookup(const char *name, int name_len)
{
    /* T2-1 rider: one O(1) canonicalization probe, then pointer scans. */
    const char *cn = lex_intern_ident(name, name_len);
    for (int i = 0; i < g_pp_n_macros; i++) {
        if (!g_pp_macros[i].live) continue;
        if (g_pp_macros[i].name == cn) return i;
    }
    return -1;
}

int
peek_ch(void)
{
    if (g_pos >= g_src_len) return -1;
    return (unsigned char)g_src[g_pos];
}

int
adv_ch(void)
{
    int c = peek_ch();
    if (c < 0) return -1;
    g_pos++;
    if (c == '\n') { g_line++; g_col = 1; }
    else g_col++;
    return c;
}

/* lint's VARARGSn: a comment that is exactly `VARARGS' or `VARARGSn' says
 * the next function definition takes a variable number of arguments after its
 * first n (none for a bare VARARGS).  2.11BSD marks its forwarders with it --
 * fsck's pwarn, pfatal and errexit hand their int parameters to printf -- and
 * the call has to leave those arguments at their own width (walk_call_args).
 * Text around the word, as in a block comment that mentions it, is not the
 * directive. */
static void
lint_varargs(int b, int e)
{
    while (b < e && (g_src[b] == ' ' || g_src[b] == '\t')) b++;
    while (e > b && (g_src[e - 1] == ' ' || g_src[e - 1] == '\t')) e--;
    if (e - b < 7 || memcmp(g_src + b, "VARARGS", 7) != 0)
        return;
    int n = 0;
    for (int i = b + 7; i < e; i++) {
        if (g_src[i] < '0' || g_src[i] > '9') return;
        n = n * 10 + (g_src[i] - '0');
    }
    g_lint_varargs = n;
}

void
skip_ws_and_comments(void)
{
    for (;;) {
        int c = peek_ch();
        if (c < 0) return;
        if (c == ' ' || c == '\t' || c == '\r' || c == '\n' ||
            c == '\f' || c == '\v') {
            /* \f (form feed, 0x0c) + \v (vertical tab) are C whitespace.  BSD
             * sources are peppered with ^L page breaks (telnet.c: 19); fcc
             * previously died "unexpected character (0x0c)". */
            adv_ch();
        } else if (c == '/' && g_pos + 1 < g_src_len &&
                   g_src[g_pos + 1] == '/') {
            /* Line comment. */
            while ((c = peek_ch()) >= 0 && c != '\n') adv_ch();
        } else if (c == '/' && g_pos + 1 < g_src_len &&
                   g_src[g_pos + 1] == '*') {
            int start_line = g_line, start_col = g_col;
            adv_ch(); adv_ch();
            int body0 = g_pos;
            for (;;) {
                int d = peek_ch();
                if (d < 0) die(start_line, start_col,
                               "unterminated /* comment");
                adv_ch();
                if (d == '*' && peek_ch() == '/') { adv_ch(); break; }
            }
            lint_varargs(body0, g_pos - 2);
        } else {
            return;
        }
    }
}

/* B-6: finalize a floating-point literal.  num_start is the offset of the
 * first character of the numeric lexeme (a digit, or a leading '.').  On
 * entry g_pos points at the tail to consume (a '.', or an 'e'/'E' exponent
 * for digit-then-exponent forms like 1e3).  fcc runs on the host, so the
 * IEEE-754 single bit pattern is computed with C strtof and carried in
 * value (low 16) / value_hi (high 16), exactly like a long literal.  K&R
 * A.2.5.3: "The type is determined by the suffix; F or f makes it float, L
 * or l makes it long double, otherwise it is double."  Double and long
 * double are one 64-bit type, so every constant without an F is read with
 * strtod into dval as well, and is_dbl says to use it. */
static void
lex_float_lit(size_t num_start)
{
    if (peek_ch() == '.') {
        adv_ch();
        while (peek_ch() >= '0' && peek_ch() <= '9') adv_ch();
    }
    if (peek_ch() == 'e' || peek_ch() == 'E') {
        adv_ch();
        if (peek_ch() == '+' || peek_ch() == '-') adv_ch();
        if (!(peek_ch() >= '0' && peek_ch() <= '9'))
            die(g_cur.line, g_cur.col, "malformed float exponent");
        while (peek_ch() >= '0' && peek_ch() <= '9') adv_ch();
    }
    {
        int s = peek_ch();
        g_cur.is_dbl = !(s == 'f' || s == 'F');
        if (s == 'f' || s == 'F' || s == 'l' || s == 'L') adv_ch();
    }
    {
        char tmp[64];
        size_t len = g_pos - num_start;
        float f;
        unsigned int bits;
        if (len >= sizeof tmp) len = sizeof tmp - 1;
        memcpy(tmp, g_src + num_start, len);
        tmp[len] = '\0';
        f = strtof(tmp, NULL);
        memcpy(&bits, &f, 4);
        g_cur.dval     = strtod(tmp, NULL);
        g_cur.kind     = TOK_FLOAT_LIT;
        g_cur.value    = bits & 0xFFFFu;
        g_cur.value_hi = (bits >> 16) & 0xFFFFu;
        g_cur.is_long  = 0;
    }
}

/* --- T2-2 token-level #if evaluator --------------------------------
 * Mirrors the deleted char evaluator on its supported surface exactly:
 * an object-macro body evaluates as a COMPLETE expression (implicit
 * parens); division/modulo by zero -> 0; undefined, funclike, and
 * empty-bodied identifiers -> 0; `defined` never expands its operand;
 * recursive body evaluation capped at depth 16 (beyond -> 0). */
typedef struct { const Tok *t; int n; int i; } EvCur;

static long ev_bin(EvCur *c, int min_prec);

static const Tok *
ev_peek(EvCur *c)
{
    return (c->i < c->n) ? &c->t[c->i] : NULL;
}

static long
pp_eval_toks(const Tok *t, int n)
{
    EvCur c;
    c.t = t; c.n = n; c.i = 0;
    return ev_bin(&c, 0);
}

static long
ev_atom(EvCur *c)
{
    const Tok *tk = ev_peek(c);
    if (!tk) return 0;
    if (tk->kind == TOK_LPAREN) {
        c->i++;
        long v = ev_bin(c, 0);
        tk = ev_peek(c);
        if (tk && tk->kind == TOK_RPAREN) c->i++;
        return v;
    }
    if (tk->kind == TOK_INT_LIT || tk->kind == TOK_CHAR_LIT) {
        c->i++;
        return (long)(((unsigned long)tk->value_hi << 16) | tk->value);
    }
    if (tk->kind == TOK_FLOAT_LIT) {
        unsigned int bits = ((unsigned)tk->value_hi << 16) | tk->value;
        float f;
        c->i++;
        memcpy(&f, &bits, 4);
        return (long)f;
    }
    if (tk->kind == TOK_IDENT) {
        c->i++;
        if (tk->id_len == 7 && memcmp(tk->id_ptr, "defined", 7) == 0) {
            int paren = 0;
            long v = 0;
            const Tok *op = ev_peek(c);
            if (op && op->kind == TOK_LPAREN) { paren = 1; c->i++; op = ev_peek(c); }
            if (op && op->kind == TOK_IDENT) {
                v = pp_macro_lookup(op->id_ptr, op->id_len) >= 0 ? 1 : 0;
                c->i++;
            }
            if (paren) {
                op = ev_peek(c);
                if (op && op->kind == TOK_RPAREN) c->i++;
            }
            return v;
        }
        {
            int midx = pp_macro_lookup(tk->id_ptr, tk->id_len);
            if (midx >= 0 && !g_pp_macros[midx].is_funclike &&
                g_pp_macros[midx].n_body_toks > 0 && g_pp_eval_depth < 16) {
                long v;
                g_pp_eval_depth++;
                v = pp_eval_toks(g_pp_macros[midx].body_toks,
                                 g_pp_macros[midx].n_body_toks);
                g_pp_eval_depth--;
                return v;
            }
        }
        return 0;   /* undefined / funclike / empty-bodied identifier */
    }
    return 0;       /* non-atom token: NOT consumed (mirrors the char atom;
                     * ev_bin's operator probe on the same token stops the
                     * parse, so garbage evaluates 0 instead of looping) */
}

static long
ev_unary(EvCur *c)
{
    const Tok *tk = ev_peek(c);
    if (!tk) return 0;
    if (tk->kind == TOK_BANG)  { c->i++; return !ev_unary(c); }
    if (tk->kind == TOK_TILDE) { c->i++; return ~ev_unary(c); }
    if (tk->kind == TOK_MINUS) { c->i++; return -ev_unary(c); }
    if (tk->kind == TOK_PLUS)  { c->i++; return  ev_unary(c); }
    return ev_atom(c);
}

static int
ev_op_prec(const Tok *tk, int *op)
{
    switch (tk->kind) {
        case TOK_PIPEPIPE: *op = 'O'; return 1;
        case TOK_AMPAMP:   *op = 'A'; return 2;
        case TOK_PIPE:     *op = '|'; return 3;
        case TOK_CARET:    *op = '^'; return 4;
        case TOK_AMP:      *op = '&'; return 5;
        case TOK_EQEQ:     *op = 'E'; return 6;
        case TOK_NE:       *op = 'N'; return 6;
        case TOK_LE:       *op = 'l'; return 7;
        case TOK_GE:       *op = 'g'; return 7;
        case TOK_LT:       *op = '<'; return 7;
        case TOK_GT:       *op = '>'; return 7;
        case TOK_LSHIFT:   *op = 'L'; return 8;
        case TOK_RSHIFT:   *op = 'R'; return 8;
        case TOK_PLUS:     *op = '+'; return 9;
        case TOK_MINUS:    *op = '-'; return 9;
        case TOK_STAR:     *op = '*'; return 10;
        case TOK_SLASH:    *op = '/'; return 10;
        case TOK_PERCENT:  *op = '%'; return 10;
        default:           return 0;
    }
}

long
pp_apply_op(int op, long a, long b)
{
    switch (op) {
        case 'O': return a || b; case 'A': return a && b;
        case '|': return a | b;  case '^': return a ^ b; case '&': return a & b;
        case 'E': return a == b; case 'N': return a != b;
        case 'l': return a <= b; case 'g': return a >= b;
        case '<': return a < b;  case '>': return a > b;
        case 'L': return a << b; case 'R': return a >> b;
        case '+': return a + b;  case '-': return a - b;
        case '*': return a * b;
        case '/': return b ? a / b : 0;
        case '%': return b ? a % b : 0;
    }
    return 0;
}

static long
ev_bin(EvCur *c, int min_prec)
{
    long lhs = ev_unary(c);
    for (;;) {
        const Tok *tk = ev_peek(c);
        int op, prec;
        if (!tk) break;
        prec = ev_op_prec(tk, &op);
        if (prec == 0 || prec < min_prec) break;
        c->i++;
        {
            long rhs = ev_bin(c, prec + 1);   /* left-assoc via prec+1 */
            lhs = pp_apply_op(op, lhs, rhs);
        }
    }
    return lhs;
}

/* Tokenize an #if/#elif expression line and evaluate it.  Called ONLY
 * when the arm's guard says it will be evaluated (an inactive arm's
 * expression is consumed as text and never tokenized — un-lexable
 * expressions in dead arms stay legal, as before). */
static long
pp_eval_expr_text(const char *s)
{
    int n = 0;
    Tok *t = pp_tokenize_text(s, (int)strlen(s), &n);
    long v;
    g_pp_eval_depth = 0;
    v = pp_eval_toks(t, n);
    free(t);
    return v;
}

static void
scan_tok(void)
{
    /* Skip lines while in inactive conditional branch.  PP directives
     * (ifdef / ifndef / else / endif) are still recognized so the cond
     * stack stays balanced and can flip back to active.  Raw mode never
     * consults the cond stack: an #elif expression is tokenized while the
     * chain's CURRENT arm is inactive (only the parent must be active). */
    while (!g_pp_raw_mode && g_pp_cond[g_pp_cond_top].active == 0) {
        /* Skip whitespace at line start. */
        while (peek_ch() == ' ' || peek_ch() == '\t') adv_ch();
        int sc = peek_ch();
        if (sc < 0) {
            /* EOF while skipping: an unbalanced #if leaks to the includer
             * (the cond stack is global), which resumes skipping its own
             * lines — same net behavior as the old frame pop. */
            g_cur.kind = TOK_EOF; return;
        }
        if (sc == '#' && g_col == 1) {
            /* Process the directive — falls through to the # block
             * below by exiting this skip loop. */
            break;
        }
        /* Skip to end of line. */
        while (peek_ch() >= 0 && peek_ch() != '\n') adv_ch();
        if (peek_ch() == '\n') adv_ch();
    }
    skip_ws_and_comments();
    g_cur.line     = g_line;
    g_cur.col      = g_col;
    g_cur.file     = g_cur_path;
    g_cur.lint_varargs = g_lint_varargs;   /* the marker, if one came before */
    g_lint_varargs = -1;
    g_cur.value_hi = 0;        /* M20: reset per-token */
    g_cur.is_long  = 0;
    g_cur.value2   = 0;        /* long long words, and its flag */
    g_cur.value3   = 0;
    g_cur.is_llong = 0;
    g_cur.is_dbl = 0;
    int c = peek_ch();
    if (c < 0) {
        /* End of the current buffer.  Includes are tokenized recursively
         * (stage c) — EOF simply ends this buffer's pass. */
        g_cur.kind = TOK_EOF; return;
    }

    /* Preprocessor directive at line start (raw mode: '#' is just an
     * unexpected character — bodies/args/exprs contain no directives). */
    if (c == '#' && g_col == 1 && !g_pp_raw_mode) {
        adv_ch();   /* consume # */
        /* Read directive name. */
        while (peek_ch() == ' ' || peek_ch() == '\t') adv_ch();
        char dir[16]; int dl = 0;
        while (peek_ch() >= 'a' && peek_ch() <= 'z' && dl < 15) {
            dir[dl++] = adv_ch();
        }
        dir[dl] = '\0';

        /* Null directive: a `#` with no directive name (ISO C 6.10.7) — bare
         * `#` alone on a line, optionally followed by whitespace/comment.  The
         * 2.11BSD Bourne shell uses bare `#` lines as separators throughout.
         * A no-op; also harmlessly swallows a GNU line-marker `# 123 "f"` (the
         * digit is not [a-z], so the name reads empty). */
        if (dl == 0) {
            while (peek_ch() >= 0 && peek_ch() != '\n') adv_ch();
            if (peek_ch() == '\n') adv_ch();
            scan_tok();
            return;
        }

        /* If we're inside an inactive conditional branch, only allow
         * the cond-control directives through.  Otherwise #define
         * etc. in the false branch would still execute, leaking
         * bindings from the wrong arm. */
        if (g_pp_cond[g_pp_cond_top].active == 0) {
            int is_cond = (strcmp(dir, "ifdef")  == 0 ||
                           strcmp(dir, "ifndef") == 0 ||
                           strcmp(dir, "if")     == 0 ||
                           strcmp(dir, "elif")   == 0 ||
                           strcmp(dir, "else")   == 0 ||
                           strcmp(dir, "endif")  == 0);
            if (!is_cond) {
                /* Skip rest of line. */
                while (peek_ch() >= 0 && peek_ch() != '\n') adv_ch();
                if (peek_ch() == '\n') adv_ch();
                scan_tok();
                return;
            }
        }

        if (strcmp(dir, "include") == 0) {
            while (peek_ch() == ' ' || peek_ch() == '\t') adv_ch();
            int open_ch = peek_ch();
            int is_sys = 0;
            int close_ch;
            if (open_ch == '"') {
                close_ch = '"';
            } else if (open_ch == '<') {
                is_sys = 1;
                close_ch = '>';
            } else {
                die(g_line, g_col, "expected '\"' or '<' after #include");
            }
            adv_ch();   /* consume opening delimiter */
            char path[256]; int pl = 0;
            while (peek_ch() >= 0 && peek_ch() != close_ch &&
                   peek_ch() != '\n' && pl < 255) {
                path[pl++] = adv_ch();
            }
            path[pl] = '\0';
            if (peek_ch() != close_ch)
                die(g_line, g_col, "unterminated #include path");
            adv_ch();   /* consume closing delimiter */
            /* Consume the rest of the line -- but a trailing block comment
             * may CONTINUE onto following lines, and this used to stop dead at
             * the first '\n'.  The continuation was then lexed as CODE, so an
             * ordinary apostrophe in the prose ("the pointer's bank") became an
             * unterminated char literal and the compile died pointing at a
             * comment.  It bit twice on 2026-07-26 and the standing workaround
             * was "keep comments off #include lines", which is exactly the kind
             * of artificial reject worth deleting instead.  Track the comment
             * state and consume through its terminator. */
            int in_cmt = 0;
            for (;;) {
                int c = peek_ch();
                if (c < 0) break;
                if (in_cmt) {
                    adv_ch();
                    if (c == '*' && peek_ch() == '/') { adv_ch(); in_cmt = 0; }
                    continue;
                }
                if (c == '\n') break;
                adv_ch();
                if (c == '/' && peek_ch() == '*') { adv_ch(); in_cmt = 1; }
            }
            if (peek_ch() == '\n') adv_ch();
            char full[256];
            if (path[0] == '/') {
                /* An absolute name is opened as it stands, in either form:
                 * there is nothing to search, and prefixing a directory to it
                 * names a file that does not exist. */
                if (pl + 1 > (int)sizeof full)
                    die(g_line, g_col, "include path too long");
                memcpy(full, path, (size_t)pl + 1);
            } else if (is_sys) {
                /* System include: search extra -I dirs first, then the
                 * binary-relative include dir. */
                int found = 0;
                for (int k = 0; k < g_n_extra_inc_dirs && !found; k++) {
                    int dl = (int)strlen(g_extra_inc_dirs[k]);
                    if (dl + pl + 2 > (int)sizeof full) continue;
                    snprintf(full, sizeof full, "%s/%s",
                             g_extra_inc_dirs[k], path);
                    FILE *probe = fopen(full, "r");
                    if (probe) { fclose(probe); found = 1; }
                }
                if (!found && g_sys_inc_dir[0]) {
                    int dl = (int)strlen(g_sys_inc_dir);
                    if (dl + pl + 2 > (int)sizeof full)
                        die(g_line, g_col, "include path too long");
                    snprintf(full, sizeof full, "%s/%s",
                             g_sys_inc_dir, path);
                    FILE *probe = fopen(full, "r");
                    if (probe) { fclose(probe); found = 1; }
                }
                if (!found) {
                    char msg[160];
                    snprintf(msg, sizeof msg,
                             "system include '<%s>' not found", path);
                    die(g_line, g_col, msg);
                }
            } else {
                /* Quoted include: per C, search the current file's
                 * directory FIRST, then fall back to the -I search dirs
                 * (and the binary-relative sys dir).  The fallback matters
                 * when a project keeps headers in a separate include dir
                 * (e.g. stevie's machine-layer fgx.h in -I include). */
                const char *cur = g_cur_path;
                const char *slash = NULL;
                if (cur != NULL) {
                    for (const char *p = cur; *p; p++)
                        if (*p == '/' || *p == '\\') slash = p;
                }
                if (slash != NULL) {
                    int dlen = (int)(slash - cur + 1);
                    if (dlen + pl + 1 > (int)sizeof full)
                        die(g_line, g_col, "include path too long");
                    memcpy(full, cur, (size_t)dlen);
                    full[dlen] = '\0';
                    strcat(full, path);
                } else {
                    strncpy(full, path, sizeof full - 1);
                    full[sizeof full - 1] = '\0';
                }
                /* If not found relative to the current file, fall back to
                 * the -I dirs, then the binary-relative sys include dir. */
                FILE *probe = fopen(full, "r");
                if (probe) {
                    fclose(probe);
                } else {
                    int found = 0;
                    for (int k = 0; k < g_n_extra_inc_dirs && !found; k++) {
                        int dl = (int)strlen(g_extra_inc_dirs[k]);
                        if (dl + pl + 2 > (int)sizeof full) continue;
                        snprintf(full, sizeof full, "%s/%s",
                                 g_extra_inc_dirs[k], path);
                        FILE *p2 = fopen(full, "r");
                        if (p2) { fclose(p2); found = 1; }
                    }
                    if (!found && g_sys_inc_dir[0]) {
                        int dl = (int)strlen(g_sys_inc_dir);
                        if (dl + pl + 2 <= (int)sizeof full) {
                            snprintf(full, sizeof full, "%s/%s",
                                     g_sys_inc_dir, path);
                            FILE *p3 = fopen(full, "r");
                            if (p3) { fclose(p3); found = 1; }
                        }
                    }
                    /* If still not found, leave `full` as the
                     * current-file-relative path so pp_read_file emits the
                     * canonical "cannot open include" error below. */
                }
            }
            /* Stage c: recursively tokenize the included file into the
             * token vector, then resume this buffer.  `full` lives on
             * this frame across the recursion, so nested relative
             * includes resolve against it (no strdup needed). */
            if (g_inc_depth + 1 >= PP_MAX_INCLUDE_DEPTH)
                die(g_line, g_col, "#include nesting exceeds 16");
            {
                int ilen = 0;
                char *ibuf = pp_read_file(full, &ilen);
                const char *save_src = g_src, *save_path = g_cur_path;
                size_t save_len = g_src_len, save_pos = g_pos;
                int save_line = g_line, save_col = g_col;
                lex_set_source(ibuf, ilen, full);
                g_inc_depth++;
                pp_tokenize_buffer();
                g_inc_depth--;
                g_src = save_src; g_src_len = save_len; g_pos = save_pos;
                g_line = save_line; g_col = save_col;
                g_cur_path = save_path;
                free(ibuf);
            }
            scan_tok();
            return;
        }

        if (strcmp(dir, "define") == 0) {
            while (peek_ch() == ' ' || peek_ch() == '\t') adv_ch();
            char mn[32]; int ml = 0;
            while (peek_ch() >= 0 && ml < 31 &&
                   (is_ident_start(peek_ch()) || is_ident_cont(peek_ch()))) {
                mn[ml++] = (char)adv_ch();
            }
            mn[ml] = '\0';
            if (ml == 0) die(g_line, g_col, "expected name after #define");
            /* Function-like macro: `name(p1, p2, ...)` with NO whitespace
             * between name and `(` (per C standard — `#define X (1)` is
             * an object-like macro whose body is "(1)"). */
            int is_funclike = 0;
            int n_params = 0;
            int is_variadic = 0;
            const char *params[PP_MAX_FN_PARAMS];
            if (peek_ch() == '(') {
                is_funclike = 1;
                adv_ch();  /* consume '(' */
                while (peek_ch() == ' ' || peek_ch() == '\t') adv_ch();
                if (peek_ch() != ')') {
                    for (;;) {
                        while (peek_ch() == ' ' || peek_ch() == '\t') adv_ch();
                        /* `...` as a param token marks the macro variadic.
                         * Must be the last entry in the param list. */
                        if (peek_ch() == '.') {
                            adv_ch();
                            if (peek_ch() != '.' || (adv_ch(), peek_ch() != '.'))
                                die(g_line, g_col,
                                    "expected '...' in variadic #define");
                            adv_ch();  /* consume third '.' */
                            is_variadic = 1;
                            while (peek_ch() == ' ' || peek_ch() == '\t') adv_ch();
                            if (peek_ch() != ')')
                                die(g_line, g_col,
                                    "'...' must be the last param in variadic #define");
                            break;
                        }
                        if (n_params >= PP_MAX_FN_PARAMS)
                            die(g_line, g_col,
                                "too many params in function-like #define (max 8)");
                        char pn[32]; int pl = 0;
                        while (peek_ch() >= 0 && pl < 31 &&
                               (is_ident_start(peek_ch()) || is_ident_cont(peek_ch()))) {
                            pn[pl++] = (char)adv_ch();
                        }
                        if (pl == 0)
                            die(g_line, g_col,
                                "expected parameter name in function-like #define");
                        pn[pl] = '\0';
                        params[n_params] = lex_intern_ident(pn, pl);
                        n_params++;
                        while (peek_ch() == ' ' || peek_ch() == '\t') adv_ch();
                        if (peek_ch() == ',') { adv_ch(); continue; }
                        if (peek_ch() == ')') break;
                        die(g_line, g_col,
                            "expected ',' or ')' in function-like #define params");
                    }
                }
                if (peek_ch() != ')')
                    die(g_line, g_col, "expected ')' in function-like #define");
                adv_ch();  /* consume ')' */
            }
            while (peek_ch() == ' ' || peek_ch() == '\t') adv_ch();
            char body[PP_MAX_MACRO_BODY]; int bl = 0;
            while (peek_ch() >= 0 && peek_ch() != '\n' &&
                   bl < PP_MAX_MACRO_BODY - 1) {
                /* A block comment may span newlines; per the C standard it is
                 * replaced by a single space and must NOT terminate the macro
                 * body at its embedded newline.  Mirror skip_ws_and_comments():
                 * a comment opened on the #define line but closed on the next
                 * line would otherwise leak its continuation out as a stray
                 * top-level token. */
                if (peek_ch() == '/' && g_pos + 1 < g_src_len &&
                    g_src[g_pos + 1] == '*') {
                    int cstart_line = g_line, cstart_col = g_col;
                    adv_ch(); adv_ch();
                    for (;;) {
                        int d = peek_ch();
                        if (d < 0) die(cstart_line, cstart_col,
                                       "unterminated /* comment");
                        adv_ch();
                        if (d == '*' && peek_ch() == '/') { adv_ch(); break; }
                    }
                    body[bl++] = ' ';
                    continue;
                }
                /* Line comment: skip to (not past) end of line; the trailing
                 * newline still terminates the macro body. */
                if (peek_ch() == '/' && g_pos + 1 < g_src_len &&
                    g_src[g_pos + 1] == '/') {
                    while (peek_ch() >= 0 && peek_ch() != '\n') adv_ch();
                    continue;
                }
                body[bl++] = (char)adv_ch();
            }
            /* Overflow is FAIL-LOUD, not a silent truncation: a body clipped
             * mid-token used to leave a garbled macro that died elsewhere as
             * "expected type" (joe's `outatr').  If the loop stopped with more
             * body still on the (continuation-spliced) line, the buffer is too
             * small -- raise PP_MAX_MACRO_BODY rather than ship a cut macro. */
            if (bl >= PP_MAX_MACRO_BODY - 1 &&
                peek_ch() >= 0 && peek_ch() != '\n')
                die(g_line, g_col,
                    "macro body too long (raise PP_MAX_MACRO_BODY)");
            body[bl] = '\0';
            while (bl > 0 && (body[bl-1] == ' ' || body[bl-1] == '\t' ||
                              body[bl-1] == '\r')) {
                body[--bl] = '\0';
            }
            if (peek_ch() == '\n') adv_ch();
            int idx = pp_macro_lookup(mn, ml);
            if (idx < 0) {
                FCC_GROW(g_pp_macros, g_pp_n_macros, g_pp_macros_cap, PpMacro);
                idx = g_pp_n_macros++;
            }
            g_pp_macros[idx].name = lex_intern_ident(mn, ml);
            g_pp_macros[idx].live = 1;
            g_pp_macros[idx].is_funclike = is_funclike;
            g_pp_macros[idx].n_params = n_params;
            g_pp_macros[idx].is_variadic = is_variadic;
            for (int p = 0; p < n_params; p++)
                g_pp_macros[idx].params[p] = params[p];
            pp_macro_set_body(&g_pp_macros[idx], body, bl);
            scan_tok();
            return;
        }

        if (strcmp(dir, "ifdef") == 0 || strcmp(dir, "ifndef") == 0) {
            int is_ifdef = (strcmp(dir, "ifdef") == 0);
            while (peek_ch() == ' ' || peek_ch() == '\t') adv_ch();
            char mn[32]; int ml = 0;
            while (peek_ch() >= 0 && ml < 31 &&
                   (is_ident_start(peek_ch()) || is_ident_cont(peek_ch()))) {
                mn[ml++] = (char)adv_ch();
            }
            mn[ml] = '\0';
            while (peek_ch() >= 0 && peek_ch() != '\n') adv_ch();
            if (peek_ch() == '\n') adv_ch();
            int defined = (pp_macro_lookup(mn, ml) >= 0);
            int cond = is_ifdef ? defined : !defined;
            if (g_pp_cond_top + 1 >= PP_MAX_COND_DEPTH)
                die(g_line, g_col, "#ifdef nesting exceeds 16");
            int parent_active = g_pp_cond[g_pp_cond_top].active;
            g_pp_cond_top++;
            g_pp_cond[g_pp_cond_top].parent_active = parent_active;
            g_pp_cond[g_pp_cond_top].active        = parent_active && cond;
            g_pp_cond[g_pp_cond_top].saw_else      = 0;
            g_pp_cond[g_pp_cond_top].taken         = parent_active && cond;
            scan_tok();
            return;
        }

        /* E-1: #if EXPR / #elif EXPR — evaluate the constant expression. */
        if (strcmp(dir, "if") == 0 || strcmp(dir, "elif") == 0) {
            int is_elif = (strcmp(dir, "elif") == 0);
            while (peek_ch() == ' ' || peek_ch() == '\t') adv_ch();
            char expr[256]; int el = 0;
            while (peek_ch() >= 0 && peek_ch() != '\n' && el < 255)
                expr[el++] = (char)adv_ch();
            expr[el] = '\0';
            if (peek_ch() == '\n') adv_ch();
            if (is_elif) {
                if (g_pp_cond_top == 0)
                    die(g_line, g_col, "#elif with no matching #if");
                if (g_pp_cond[g_pp_cond_top].saw_else)
                    die(g_line, g_col, "#elif after #else");
                int p = g_pp_cond[g_pp_cond_top].parent_active;
                int already = g_pp_cond[g_pp_cond_top].taken;
                int cond = (!already && p) ? (pp_eval_expr_text(expr) != 0) : 0;
                g_pp_cond[g_pp_cond_top].active = p && !already && cond;
                if (g_pp_cond[g_pp_cond_top].active)
                    g_pp_cond[g_pp_cond_top].taken = 1;
            } else {
                if (g_pp_cond_top + 1 >= PP_MAX_COND_DEPTH)
                    die(g_line, g_col, "#if nesting exceeds 16");
                int parent_active = g_pp_cond[g_pp_cond_top].active;
                int cond = parent_active ? (pp_eval_expr_text(expr) != 0) : 0;
                g_pp_cond_top++;
                g_pp_cond[g_pp_cond_top].parent_active = parent_active;
                g_pp_cond[g_pp_cond_top].active        = parent_active && cond;
                g_pp_cond[g_pp_cond_top].saw_else      = 0;
                g_pp_cond[g_pp_cond_top].taken         = parent_active && cond;
            }
            scan_tok();
            return;
        }

        if (strcmp(dir, "else") == 0) {
            if (g_pp_cond_top == 0)
                die(g_line, g_col, "#else with no matching #if*");
            if (g_pp_cond[g_pp_cond_top].saw_else)
                die(g_line, g_col, "duplicate #else");
            g_pp_cond[g_pp_cond_top].saw_else = 1;
            int p = g_pp_cond[g_pp_cond_top].parent_active;
            /* E-1: else is taken iff no prior #if/#elif arm was taken. */
            g_pp_cond[g_pp_cond_top].active = p && !g_pp_cond[g_pp_cond_top].taken;
            g_pp_cond[g_pp_cond_top].taken = 1;
            while (peek_ch() >= 0 && peek_ch() != '\n') adv_ch();
            if (peek_ch() == '\n') adv_ch();
            scan_tok();
            return;
        }

        if (strcmp(dir, "endif") == 0) {
            if (g_pp_cond_top == 0)
                die(g_line, g_col, "#endif with no matching #if*");
            g_pp_cond_top--;
            while (peek_ch() >= 0 && peek_ch() != '\n') adv_ch();
            if (peek_ch() == '\n') adv_ch();
            scan_tok();
            return;
        }

        if (strcmp(dir, "undef") == 0) {
            while (peek_ch() == ' ' || peek_ch() == '\t') adv_ch();
            char mn[32]; int ml = 0;
            while (peek_ch() >= 0 && ml < 31 &&
                   (is_ident_start(peek_ch()) || is_ident_cont(peek_ch()))) {
                mn[ml++] = (char)adv_ch();
            }
            mn[ml] = '\0';
            while (peek_ch() >= 0 && peek_ch() != '\n') adv_ch();
            if (peek_ch() == '\n') adv_ch();
            int idx = pp_macro_lookup(mn, ml);
            if (idx >= 0) g_pp_macros[idx].live = 0;
            scan_tok();
            return;
        }

        /* E-2 (queue 9): #error dies with the line's text; #pragma and
         * #line are consumed as no-ops (standard-conformant ignore).
         * Inactive branches never reach here (non-cond directives are
         * line-skipped above), so `#if 0 ... #error ... #endif` is inert. */
        if (strcmp(dir, "error") == 0) {
            char emsg[160]; int el = 0;
            while (peek_ch() == ' ' || peek_ch() == '\t') adv_ch();
            while (peek_ch() >= 0 && peek_ch() != '\n' &&
                   el < (int)sizeof emsg - 1)
                emsg[el++] = (char)adv_ch();
            emsg[el] = '\0';
            {
                char full_msg[200];
                snprintf(full_msg, sizeof full_msg, "#error %s", emsg);
                die(g_line, g_col, full_msg);
            }
        }
        if (strcmp(dir, "pragma") == 0 || strcmp(dir, "line") == 0) {
            while (peek_ch() >= 0 && peek_ch() != '\n') adv_ch();
            if (peek_ch() == '\n') adv_ch();
            scan_tok();
            return;
        }
        /* #warning (C23/GNU): print the message to stderr and CONTINUE, unlike
         * #error which halts.  joe path.c's `#ifndef PATH_MAX / #warning ...`
         * -- inert once PATH_MAX is defined, but a compiler that rejects the
         * directive outright cannot even reach the definition. */
        if (strcmp(dir, "warning") == 0) {
            char wmsg[160]; int wl = 0;
            while (peek_ch() == ' ' || peek_ch() == '\t') adv_ch();
            while (peek_ch() >= 0 && peek_ch() != '\n' &&
                   wl < (int)sizeof wmsg - 1)
                wmsg[wl++] = (char)adv_ch();
            wmsg[wl] = '\0';
            fprintf(stderr, "%s:%d:%d: warning: #warning %s\n",
                    g_input_path, g_line, g_col, wmsg);
            /* The rest of a message longer than wmsg is still the DIRECTIVE's.
             * Without this drain the capture loop stops on length, the newline
             * test below fails, and scan_tok resumes in the middle of the
             * message -- the tail is lexed as C.  #pragma just below drains the
             * same way; #error can truncate because it dies here. */
            while (peek_ch() >= 0 && peek_ch() != '\n') adv_ch();
            if (peek_ch() == '\n') adv_ch();
            scan_tok();
            return;
        }

        char msg[64];
        snprintf(msg, sizeof msg, "unknown preprocessor directive '#%s'", dir);
        die(g_line, g_col, msg);
    }

    if (c == '(') { adv_ch(); g_cur.kind = TOK_LPAREN; return; }
    if (c == ')') { adv_ch(); g_cur.kind = TOK_RPAREN; return; }
    if (c == '{') { adv_ch(); g_cur.kind = TOK_LBRACE; return; }
    if (c == '}') { adv_ch(); g_cur.kind = TOK_RBRACE; return; }
    if (c == ';') { adv_ch(); g_cur.kind = TOK_SEMI;   return; }
    if (c == '+') {
        adv_ch();
        if (peek_ch() == '+') { adv_ch(); g_cur.kind = TOK_PLUSPLUS;   return; }
        if (peek_ch() == '=') { adv_ch(); g_cur.kind = TOK_PLUSEQ;     return; }
        g_cur.kind = TOK_PLUS;
        return;
    }
    if (c == '-') {
        adv_ch();
        if (peek_ch() == '-') { adv_ch(); g_cur.kind = TOK_MINUSMINUS; return; }
        if (peek_ch() == '>') { adv_ch(); g_cur.kind = TOK_ARROW;      return; }
        if (peek_ch() == '=') { adv_ch(); g_cur.kind = TOK_MINUSEQ;    return; }
        g_cur.kind = TOK_MINUS;
        return;
    }
    if (c == '*') {
        adv_ch();
        if (peek_ch() == '=') { adv_ch(); g_cur.kind = TOK_STAREQ;     return; }
        g_cur.kind = TOK_STAR;
        return;
    }
    if (c == '/') {
        adv_ch();
        if (peek_ch() == '=') { adv_ch(); g_cur.kind = TOK_SLASHEQ;    return; }
        g_cur.kind = TOK_SLASH;
        return;
    }
    if (c == '%') {
        adv_ch();
        if (peek_ch() == '=') { adv_ch(); g_cur.kind = TOK_PERCENTEQ;  return; }
        g_cur.kind = TOK_PERCENT;
        return;
    }
    if (c == '=') {
        adv_ch();
        if (peek_ch() == '=') { adv_ch(); g_cur.kind = TOK_EQEQ; }
        else                    g_cur.kind = TOK_EQ;
        return;
    }
    if (c == ',') { adv_ch(); g_cur.kind = TOK_COMMA;  return; }
    if (c == '.') {
        /* B-6: leading-dot float literal (.5, .25e3) — '.' followed by a digit. */
        if (g_pos + 1 < g_src_len &&
            g_src[g_pos + 1] >= '0' && g_src[g_pos + 1] <= '9') {
            lex_float_lit(g_pos);
            return;
        }
        adv_ch();
        if (peek_ch() == '.') {
            adv_ch();
            if (peek_ch() == '.') {
                adv_ch();
                g_cur.kind = TOK_ELLIPSIS;
                return;
            }
            die(g_cur.line, g_cur.col, "unexpected '..' (need '...' or '.')");
        }
        g_cur.kind = TOK_DOT;
        return;
    }
    if (c == ':') { adv_ch(); g_cur.kind = TOK_COLON;  return; }
    if (c == '?') { adv_ch(); g_cur.kind = TOK_QMARK;  return; }
    if (c == '<') {
        adv_ch();
        if (peek_ch() == '<') {
            adv_ch();
            if (peek_ch() == '=') { adv_ch(); g_cur.kind = TOK_LSHIFTEQ; return; }
            g_cur.kind = TOK_LSHIFT;
            return;
        }
        if (peek_ch() == '=') { adv_ch(); g_cur.kind = TOK_LE; return; }
        g_cur.kind = TOK_LT;
        return;
    }
    if (c == '>') {
        adv_ch();
        if (peek_ch() == '>') {
            adv_ch();
            if (peek_ch() == '=') { adv_ch(); g_cur.kind = TOK_RSHIFTEQ; return; }
            g_cur.kind = TOK_RSHIFT;
            return;
        }
        if (peek_ch() == '=') { adv_ch(); g_cur.kind = TOK_GE; return; }
        g_cur.kind = TOK_GT;
        return;
    }
    if (c == '!') {
        adv_ch();
        if (peek_ch() == '=') { adv_ch(); g_cur.kind = TOK_NE;   return; }
        g_cur.kind = TOK_BANG;
        return;
    }
    if (c == '&') {
        adv_ch();
        if (peek_ch() == '&') { adv_ch(); g_cur.kind = TOK_AMPAMP; return; }
        if (peek_ch() == '=') { adv_ch(); g_cur.kind = TOK_AMPEQ;  return; }
        g_cur.kind = TOK_AMP;
        return;
    }
    if (c == '|') {
        adv_ch();
        if (peek_ch() == '|') { adv_ch(); g_cur.kind = TOK_PIPEPIPE; return; }
        if (peek_ch() == '=') { adv_ch(); g_cur.kind = TOK_PIPEEQ;   return; }
        g_cur.kind = TOK_PIPE;
        return;
    }
    if (c == '^') {
        adv_ch();
        if (peek_ch() == '=') { adv_ch(); g_cur.kind = TOK_CARETEQ; return; }
        g_cur.kind = TOK_CARET;
        return;
    }
    if (c == '~') { adv_ch(); g_cur.kind = TOK_TILDE; return; }
    if (c == '[') { adv_ch(); g_cur.kind = TOK_LBRACKET; return; }
    if (c == ']') { adv_ch(); g_cur.kind = TOK_RBRACKET; return; }

    if (c == '\'') {
        adv_ch();
        int ch = peek_ch();
        if (ch < 0 || ch == '\n')
            die(g_cur.line, g_cur.col, "unterminated char literal");
        if (ch == '\\') {
            adv_ch();
            int esc = peek_ch();
            switch (esc) {
                case 'n':  ch = '\n'; break;
                case 't':  ch = '\t'; break;
                case 'r':  ch = '\r'; break;
                case 'b':  ch = 8;    break;   /* backspace */
                case 'f':  ch = 12;   break;   /* form feed */
                case 'v':  ch = 11;   break;   /* vertical tab */
                case 'a':  ch = 7;    break;   /* bell / alert */
                case '\\': ch = '\\'; break;
                case '\'': ch = '\''; break;
                case '"':  ch = '"';  break;
                case '?':  ch = '?';  break;
                default:
                    if (esc >= '0' && esc <= '7') {
                        /* G16: octal escape \N, \NN, or \NNN (1-3 digits).
                         * ascii.h uses '\000' (NUL), '\033' (ESC), etc. */
                        int oct = esc - '0';
                        for (int d = 0; d < 2; d++) {
                            int nx = (g_pos + 1 < g_src_len)
                                     ? (unsigned char)g_src[g_pos + 1] : -1;
                            if (nx < '0' || nx > '7') break;
                            adv_ch();   /* consume the digit we peeked */
                            oct = (oct << 3) | (nx - '0');
                        }
                        ch = oct & 0xFF;
                    } else if (esc == 'x' || esc == 'X') {
                        /* Hex escape \xNN (1-2 hex digits). */
                        int hex = 0, ndig = 0;
                        for (;;) {
                            int nx = (g_pos + 1 < g_src_len)
                                     ? (unsigned char)g_src[g_pos + 1] : -1;
                            int hv;
                            if (nx >= '0' && nx <= '9')      hv = nx - '0';
                            else if (nx >= 'a' && nx <= 'f') hv = nx - 'a' + 10;
                            else if (nx >= 'A' && nx <= 'F') hv = nx - 'A' + 10;
                            else break;
                            adv_ch();
                            hex = (hex << 4) | hv;
                            if (++ndig == 2) break;
                        }
                        if (ndig == 0)
                            die(g_cur.line, g_cur.col,
                                "\\x used with no hex digits");
                        ch = hex & 0xFF;
                    } else {
                        die(g_cur.line, g_cur.col,
                            "unsupported escape in char literal");
                    }
            }
        }
        adv_ch();
        if (peek_ch() != '\'')
            die(g_cur.line, g_cur.col,
                "expected closing apostrophe in char literal");
        adv_ch();
        g_cur.kind  = TOK_CHAR_LIT;
        g_cur.value = (unsigned)(ch & 0xFF);
        return;
    }

    if (c == '"') {
        adv_ch();
        int n = 0;
        for (;;) {
            int ch = peek_ch();
            if (ch < 0 || ch == '\n')
                die(g_cur.line, g_cur.col, "unterminated string literal");
            if (ch == '"') { adv_ch(); break; }
            if (ch == '\\') {
                adv_ch();
                int esc = peek_ch();
                switch (esc) {
                    case 'n':  ch = '\n'; break;
                    case 't':  ch = '\t'; break;
                    case 'r':  ch = '\r'; break;
                    case 'b':  ch = 8;    break;   /* backspace */
                    case 'f':  ch = 12;   break;   /* form feed */
                    case 'v':  ch = 11;   break;   /* vertical tab */
                    case 'a':  ch = 7;    break;   /* bell / alert */
                    case '\\': ch = '\\'; break;
                    case '"':  ch = '"';  break;
                    case '\'': ch = '\''; break;
                    case '?':  ch = '?';  break;
                    case 'x': {
                        adv_ch();
                        int hi = peek_ch();
                        adv_ch();
                        int lo = peek_ch();
                        int hv = (hi >= '0' && hi <= '9') ? hi - '0'
                               : (hi >= 'a' && hi <= 'f') ? hi - 'a' + 10
                               : (hi >= 'A' && hi <= 'F') ? hi - 'A' + 10 : -1;
                        int lv = (lo >= '0' && lo <= '9') ? lo - '0'
                               : (lo >= 'a' && lo <= 'f') ? lo - 'a' + 10
                               : (lo >= 'A' && lo <= 'F') ? lo - 'A' + 10 : -1;
                        if (hv < 0 || lv < 0)
                            die(g_cur.line, g_cur.col,
                                "bad \\x escape (need two hex digits)");
                        ch = (hv << 4) | lv;
                        break;
                    }
                    default:
                        if (esc >= '0' && esc <= '7') {
                            /* G19: octal escape \N, \NN, or \NNN (1-3 digits),
                             * the string-literal mirror of G16's char fix.
                             * ascii.h uses "\334", term strings use "\033[..." */
                            int oct = esc - '0';
                            for (int d = 0; d < 2; d++) {
                                int nx = (g_pos + 1 < g_src_len)
                                         ? (unsigned char)g_src[g_pos + 1] : -1;
                                if (nx < '0' || nx > '7') break;
                                adv_ch();   /* consume the digit we peeked */
                                oct = (oct << 3) | (nx - '0');
                            }
                            ch = oct & 0xFF;
                        } else {
                            die(g_cur.line, g_cur.col,
                                "unsupported escape in string literal");
                        }
                }
            }
            if (n >= MAX_STR_TOK_LEN - 1)
                die(g_cur.line, g_cur.col,
                    "string literal too long");
            g_str_tok_buf[n++] = (char)(ch & 0xFF);
            adv_ch();
        }
        g_str_tok_buf[n] = '\0';
        g_cur.kind    = TOK_STR_LIT;
        /* T2-2: intern at production — string tokens stored in macro
         * bodies / arg spans must own their bytes (g_str_tok_buf is a
         * shared scratch buffer). */
        g_cur.str_ptr = intern_bytes(g_str_tok_buf, n);
        g_cur.str_len = n;
        return;
    }

    if (c >= '0' && c <= '9') {
        size_t num_start = g_pos;   /* B-6: start of lexeme, for float slice */
        unsigned long lv = 0;
        /* Hex literal: '0x' / '0X' prefix.  Peek requires advancing past
         * the leading '0' first.  Save position so we can roll back if
         * what follows isn't 'x' (e.g. just literal '0'). */
        int is_hex = 0;
        int is_octal = 0;
        /* A decimal digit string too long for 64 bits is refused only once it
         * is known to be an INTEGER constant.  K&R A.2.5.3 makes the digits
         * before a `.' or an exponent "the integer part" of a floating
         * constant, which has no such limit: 4.3BSD-Reno's atof.c writes
         * 5^32 as `23283064365386962890625.'. */
        int dec_overflow = 0;
        if (c == '0') {
            adv_ch();              /* consume '0' */
            int p = peek_ch();
            if (p == 'x' || p == 'X') {
                is_hex = 1;
                adv_ch();          /* consume 'x' */
            } else if (p >= '0' && p <= '7') {
                /* C octal literal: a leading '0' followed by octal digits
                 * (0377 == 255).  Was missing entirely — the digits fell into
                 * the decimal loop below, so `0377` lexed as decimal 377 and
                 * Merlin then took `LDA #377` as $0179, masking od's
                 * `*cc & 0377` to & $79 and mangling its -c char dump. */
                is_octal = 1;
            }
            /* A lone '0', or '0' before '.'/'e' (float) or '8'/'9', stays on
             * the decimal path; lv starts at 0 which is correct there. */
        }
        if (is_hex) {
            int n = 0;
            for (;;) {
                int p = peek_ch();
                int d;
                if (p >= '0' && p <= '9')      d = p - '0';
                else if (p >= 'a' && p <= 'f') d = p - 'a' + 10;
                else if (p >= 'A' && p <= 'F') d = p - 'A' + 10;
                else                            break;
                if (lv >> 60)
                    die(g_cur.line, g_cur.col,
                        "hex literal exceeds 64-bit");
                lv = (lv << 4) | (unsigned)d;
                adv_ch();
                n++;
            }
            if (n == 0) die(g_cur.line, g_cur.col,
                            "hex literal needs at least one digit after 0x");
            c = peek_ch();
        } else if (is_octal) {
            for (;;) {
                int p = peek_ch();
                if (p < '0' || p > '7') break;
                if (lv >> 61)
                    die(g_cur.line, g_cur.col,
                        "octal literal exceeds 64-bit");
                lv = (lv << 3) | (unsigned)(p - '0');
                adv_ch();
            }
            c = peek_ch();
        } else {
            while ((c = peek_ch()) >= '0' && c <= '9') {
                if (lv > (0xFFFFFFFFFFFFFFFFUL - (unsigned)(c - '0')) / 10)
                    dec_overflow = 1;
                lv = lv * 10 + (unsigned)(c - '0');
                adv_ch();
            }
        }
        int has_l_suffix = 0;
        /* B-6: a '.' or an exponent after the integer part => float literal.
         * Decimal only (hex floats are C99, out of scope).  The exponent
         * form is committed only when 'e'/'E' is followed by [+-]?digit, so
         * a stray `3east`-style adjacency stays an int + ident. */
        if (!is_hex && c == '.') {
            lex_float_lit(num_start);
            return;
        }
        if (!is_hex && (c == 'e' || c == 'E')) {
            int n1 = (g_pos + 1 < g_src_len) ? (unsigned char)g_src[g_pos + 1] : 0;
            int n2 = (g_pos + 2 < g_src_len) ? (unsigned char)g_src[g_pos + 2] : 0;
            if ((n1 >= '0' && n1 <= '9') ||
                ((n1 == '+' || n1 == '-') && (n2 >= '0' && n2 <= '9'))) {
                lex_float_lit(num_start);
                return;
            }
        }
        if (dec_overflow)
            die(g_cur.line, g_cur.col, "integer literal exceeds 64-bit");
        /* Integer suffixes: any of U/L in either order + case (U, L, UL,
         * LU, ...).  U marks the literal unsigned (A-1); L forces long. */
        {
            int has_u_suffix = 0;
            for (;;) {
                c = peek_ch();
                if (c == 'L' || c == 'l')      { has_l_suffix++; adv_ch(); }
                else if (c == 'U' || c == 'u') { has_u_suffix = 1; adv_ch(); }
                else break;
            }
            g_cur.kind        = TOK_INT_LIT;
            g_cur.value       = (unsigned)(lv & 0xFFFFu);
            g_cur.value_hi    = (unsigned)((lv >> 16) & 0xFFFFu);
            g_cur.value2      = (unsigned)((lv >> 32) & 0xFFFFu);
            g_cur.value3      = (unsigned)((lv >> 48) & 0xFFFFu);
            /* LONG LONG, the C99 extension: an LL suffix, or a value past the
             * last rung K&R's lists give (unsigned long).  Both lists below
             * then continue with long long and unsigned long long -- appended
             * to K&R's order, which is kept as written. */
            g_cur.is_llong    = (has_l_suffix >= 2 || lv > 0xFFFFFFFFUL);
            if (g_cur.is_llong) {
                g_cur.is_long     = 0;
                g_cur.is_unsigned = has_u_suffix ||
                                    (lv > 0x7FFFFFFFFFFFFFFFUL);
                return;
            }
            /* K&R A.2.5.1 type ladder.  `is_long = lv > 65535, unsigned only
             * from a U suffix` skipped two rungs, and on a 16-bit int that is
             * a silent wrong-VALUE bug, not a pedantic one: 0xFFFF became a
             * SIGNED int, so `long x = 0xFFFF` sign-extended to 0xFFFFFFFF
             * (-1) instead of 65535.  Any bit mask >= 0x8000 assigned to or
             * compared against a long was affected.
             *
             * "If it is unsuffixed and decimal, it has the first of these
             *  types in which its value can be represented: int, long int,
             *  unsigned long int.  If it is unsuffixed, octal or hexadecimal,
             *  it has the first possible of these types: int, unsigned int,
             *  long int, unsigned long int."
             *
             * So `unsigned int` is a rung for octal/hex ONLY -- decimal 40000
             * is a long, while 0x9C40 is an unsigned int.  Both are positive;
             * the old code made both negative ints. */
            {
                int uint_rung = (is_hex || is_octal);
                int lg, un;
                if (has_l_suffix) {                     /* L / UL */
                    lg = 1;
                    un = has_u_suffix || (lv > 0x7FFFFFFFUL);
                } else if (has_u_suffix) {              /* U */
                    lg = (lv > 0xFFFFUL);
                    un = 1;
                } else if (lv <= 0x7FFFUL) {            /* int */
                    lg = 0; un = 0;
                } else if (uint_rung && lv <= 0xFFFFUL) {   /* unsigned int */
                    lg = 0; un = 1;
                } else if (lv <= 0x7FFFFFFFUL) {        /* long int */
                    lg = 1; un = 0;
                } else {                                /* unsigned long */
                    lg = 1; un = 1;
                }
                g_cur.is_long     = lg;
                g_cur.is_unsigned = un;
            }
        }
        return;
    }

    if (is_ident_start(c)) {
        size_t start = g_pos;
        while (is_ident_cont(peek_ch())) adv_ch();
        size_t len = g_pos - start;
        if (len == 3 && memcmp(g_src + start, "int", 3) == 0) {
            g_cur.kind = TOK_INT_KW;
            return;
        }
        if (len == 6 && memcmp(g_src + start, "return", 6) == 0) {
            g_cur.kind = TOK_RETURN_KW;
            return;
        }
        if (len == 2 && memcmp(g_src + start, "if", 2) == 0) {
            g_cur.kind = TOK_IF_KW;
            return;
        }
        if (len == 2 && memcmp(g_src + start, "do", 2) == 0) {
            g_cur.kind = TOK_DO_KW;
            return;
        }
        if (len == 4 && memcmp(g_src + start, "else", 4) == 0) {
            g_cur.kind = TOK_ELSE_KW;
            return;
        }
        if (len == 5 && memcmp(g_src + start, "while", 5) == 0) {
            g_cur.kind = TOK_WHILE_KW;
            return;
        }
        if (len == 4 && memcmp(g_src + start, "char", 4) == 0) {
            g_cur.kind = TOK_CHAR_KW;
            return;
        }
        if (len == 4 && memcmp(g_src + start, "void", 4) == 0) {
            g_cur.kind = TOK_VOID_KW;
            return;
        }
        if (len == 6 && memcmp(g_src + start, "sizeof", 6) == 0) {
            g_cur.kind = TOK_SIZEOF_KW;
            return;
        }
        if (len == 6 && memcmp(g_src + start, "struct", 6) == 0) {
            g_cur.kind = TOK_STRUCT_KW;
            return;
        }
        if (len == 5 && memcmp(g_src + start, "union", 5) == 0) {
            g_cur.kind = TOK_UNION_KW;
            return;
        }
        if (len == 4 && memcmp(g_src + start, "enum", 4) == 0) {
            g_cur.kind = TOK_ENUM_KW;
            return;
        }
        if (len == 7 && memcmp(g_src + start, "typedef", 7) == 0) {
            g_cur.kind = TOK_TYPEDEF_KW;
            return;
        }
        if (len == 6 && memcmp(g_src + start, "switch", 6) == 0) {
            g_cur.kind = TOK_SWITCH_KW; return;
        }
        if (len == 4 && memcmp(g_src + start, "case", 4) == 0) {
            g_cur.kind = TOK_CASE_KW; return;
        }
        if (len == 7 && memcmp(g_src + start, "default", 7) == 0) {
            g_cur.kind = TOK_DEFAULT_KW; return;
        }
        if (len == 5 && memcmp(g_src + start, "break", 5) == 0) {
            g_cur.kind = TOK_BREAK_KW; return;
        }
        if (len == 8 && memcmp(g_src + start, "continue", 8) == 0) {
            g_cur.kind = TOK_CONTINUE_KW; return;
        }
        if (len == 3 && memcmp(g_src + start, "for", 3) == 0) {
            g_cur.kind = TOK_FOR_KW; return;
        }
        if (len == 4 && memcmp(g_src + start, "goto", 4) == 0) {
            g_cur.kind = TOK_GOTO_KW; return;
        }
        if (len == 4 && memcmp(g_src + start, "long", 4) == 0) {
            g_cur.kind = TOK_LONG_KW;
            return;
        }
        /* B-6: float / double both lex to TOK_FLOAT_KW.  `value' says which
         * was written -- 1 for `double' -- because `double' is the type
         * LT_DBL, `long double' is a type and `long float' is not. */
        if (len == 5 && memcmp(g_src + start, "float", 5) == 0) {
            g_cur.kind = TOK_FLOAT_KW;
            g_cur.value = 0;
            return;
        }
        if (len == 6 && memcmp(g_src + start, "double", 6) == 0) {
            g_cur.kind = TOK_FLOAT_KW;
            g_cur.value = 1;
            return;
        }
        if (len == 6 && memcmp(g_src + start, "static", 6) == 0) {
            g_cur.kind = TOK_STATIC_KW;
            return;
        }
        /* T2-2: scan_tok is a RAW scanner — macro expansion happens at the
         * token level in pp_next_tok().  Identifiers are dedup-interned at
         * production so every downstream consumer (macro tables, symbol
         * tables, the token vector) shares one canonical pointer whose
         * bytes outlive any source buffer. */
        g_cur.kind   = TOK_IDENT;
        g_cur.id_ptr = lex_intern_ident(g_src + start, (int)len);
        g_cur.id_len = (int)len;
        return;
    }

    /* Unknown character. */
    char msgbuf[64];
    snprintf(msgbuf, sizeof msgbuf,
             "unexpected character %c (0x%02x)", c, c);
    die(g_cur.line, g_cur.col, msgbuf);
}

/* =============== T2-2: token-level macro expansion engine ===============
 * scan_tok() above is a RAW scanner (chars -> tokens, directives handled,
 * no expansion).  pp_next_tok() below is the expansion layer: it reads
 * tokens (from in-flight expansion frames first, else the raw scanner)
 * and splices macro bodies as TOKEN SLICES.  Faithfulness notes vs the
 * deleted text-frame engine:
 *   - a frame is popped LAZILY (only when a read goes past its end), so
 *     the recursion guard still covers a body's own final token;
 *   - a funclike name is an invocation only if `(` follows in the SAME
 *     source (same expansion frame, or the raw char stream via the old
 *     save/peek/restore idiom) — a `(` across a boundary does not invoke,
 *     exactly like the old per-frame char peek;
 *   - a guard-blocked funclike CALL still consumes (and drops) its args
 *     and emits the bare name — the pinned G(G(1)) behavior (pp_adv3);
 *   - arg-count dies fire BEFORE the guard, as before. */

#define PP_MX_DEPTH     16
#define PP_MAX_CALL_ARGS 16

typedef struct {
    int        midx;    /* macro being expanded (recursion-guard key) */
    const Tok *toks;
    int        n;
    int        cur;
    Tok       *owned;   /* substituted vector to free on pop; NULL = shared body */
} MxFrame;
static MxFrame g_mx[PP_MX_DEPTH];
static int     g_mx_n = 0;

/* An argument as a token span.  mx-path spans point into the invoking
 * frame (copied into the substituted vector before any pop); raw-path
 * spans own a freshly tokenized vector (owned != NULL). */
typedef struct { const Tok *t; int n; Tok *owned; } ArgSpan;

/* Tokenize a text slice RAW: no directives, no expansion, no frame pops.
 * Returns a malloc'd Tok vector the caller owns.  Ident/string bytes are
 * interned at production (scan_tok), so tokens are self-contained. */
static Tok *
pp_tokenize_text(const char *text, int len, int *out_n)
{
    const char *save_src = g_src;
    size_t save_len = g_src_len, save_pos = g_pos;
    int save_line = g_line, save_col = g_col;
    Tok save_cur = g_cur;
    Tok *v = NULL;
    int n = 0, cap = 0;

    g_src = text; g_src_len = (size_t)len; g_pos = 0;
    g_line = 1; g_col = 1;
    g_pp_raw_mode = 1;
    for (;;) {
        scan_tok();
        if (g_cur.kind == TOK_EOF) break;
        if (n >= cap) {
            cap = cap ? cap * 2 : 16;
            v = (Tok *)realloc(v, (size_t)cap * sizeof(Tok));
            if (!v) die(save_line, save_col, "out of memory (pp tokens)");
        }
        v[n++] = g_cur;
    }
    g_pp_raw_mode = 0;
    g_src = save_src; g_src_len = save_len; g_pos = save_pos;
    g_line = save_line; g_col = save_col;
    g_cur = save_cur;
    *out_n = n;
    return v;
}

static void
pp_macro_set_body(PpMacro *m, const char *text, int len)
{
    free(m->body_toks);
    m->body_toks = pp_tokenize_text(text, len, &m->n_body_toks);
    g_pp_body_tok_bytes += m->n_body_toks * (int)sizeof(Tok);
}

/* Define an object-like macro from plain text (__FGX__, -D name=value).
 * Mirrors the old direct table writes in main.c, including the -D body
 * clamp at PP_MAX_MACRO_BODY-1. */
void
pp_define_text(const char *name, int name_len, const char *body_text)
{
    int idx = pp_macro_lookup(name, name_len);
    if (idx < 0) {
        FCC_GROW(g_pp_macros, g_pp_n_macros, g_pp_macros_cap, PpMacro);
        idx = g_pp_n_macros++;
    }
    g_pp_macros[idx].name = lex_intern_ident(name, name_len);
    g_pp_macros[idx].live = 1;
    g_pp_macros[idx].is_funclike = 0;
    g_pp_macros[idx].n_params = 0;
    g_pp_macros[idx].is_variadic = 0;
    {
        int bl = (int)strlen(body_text);
        if (bl >= PP_MAX_MACRO_BODY) bl = PP_MAX_MACRO_BODY - 1;
        pp_macro_set_body(&g_pp_macros[idx], body_text, bl);
    }
}

static int
mx_on_stack(int midx)
{
    for (int i = 0; i < g_mx_n; i++)
        if (g_mx[i].midx == midx) return 1;
    return 0;
}

static void
mx_push(int midx, const Tok *toks, int n, Tok *owned)
{
    if (g_mx_n >= PP_MX_DEPTH)
        die(g_line, g_col, "macro expansion depth exceeds 16");
    g_mx[g_mx_n].midx  = midx;
    g_mx[g_mx_n].toks  = toks;
    g_mx[g_mx_n].n     = n;
    g_mx[g_mx_n].cur   = 0;
    g_mx[g_mx_n].owned = owned;
    g_mx_n++;
}

static void
pp_free_args(ArgSpan *args, int n_args)
{
    for (int i = 0; i < n_args; i++) free(args[i].owned);
}

/* Funclike '(' lookahead + arg collection, RAW-source flavor: byte-exact
 * port of the old in-scan_tok collector (whitespace/newline skipping,
 * depth-aware commas, strings passed verbatim, trailing-ws trim), except
 * each collected arg TEXT is tokenized into an owned span. */
static int
pp_collect_args_raw(const PpMacro *m, ArgSpan *args, int *out_n)
{
    size_t save_pos = g_pos;
    int save_line = g_line, save_col = g_col;
    int n_args = 0;
    while (peek_ch() == ' ' || peek_ch() == '\t' ||
           peek_ch() == '\n' || peek_ch() == '\r') adv_ch();
    if (peek_ch() != '(') {
        g_pos = save_pos; g_line = save_line; g_col = save_col;
        return 0;
    }
    adv_ch();  /* consume '(' */
    /* Zero-param invocation `f()` is valid. */
    while (peek_ch() == ' ' || peek_ch() == '\t' ||
           peek_ch() == '\n' || peek_ch() == '\r') adv_ch();
    if (peek_ch() == ')' && m->n_params == 0) {
        adv_ch();
        *out_n = 0;
        return 1;
    }
    for (;;) {
        if (n_args >= PP_MAX_CALL_ARGS)
            die(g_line, g_col,
                "too many args in function-like macro call (max 16)");
        int cap = 64;
        char *buf = (char *)malloc((size_t)cap);
        if (!buf) die(g_line, g_col, "OOM in macro arg");
        int blen = 0;
        int depth = 0;
        /* Skip leading whitespace. */
        while (peek_ch() == ' ' || peek_ch() == '\t' ||
               peek_ch() == '\n' || peek_ch() == '\r') adv_ch();
        for (;;) {
            int pc = peek_ch();
            if (pc < 0)
                die(g_line, g_col,
                    "unterminated function-like macro call");
            if (depth == 0 && (pc == ',' || pc == ')')) break;
            if (pc == '(') depth++;
            else if (pc == ')') depth--;
            /* Pass strings/char literals verbatim. */
            if (pc == '"' || pc == '\'') {
                char quote = (char)pc;
                if (blen + 1 >= cap) { cap *= 2; buf = (char *)realloc(buf, (size_t)cap); }
                buf[blen++] = (char)adv_ch();
                while ((pc = peek_ch()) >= 0) {
                    if (blen + 2 >= cap) { cap *= 2; buf = (char *)realloc(buf, (size_t)cap); }
                    buf[blen++] = (char)adv_ch();
                    if (pc == '\\' && peek_ch() >= 0) {
                        buf[blen++] = (char)adv_ch();
                        continue;
                    }
                    if (pc == quote) break;
                }
                continue;
            }
            if (blen + 1 >= cap) { cap *= 2; buf = (char *)realloc(buf, (size_t)cap); }
            buf[blen++] = (char)adv_ch();
        }
        /* Trim trailing whitespace. */
        while (blen > 0 && (buf[blen-1] == ' ' ||
                            buf[blen-1] == '\t' ||
                            buf[blen-1] == '\n' ||
                            buf[blen-1] == '\r'))
            blen--;
        buf[blen] = '\0';
        args[n_args].owned = pp_tokenize_text(buf, blen, &args[n_args].n);
        args[n_args].t = args[n_args].owned;
        free(buf);
        n_args++;
        if (peek_ch() == ',') { adv_ch(); continue; }
        if (peek_ch() == ')') { adv_ch(); break; }
        die(g_line, g_col, "expected ',' or ')' in macro call");
    }
    *out_n = n_args;
    return 1;
}

/* Funclike '(' lookahead + arg collection, expansion-frame flavor: the
 * name came from the TOP mx frame, so the call must complete within that
 * frame's tokens (the old engine's char peek stopped at the frame end). */
static int
pp_collect_args_mx(const PpMacro *m, ArgSpan *args, int *out_n)
{
    MxFrame *f = &g_mx[g_mx_n - 1];
    int n_args = 0;
    if (f->cur >= f->n || f->toks[f->cur].kind != TOK_LPAREN)
        return 0;
    f->cur++;   /* consume '(' */
    if (f->cur < f->n && f->toks[f->cur].kind == TOK_RPAREN &&
        m->n_params == 0) {
        f->cur++;
        *out_n = 0;
        return 1;
    }
    for (;;) {
        int depth = 0;
        int start;
        if (n_args >= PP_MAX_CALL_ARGS)
            die(g_line, g_col,
                "too many args in function-like macro call (max 16)");
        start = f->cur;
        for (;;) {
            TokKind k;
            if (f->cur >= f->n)
                die(g_line, g_col,
                    "unterminated function-like macro call");
            k = f->toks[f->cur].kind;
            if (depth == 0 && (k == TOK_COMMA || k == TOK_RPAREN)) break;
            if (k == TOK_LPAREN) depth++;
            else if (k == TOK_RPAREN) depth--;
            f->cur++;
        }
        args[n_args].t = &f->toks[start];
        args[n_args].n = f->cur - start;
        args[n_args].owned = NULL;
        n_args++;
        if (f->toks[f->cur].kind == TOK_COMMA) { f->cur++; continue; }
        f->cur++;   /* consume ')' */
        break;
    }
    *out_n = n_args;
    return 1;
}

/* K&R substitute-inside-literals (traditional cpp): a macro parameter that
 * appears INSIDE a character (or string) literal in the body is replaced by the
 * argument — the pre-ANSI behavior the classic `#define CTRL(c) ('c'&037)` idiom
 * relies on (CTRL(]) -> ']'&037).  ANSI dropped it, but 2.11BSD uses it widely
 * (telnet escape/echo chars, ex, termlib, games).  Implemented at the token
 * level: char/string literals keep no source spelling, so reconstruct the arg's
 * leading char from its single token. */
static int
punct_char(TokKind k)
{
    switch (k) {
    case TOK_LPAREN: return '('; case TOK_RPAREN: return ')';
    case TOK_LBRACE: return '{'; case TOK_RBRACE: return '}';
    case TOK_LBRACKET: return '['; case TOK_RBRACKET: return ']';
    case TOK_SEMI: return ';'; case TOK_COMMA: return ',';
    case TOK_COLON: return ':'; case TOK_QMARK: return '?';
    case TOK_TILDE: return '~'; case TOK_PLUS: return '+';
    case TOK_MINUS: return '-'; case TOK_STAR: return '*';
    case TOK_SLASH: return '/'; case TOK_PERCENT: return '%';
    case TOK_EQ: return '='; case TOK_DOT: return '.';
    case TOK_LT: return '<'; case TOK_GT: return '>';
    case TOK_BANG: return '!'; case TOK_AMP: return '&';
    case TOK_PIPE: return '|'; case TOK_CARET: return '^';
    default: return 0;
    }
}

/* The leading character of a single-token argument (for literal substitution).
 * -1 if the arg isn't a single token with a single-char spelling we can form. */
static int
arg_lead_char(const ArgSpan *a)
{
    if (a->n != 1) return -1;
    const Tok *t = &a->t[0];
    if (t->kind == TOK_IDENT && t->id_len >= 1) return (unsigned char)t->id_ptr[0];
    if (t->kind == TOK_CHAR_LIT) return (int)(t->value & 0xff);
    if (t->kind == TOK_STR_LIT && t->str_len >= 1) return (unsigned char)t->str_ptr[0];
    return punct_char(t->kind);   /* 0 (=> caller treats as -1) for unknown */
}

/* Full spelling of a single-token arg into buf; returns length or -1. */
static int
arg_spelling(const ArgSpan *a, char *buf, int cap)
{
    if (a->n != 1) return -1;
    const Tok *t = &a->t[0];
    if (t->kind == TOK_IDENT) {
        if (t->id_len >= cap) return -1;
        memcpy(buf, t->id_ptr, (size_t)t->id_len);
        return t->id_len;
    }
    int c = arg_lead_char(a);
    if (c >= 0 && cap >= 1) { buf[0] = (char)c; return 1; }
    return -1;
}

static int
pp_is_ident_ch(int c, int first)
{
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' ||
           (!first && c >= '0' && c <= '9');
}

/* Build a funclike expansion: the body slice with param idents replaced
 * by their arg spans and __VA_ARGS__ by the extras joined with commas.
 * Whole-ident matching only, exactly like the old text substituter. */
static Tok *
pp_subst_body(const PpMacro *m, const ArgSpan *args, int n_args, int *out_n)
{
    Tok *v = NULL;
    int n = 0, cap = 0;
#define SUB_PUT(tok) do { \
        if (n >= cap) { \
            cap = cap ? cap * 2 : 32; \
            v = (Tok *)realloc(v, (size_t)cap * sizeof(Tok)); \
            if (!v) die(g_line, g_col, "out of memory expanding macro"); \
        } \
        v[n++] = (tok); } while (0)
    /* Body idents and param names are both interned: matches are pointer
     * compares. */
    static const char *va_ident = NULL;
    if (!va_ident) va_ident = lex_intern_ident("__VA_ARGS__", 11);
    for (int i = 0; i < m->n_body_toks; i++) {
        const Tok *bt = &m->body_toks[i];
        if (bt->kind == TOK_IDENT) {
            /* __VA_ARGS__: join args[n_params..n_args-1] with commas. */
            if (m->is_variadic && bt->id_ptr == va_ident) {
                int n_extra = n_args - m->n_params;
                for (int e = 0; e < n_extra; e++) {
                    const ArgSpan *a = &args[m->n_params + e];
                    for (int j = 0; j < a->n; j++) SUB_PUT(a->t[j]);
                    if (e + 1 < n_extra) {
                        Tok ct = *bt;
                        ct.kind = TOK_COMMA;
                        SUB_PUT(ct);
                    }
                }
                continue;
            }
            /* Named parameter? */
            {
                int pidx = -1;
                for (int p = 0; p < m->n_params; p++) {
                    if (m->params[p] == bt->id_ptr) {
                        pidx = p;
                        break;
                    }
                }
                if (pidx >= 0) {
                    for (int j = 0; j < args[pidx].n; j++)
                        SUB_PUT(args[pidx].t[j]);
                    continue;
                }
            }
        }
        /* K&R: a single-byte CHAR literal whose char IS a parameter name is
         * replaced by the argument's leading char — `('c'&037)` with param `c`,
         * CTRL(]) -> ('&037), CTRL(E) -> ('E'&037).  chars are interned so the
         * "is this char a param name" test is a pointer compare. */
        if (bt->kind == TOK_CHAR_LIT && (bt->value & ~0xffu) == 0 &&
            m->n_params > 0) {
            char ch = (char)(bt->value & 0xff);
            const char *chin = lex_intern_ident(&ch, 1);
            int pidx = -1;
            for (int p = 0; p < m->n_params; p++)
                if (m->params[p] == chin) { pidx = p; break; }
            if (pidx >= 0) {
                int lc = arg_lead_char(&args[pidx]);
                Tok nt = *bt;
                if (lc >= 0) nt.value = (unsigned)(lc & 0xff);
                SUB_PUT(nt);
                continue;
            }
        }
        /* K&R: a param name appearing as a whole identifier INSIDE a string
         * literal is replaced by the arg's spelling — `#define S(x) "x-tag"`,
         * S(hi) -> "hi-tag".  Rarer than the CHAR case but the same feature. */
        if (bt->kind == TOK_STR_LIT && m->n_params > 0) {
            char out[PP_MAX_MACRO_BODY]; int on = 0, changed = 0, ok = 1;
            for (int k = 0; k < bt->str_len && ok; ) {
                int c = (unsigned char)bt->str_ptr[k];
                if (pp_is_ident_ch(c, 1)) {
                    int j = k + 1;
                    while (j < bt->str_len &&
                           pp_is_ident_ch((unsigned char)bt->str_ptr[j], 0)) j++;
                    const char *runin = lex_intern_ident(bt->str_ptr + k, j - k);
                    int pidx = -1;
                    for (int p = 0; p < m->n_params; p++)
                        if (m->params[p] == runin) { pidx = p; break; }
                    int rl = j - k;
                    if (pidx >= 0) {
                        char sp[128];
                        int sl = arg_spelling(&args[pidx], sp, (int)sizeof sp);
                        if (sl >= 0) {
                            if (on + sl >= (int)sizeof out) { ok = 0; break; }
                            memcpy(out + on, sp, (size_t)sl); on += sl;
                            changed = 1; k = j; continue;
                        }
                    }
                    if (on + rl >= (int)sizeof out) { ok = 0; break; }
                    memcpy(out + on, bt->str_ptr + k, (size_t)rl); on += rl; k = j;
                } else {
                    if (on + 1 >= (int)sizeof out) { ok = 0; break; }
                    out[on++] = (char)c; k++;
                }
            }
            if (ok && changed) {
                Tok nt = *bt;
                nt.str_ptr = intern_bytes(out, on);
                nt.str_len = on;
                SUB_PUT(nt);
                continue;
            }
        }
        SUB_PUT(*bt);
    }
#undef SUB_PUT
    *out_n = n;
    g_pp_body_tok_bytes += n * (int)sizeof(Tok);
    return v;
}

static Tok *pp_expand_span(const Tok *t, int n, int *out_n);

/* The expansion loop, parameterized by a frame-stack BASE and whether
 * the raw scanner may be consulted.  The whole-TU stream runs with
 * (base=0, raw_ok=1); pp_expand_span() drains an argument span with
 * (base=<level below its sentinel>, raw_ok=0) so it runs through the
 * same machinery without ever touching raw source — returns 0 when the
 * frames above base are exhausted. */
static int
pp_next_tok_above(int base, int raw_ok, Tok *out)
{
    for (;;) {
        Tok t;
        int from_mx;
        /* Lazy-pop exhausted frames — BEFORE the next read, never after
         * an emit, so a frame still guards its own final token. */
        while (g_mx_n > base && g_mx[g_mx_n - 1].cur >= g_mx[g_mx_n - 1].n) {
            free(g_mx[g_mx_n - 1].owned);
            g_mx_n--;
        }
        if (g_mx_n > base) {
            MxFrame *f = &g_mx[g_mx_n - 1];
            t = f->toks[f->cur++];
            /* An expanded token belongs to the file that invokes the macro,
             * which is the file being scanned now -- not the header that
             * defined it: a static a header macro declares is the invoking
             * member's (fcc --libso attributes by file). */
            t.file = g_cur_path;
            from_mx = 1;
        } else if (raw_ok) {
            scan_tok();
            t = g_cur;
            from_mx = 0;
        } else {
            return 0;               /* span drained */
        }
        if (t.kind != TOK_IDENT) { *out = t; return 1; }
        {
            int midx = pp_macro_lookup(t.id_ptr, t.id_len);
            PpMacro *m;
            if (midx < 0) { *out = t; return 1; }
            m = &g_pp_macros[midx];
            if (!m->is_funclike) {
                /* Object-like: recursion guard, then splice the body. */
                if (mx_on_stack(midx)) { *out = t; return 1; }
                mx_push(midx, m->body_toks, m->n_body_toks, NULL);
                continue;
            }
            {
                ArgSpan args[PP_MAX_CALL_ARGS];
                int n_args = 0;
                int invoked = from_mx ? pp_collect_args_mx(m, args, &n_args)
                                      : pp_collect_args_raw(m, args, &n_args);
                if (!invoked) { *out = t; return 1; }   /* bare name */
                /* Arg-count check BEFORE the guard (a guarded call with a
                 * wrong count still dies, as before). */
                if (m->is_variadic) {
                    if (n_args < m->n_params)
                        die(g_line, g_col,
                            "too few args for variadic macro (need >= named count)");
                } else if (n_args != m->n_params) {
                    die(g_line, g_col,
                        "wrong arg count for function-like macro");
                }
                if (mx_on_stack(midx)) {
                    /* Guard-blocked call: args are consumed and DROPPED,
                     * the bare name is emitted (self-recursive funclike —
                     * pathological; real cpp would emit the tokens). */
                    pp_free_args(args, n_args);
                    *out = t; return 1;
                }
                /* C90 6.8.3.1: each argument is FULLY macro-expanded
                 * before substitution (fixes the pinned arg-position gap:
                 * G(G(1)), tword.h INCREF(INCREF(..)) now expand).  Done
                 * AFTER the guard so a blocked call drops raw args. */
                for (int i = 0; i < n_args; i++) {
                    int en = 0;
                    Tok *ev = pp_expand_span(args[i].t, args[i].n, &en);
                    free(args[i].owned);
                    args[i].owned = ev;
                    args[i].t = ev;
                    args[i].n = en;
                }
                {
                    int sn = 0;
                    Tok *sv = pp_subst_body(m, args, n_args, &sn);
                    pp_free_args(args, n_args);
                    mx_push(midx, sv, sn, sv);
                }
                continue;
            }
        }
    }
}

Tok
pp_next_tok(void)
{
    Tok t;
    (void)pp_next_tok_above(0, 1, &t);
    return t;
}

/* Fully expand a token span (a collected macro argument) into a fresh
 * malloc'd vector.  Runs above a sentinel frame (midx -1 matches no
 * guard); never reads raw source, so a funclike name at the span's end
 * is never invoked by tokens beyond the span (the same-source rule). */
static Tok *
pp_expand_span(const Tok *t, int n, int *out_n)
{
    int base = g_mx_n;
    Tok *v = NULL;
    int vn = 0, cap = 0;
    Tok tok;
    mx_push(-1, t, n, NULL);
    while (pp_next_tok_above(base, 0, &tok)) {
        if (vn >= cap) {
            cap = cap ? cap * 2 : 16;
            v = (Tok *)realloc(v, (size_t)cap * sizeof(Tok));
            if (!v) die(g_line, g_col, "out of memory expanding macro arg");
        }
        v[vn++] = tok;
    }
    *out_n = vn;
    return v;
}

/* --- Increment 1: whole-TU token vector ---
 * lex_tokenize_all() drives the raw scanner scan_tok() to TOK_EOF exactly
 * once (all #include / #define / #if resolution and macro expansion happen
 * here, in source order — the pp frame stack is now pre-pass-internal), and
 * records every token in g_toks[].  IDENT / STR_LIT text is copied into an
 * intern arena so tokens own their bytes for the compiler's lifetime: the
 * whole "don't hold a pointer across a peek" bug class is gone.
 *
 * The parser interface is a cursor: g_cur == the last consumed token,
 * g_tok_idx == index of the next.  A lookahead rewind is lex_peek_save/
 * lex_peek_restore over {idx, cur} — it cannot corrupt pp state because
 * there is none left by the time the parser runs. */
Tok *g_toks = NULL;
int  g_n_toks = 0;
int  g_tok_idx = 0;
static int g_toks_cap = 0;

/* Block-chained intern arena: pointers stay valid forever (blocks are never
 * realloc'd or freed; superseded blocks leak their tail — bounded by TU size,
 * reclaimed at process exit like every other fcc arena). */
#define INTERN_BLK 65536
static char *g_intern_blk = NULL;
static int   g_intern_used = 0, g_intern_cap = 0;
int          g_intern_total = 0;   /* T2-0: bytes across ALL blocks (Part-V measurement) */

static const char *
intern_bytes(const char *p, int len)
{
    if (g_intern_blk == NULL || g_intern_used + len + 1 > g_intern_cap) {
        g_intern_cap = (len + 1 > INTERN_BLK) ? len + 1 : INTERN_BLK;
        g_intern_blk = (char *)malloc((size_t)g_intern_cap);
        if (!g_intern_blk) die(g_line, g_col, "out of memory (token intern)");
        g_intern_used = 0;
    }
    char *dst = g_intern_blk + g_intern_used;
    memcpy(dst, p, (size_t)len);
    dst[len] = '\0';
    g_intern_used += len + 1;
    g_intern_total += len + 1;
    return dst;
}

/* T2-1: DEDUP-interning for IDENTIFIERS — same spelling => same pointer,
 * TU-wide.  This is the "stable symbol handle" substrate: symbol-table
 * names can become interned pointers and every name lookup a pointer
 * compare, and the T2-3 %s-operand cell ops get alias-safe name storage.
 * Open-addressing hash over the arena; the table only stores pointers
 * (the bytes live in the ordinary intern blocks).  Sized generously for
 * the largest elvis TU; dies loudly if a pathological TU fills it. */
#define IDENT_HASH_SZ 8192           /* power of two; ~5.6k idents max @ 70% */
static const char *g_ident_tab[IDENT_HASH_SZ];
static int         g_ident_n = 0;
int                g_ident_unique = 0;   /* T2-0 stats: distinct identifiers */

const char *
lex_intern_ident(const char *p, int len)
{
    unsigned h = 2166136261u;
    int i;
    for (i = 0; i < len; i++) { h ^= (unsigned char)p[i]; h *= 16777619u; }
    h &= (IDENT_HASH_SZ - 1);
    for (;;) {
        const char *e = g_ident_tab[h];
        if (e == NULL) break;
        if ((int)strlen(e) == len && memcmp(e, p, (size_t)len) == 0)
            return e;                          /* hit: the canonical pointer */
        h = (h + 1) & (IDENT_HASH_SZ - 1);
    }
    if (g_ident_n >= (IDENT_HASH_SZ * 7) / 10)
        die(g_line, g_col, "identifier intern table full (raise IDENT_HASH_SZ)");
    g_ident_tab[h] = intern_bytes(p, len);
    g_ident_n++;
    g_ident_unique++;
    return g_ident_tab[h];
}

static void
lex_append_tok(Tok t)
{
    if (g_n_toks >= g_toks_cap) {
        g_toks_cap = g_toks_cap ? g_toks_cap * 2 : 4096;
        g_toks = (Tok *)realloc(g_toks,
                                (size_t)g_toks_cap * sizeof(Tok));
        if (!g_toks) die(g_line, g_col, "out of memory (token vector)");
    }
    g_toks[g_n_toks++] = t;
}

/* Tokenize the CURRENT g_src buffer (directives live) into g_toks.
 * #include recurses through here (stage c) — an included file's EOF just
 * ends its own pass, so its tokens land inline at the directive point. */
static void
pp_tokenize_buffer(void)
{
    for (;;) {
        /* T2-2: pp_next_tok = raw scan + token-level macro expansion.
         * Ident/string interning happens at production in scan_tok. */
        Tok t = pp_next_tok();
        if (t.kind == TOK_EOF) break;
        lex_append_tok(t);
    }
}

/* --- Redundant grouping parens around a postfix expression (apple/fgx#95) ---
 *
 * K&R DEFINES the forms fcc accepts in terms of the forms it rejected:
 *
 *   A.7.3.3 p.164  `E1->MOS` is THE SAME AS `(*E1).MOS`
 *   A.7.3.1 p.162  `E1[E2]` is IDENTICAL (BY DEFINITION) TO `*((E1)+(E2))`
 *   A.7.3.2 p.163  in the first edition an explicit `*` was REQUIRED to call
 *                  through a function pointer; "the older syntax is still usable"
 *   A.7.2   p.162  a parenthesized expression is a primary expression, and the
 *                  parens do not affect its lvalue-ness
 *
 * fcc accepted every DERIVED spelling (`p->f`, `p[i]`, `fp()`) and rejected the
 * PRIMITIVE each one is defined as (`(*p).f`, `*(p+i)`, `(*fp)()`).  Seven
 * different diagnostics, in read, assign and address-of context, from one gap:
 * `.` applied to a PARENTHESIZED postfix expression.  The parser had grown six
 * arms around that gap, three of which already spliced a grouping ')' out of the
 * token vector by hand (parse_stmt.c's G21/G41 re-dispatch).  This is the
 * general form of that splice, done once, before any arm sees the stream.
 *
 * SO THE PARENS ARE MADE TRANSPARENT FOR ONE IDENTITY, rather than the arms
 * taught to see through them:
 *
 *      ( * E ) . m      ->   E -> m         A.7.3.3
 *
 * THE OTHER THREE IDENTITIES ARE NOT DONE HERE, AND THE FIXTURES ARE WHY.  The
 * premise this pass started from -- that fcc accepts every DERIVED spelling and
 * rejects every PRIMITIVE -- is true of the four rows above and NOT true in
 * general.  Rewriting the other identities regressed five fixtures, each of
 * which pins the opposite direction:
 *
 *   - `(*vp->v_op->vn_lookup)()` (M18 fnptr_vnodeops, M22 fnptr_drfcall) is the
 *     PRIMITIVE call form, and fcc accepts it while REJECTING the derived
 *     `vp->v_op->vn_lookup()`.  A.7.3.2 read one way turns a working call into
 *     a broken one.
 *   - `((p)._cheat) &= 0` (M8 dot_ptr_pun, knr_pun_dot) reaches the K&R
 *     global-member pun through a parenthesized POINTER; stripping the parens
 *     routes it to an arm that rejects `.` on a non-struct.
 *   - `(p->link[1])->link[0]` (M8 paren_base_chain) needs its parens: they are
 *     what gives the chain reader a computed base to resolve the element's
 *     struct_id against.
 *
 * In each case the parens are LOAD-BEARING for an arm that already works.  A
 * stream-level rewrite cannot know that, so it only performs the one identity
 * where the primitive is rejected and the derived form is not.  The rest belong
 * in the parser, where the accepted spellings keep their own paths.
 *
 * NARROWLY GUARDED even so.  E must be a single postfix-expression -- an
 * identifier or a parenthesized group, followed by a run of `.f` / `->f` /
 * `[...]` / `(...)`.  That is what stops
 *
 *      (*a ? *b : *c).m        (starts with `*`, is not a deref)
 *      (*p + 1).m              (ditto)
 *
 * being rewritten into something that still parses and means something else,
 * which is the only outcome here worth being afraid of.
 *
 * A `*` is cancelled ONLY against a following `.`.  Never against `[`:
 * `(*p)[i]` with p a pointer-to-array is not `*p[i]`, and conflating them
 * would be a silent miscompile rather than a rejection.  Never against a call
 * either: `int (*fn)();` -- a function-pointer DECLARATOR -- is the same token
 * shape as a K&R-1 call through one, and a first cut that rewrote it produced
 * `int fn();`, so every struct carrying a function pointer stopped compiling.
 *
 * Spliced slots become TOK_SKIP and lex_drop_skips then removes them; every
 * surviving token keeps its own line/col, so diagnostics still point at the
 * source the programmer wrote.
 */
static int
lex_match_close(int i)
{
    /* i indexes a '('; return the index of its matching ')', or -1. */
    int d = 0;
    for (; i < g_n_toks; i++) {
        TokKind k = g_toks[i].kind;
        if (k == TOK_LPAREN) d++;
        else if (k == TOK_RPAREN) { if (--d == 0) return i; }
        else if (k == TOK_EOF) break;
    }
    return -1;
}

static int
lex_skip_group(int i, TokKind open, TokKind close)
{
    /* i indexes `open`; return the index just past the matching `close`. */
    int d = 0;
    for (; i < g_n_toks; i++) {
        TokKind k = g_toks[i].kind;
        if (k == open) d++;
        else if (k == close) { if (--d == 0) return i + 1; }
        else if (k == TOK_EOF) break;
    }
    return -1;
}

/* Do tokens [a, b) form exactly ONE postfix-expression (K&R A.7.3)?
 * `*sel` (optional) is set when the run selects a member -- see the caller. */
static int
lex_is_postfix_run_sel(int a, int b, int *sel)
{
    int i = a;
    if (i >= b) return 0;
    if (g_toks[i].kind == TOK_IDENT) i++;
    else if (g_toks[i].kind == TOK_LPAREN) {
        i = lex_skip_group(i, TOK_LPAREN, TOK_RPAREN);
        if (i < 0 || i > b) return 0;
    } else return 0;
    while (i < b) {
        TokKind k = g_toks[i].kind;
        if (k == TOK_DOT || k == TOK_ARROW) {
            if (i + 1 >= b || g_toks[i + 1].kind != TOK_IDENT) return 0;
            if (sel) *sel = 1;
            i += 2;
        } else if (k == TOK_LBRACKET) {
            i = lex_skip_group(i, TOK_LBRACKET, TOK_RBRACKET);
            if (i < 0 || i > b) return 0;
        } else if (k == TOK_LPAREN) {
            i = lex_skip_group(i, TOK_LPAREN, TOK_RPAREN);
            if (i < 0 || i > b) return 0;
        } else return 0;
    }
    return i == b;
}

int
lex_is_postfix_run(int a, int b)
{
    return lex_is_postfix_run_sel(a, b, NULL);
}

static void
lex_normalize_paren_postfix(void)
{
    int i;
    for (i = 0; i < g_n_toks; i++) {
        if (g_toks[i].kind != TOK_LPAREN) continue;
        int close = lex_match_close(i);
        if (close < 0) continue;
        int after = close + 1;
        while (after < g_n_toks && g_toks[after].kind == TOK_SKIP) after++;
        if (after >= g_n_toks) continue;
        TokKind nk = g_toks[after].kind;

        /* ( * E ) . m   ->   E -> m           K&R A.7.3.3, and ONLY this. */
        if (g_toks[i + 1].kind == TOK_STAR && nk == TOK_DOT &&
            lex_is_postfix_run(i + 2, close)) {
            g_toks[i].kind     = TOK_SKIP;
            g_toks[i + 1].kind = TOK_SKIP;
            g_toks[close].kind = TOK_SKIP;
            g_toks[after].kind = TOK_ARROW;
        }
    }
}

/*------------------------------------------------------------------------------
 * Translation phase 6: ADJACENT STRING LITERALS ARE ONE LITERAL.
 *
 * K&R 2nd ed A.2.6: "Adjacent string literals are concatenated into a single
 * string."  fcc had no rule for a string token following a string token, so
 * `"abc" "def"` stopped at `expected ';'` (apple/fgx#158) and every long message
 * in the tree had to be one physical line.  That costs most in PORTED files:
 * re-flowing upstream's diagnostics is an edit, and an edit is a permanent
 * divergence from the vendored original in exactly the files where divergence is
 * most expensive to explain.
 *
 * IT RUNS HERE, over the finished token array, and the placement is the
 * correctness argument rather than convenience.  Concatenation is phase 6 and
 * macro expansion is phase 4, so
 *
 *      #define TAIL "!"
 *      char *s = "hi" TAIL;
 *
 * must join AFTER expansion.  Doing it in the raw scanner would have been a
 * smaller diff and would have silently missed every macro-produced literal --
 * the half no simple test would have looked for.
 *
 * Absorbed slots become TOK_SKIP, the same mechanism lex_normalize_paren_postfix
 * uses, so the surviving token keeps the line/col of the FIRST literal and a
 * diagnostic points where the programmer started the string rather than at
 * whichever fragment happened to be last.
 */
static void
lex_concat_adjacent_strings(void)
{
    int i;

    for (i = 0; i < g_n_toks; i++) {
        int j, n;

        if (g_toks[i].kind != TOK_STR_LIT) continue;
        j = i + 1;
        while (j < g_n_toks && g_toks[j].kind == TOK_SKIP) j++;
        if (j >= g_n_toks || g_toks[j].kind != TOK_STR_LIT) continue;

        /* g_str_tok_buf is the scanner's scratch and tokenization is finished,
         * so it is free real estate -- and it is already the size a literal is
         * allowed to be, which is the bound that has to hold here too. */
        n = g_toks[i].str_len;
        memcpy(g_str_tok_buf, g_toks[i].str_ptr, (size_t)n);
        while (j < g_n_toks && g_toks[j].kind == TOK_STR_LIT) {
            if (n + g_toks[j].str_len >= MAX_STR_TOK_LEN)
                die(g_toks[j].line, g_toks[j].col,
                    "concatenated string literal too long");
            memcpy(g_str_tok_buf + n, g_toks[j].str_ptr,
                   (size_t)g_toks[j].str_len);
            n += g_toks[j].str_len;
            g_toks[j].kind = TOK_SKIP;
            j++;
            while (j < g_n_toks && g_toks[j].kind == TOK_SKIP) j++;
        }
        g_str_tok_buf[n] = '\0';
        g_toks[i].str_ptr = intern_bytes(g_str_tok_buf, n);
        g_toks[i].str_len = n;
    }
}

/* CLOSE THE HOLES THE TWO PASSES ABOVE LEAVE.  next_tok() and peek_tok()
 * step over a TOK_SKIP, but the parser's lookahead helpers index g_toks[]
 * directly, and to them a hole reads as whatever it is not -- so `(*p).a[i]
 * = v', rewritten to `p->a[i] = v', still failed in every context whose
 * lookahead scans raw slots, while the spelling it was rewritten TO did not.
 * Nothing holds a token index before parsing starts, and every token carries
 * its own line/col, so removing the slots loses nothing a diagnostic uses. */
static void
lex_drop_skips(void)
{
    int i, j = 0;
    for (i = 0; i < g_n_toks; i++)
        if (g_toks[i].kind != TOK_SKIP)
            g_toks[j++] = g_toks[i];
    g_n_toks = j;
}

void
lex_tokenize_all(void)
{
    g_mx_n = 0;
    g_inc_depth = 0;
    pp_tokenize_buffer();
    lex_append_tok(g_cur);   /* the root buffer's TOK_EOF (sticky sentinel) */
    lex_concat_adjacent_strings();
    lex_normalize_paren_postfix();
    lex_drop_skips();
    g_tok_idx = 0;
}

void
next_tok(void)
{
    while (g_toks[g_tok_idx].kind == TOK_SKIP) g_tok_idx++;
    g_cur = g_toks[g_tok_idx];
    if (g_cur.kind != TOK_EOF) g_tok_idx++;   /* EOF is sticky */
}

/* Returns the token AFTER g_cur without consuming it; idempotent. */
Tok
peek_tok(void)
{
    int i = g_tok_idx;
    while (g_toks[i].kind == TOK_SKIP) i++;
    return g_toks[i];
}

void
lex_peek_save(LexPeek *p)
{
    p->idx = g_tok_idx;
    p->cur = g_cur;
}

void
lex_peek_restore(const LexPeek *p)
{
    g_tok_idx = p->idx;
    g_cur = p->cur;
}

#ifdef FCC_LEX_TEST
/* Unit-test entry (test-lex): seat `src` as the root lex buffer and tokenize
 * it so next_tok()/peek_tok() run without main()/a file. */
void
lex_init_buffer(const char *src)
{
    g_n_toks            = 0;
    g_tok_idx           = 0;
    g_pp_cond_top       = 0;
    g_pp_cond[0].active = 1;
    lex_set_source(src, (int)strlen(src), "<test>");
    lex_tokenize_all();
}
#endif
