#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "peephole.h"

#define PH_TOK 64

typedef struct {
    char *raw;              /* exact original line text (no newline) */
    char  label[PH_TOK];    /* leading label (col 0), verbatim, or "" */
    char  mnem[PH_TOK];     /* mnemonic, UPPERCASED for table lookup, or "" */
    char  operand[PH_TOK];  /* operand, verbatim, up to a ';' comment, or "" */
    int   dead;             /* 1 = drop this line from output */
} Line;

static char *
dup_range(const char *s, size_t n)
{
    char *p = malloc(n + 1);
    if (!p) return NULL;
    memcpy(p, s, n);
    p[n] = '\0';
    return p;
}

static void
copy_tok(char *dst, const char *s, size_t n, int upper)
{
    size_t i;
    if (n >= PH_TOK) n = PH_TOK - 1;
    for (i = 0; i < n; i++)
        dst[i] = upper ? (char)toupper((unsigned char)s[i]) : s[i];
    dst[i] = '\0';
}

static void
parse_fields(Line *L)
{
    const char *s = L->raw;
    const char *p;
    const char *q = s;

    L->label[0] = L->mnem[0] = L->operand[0] = '\0';

    /* blank, comment (';'), or Merlin star-comment ('*') line: no fields */
    while (*q == ' ' || *q == '\t') q++;
    if (*q == '\0' || *q == ';' || *q == '*') return;

    p = s;
    /* label present iff column 0 is not whitespace */
    if (*p != ' ' && *p != '\t') {
        const char *e = p;
        while (*e && *e != ' ' && *e != '\t') e++;
        copy_tok(L->label, p, (size_t)(e - p), 0);
        p = e;
    }
    while (*p == ' ' || *p == '\t') p++;
    if (*p == '\0' || *p == ';') return;

    {   /* mnemonic */
        const char *e = p;
        while (*e && *e != ' ' && *e != '\t') e++;
        copy_tok(L->mnem, p, (size_t)(e - p), 1);
        p = e;
    }
    while (*p == ' ' || *p == '\t') p++;
    if (*p == '\0' || *p == ';') return;

    {   /* operand: up to a comment or end-of-line, trailing ws trimmed */
        const char *e = p;
        while (*e && *e != ';') e++;
        while (e > p && (e[-1] == ' ' || e[-1] == '\t')) e--;
        copy_tok(L->operand, p, (size_t)(e - p), 0);
    }
}

static Line *
split_lines(const char *txt, size_t *out_n)
{
    size_t cap = 16, n = 0;
    Line  *lines = malloc(cap * sizeof *lines);
    const char *p = txt;

    if (!lines) { *out_n = 0; return NULL; }
    for (;;) {
        const char *nl = strchr(p, '\n');
        size_t len = nl ? (size_t)(nl - p) : strlen(p);
        Line *L;
        if (n == cap) {
            Line *tmp = realloc(lines, cap * 2 * sizeof *lines);
            if (!tmp) {
                size_t k;
                for (k = 0; k < n; k++) free(lines[k].raw);
                free(lines);
                *out_n = 0;
                return NULL;
            }
            cap *= 2;
            lines = tmp;
        }
        L = &lines[n++];
        L->raw  = dup_range(p, len);
        L->dead = 0;
        parse_fields(L);
        if (!nl) break;          /* last segment (after final '\n' or no '\n') */
        p = nl + 1;
        if (*p == '\0') break;    /* trailing '\n' -> no empty final line */
    }
    *out_n = n;
    return lines;
}

/* Join surviving (non-dead) lines' raw text with '\n'.  Preserves the
 * input's trailing-newline shape: a trailing '\n' in the source produced
 * no empty final Line, so we re-add one iff the source ended in '\n'. */
static char *
render(Line *lines, size_t n, int had_trailing_nl)
{
    size_t total = 1, i;
    char *out, *w;
    for (i = 0; i < n; i++)
        if (!lines[i].dead) total += strlen(lines[i].raw) + 1;
    out = malloc(total);
    if (!out) return NULL;
    w = out;
    for (i = 0; i < n; i++) {
        size_t len;
        if (lines[i].dead) continue;
        len = strlen(lines[i].raw);
        memcpy(w, lines[i].raw, len);
        w += len;
        *w++ = '\n';
    }
    if (w > out && !had_trailing_nl) w--;   /* drop the synthetic final '\n' */
    *w = '\0';
    return out;
}

static void
free_lines(Line *lines, size_t n)
{
    size_t i;
    for (i = 0; i < n; i++) free(lines[i].raw);
    free(lines);
}

/* Does this mnemonic write the N and Z flags as a result of its data value?
 * (loads, pulls, transfers, inc/dec, logic/arith, compares, BIT.) Stores,
 * pushes, and branches do NOT. */
static int
sets_nz(const char *m)
{
    static const char *t[] = {
        "LDA","LDX","LDY","PLA","PLX","PLY",
        "TAX","TAY","TXA","TYA","TSX","TXY","TYX",
        "INC","DEC","INX","INY","DEX","DEY","INA","DEA",
        "AND","ORA","EOR","ADC","SBC","ASL","LSR","ROL","ROR",
        "CMP","CPX","CPY","BIT",
        NULL
    };
    int i;
    for (i = 0; t[i]; i++) if (strcmp(m, t[i]) == 0) return 1;
    return 0;
}

/* A conditional branch that READS N or Z. */
static int
reads_nz(const char *m)
{
    return strcmp(m,"BEQ")==0 || strcmp(m,"BNE")==0 ||
           strcmp(m,"BMI")==0 || strcmp(m,"BPL")==0;
}

/* Any control transfer (branch/jump/call/return) - a conservative barrier
 * for the local liveness scan. */
static int
is_control(const char *m)
{
    return m[0] == 'B' /* all Bxx branches incl. BRA/BRL */
        || strcmp(m,"JMP")==0 || strcmp(m,"JML")==0
        || strcmp(m,"JSR")==0 || strcmp(m,"JSL")==0
        || strcmp(m,"RTS")==0 || strcmp(m,"RTL")==0 || strcmp(m,"RTI")==0;
}

/* A function/subroutine return - flags are dead afterward. */
static int
is_return(const char *m)
{
    return strcmp(m,"RTS")==0 || strcmp(m,"RTL")==0 || strcmp(m,"RTI")==0;
}

/* True if the N/Z flags set by line `idx` are provably dead: on the
 * fall-through path, some instruction overwrites N/Z (sets_nz) or we reach a
 * return, before any NZ-reading branch.  Conservative: a label, a control
 * transfer that is not a return, or end-of-buffer -> assume LIVE (0). */
static int
nz_dead_after(Line *lines, size_t n, size_t idx)
{
    size_t i;
    for (i = idx + 1; i < n; i++) {
        Line *L = &lines[i];
        if (L->raw[0] == '\0') continue;               /* blank */
        if (L->mnem[0] == '\0') {
            if (L->label[0] != '\0') return 0;          /* label = barrier */
            continue;                                   /* comment-only */
        }
        if (reads_nz(L->mnem))   return 0;              /* branch consumes NZ */
        if (is_return(L->mnem))  return 1;              /* flags dead at return */
        if (is_control(L->mnem)) return 0;              /* other transfer: barrier */
        if (sets_nz(L->mnem))    return 1;              /* NZ overwritten */
        /* flag-neutral instruction (STA/PHA/...) -> keep scanning */
    }
    return 0;                                            /* fell off end: live */
}

/* Index of the next line that carries a label, skipping blank/comment lines.
 * Returns -1 if the next non-blank line has no label. */
static long
next_labeled_line(Line *lines, size_t from, size_t n)
{
    size_t i;
    for (i = from; i < n; i++) {
        if (lines[i].raw[0] == '\0') continue;            /* blank */
        if (lines[i].mnem[0] == '\0' && lines[i].label[0] == '\0')
            continue;                                     /* comment-only */
        return (lines[i].label[0] != '\0') ? (long)i : -1;
    }
    return -1;
}

/* Index of the next non-dead line that is a real instruction (has a mnemonic
 * and no label that would make it a branch target), or -1.  A label on the
 * candidate line means it is reachable by a branch and must not be folded. */
static long
next_insn_no_label(Line *lines, size_t n, size_t from)
{
    size_t i;
    for (i = from; i < n; i++) {
        if (lines[i].dead) continue;
        if (lines[i].raw[0] == '\0') continue;           /* blank */
        if (lines[i].mnem[0] == '\0') {
            if (lines[i].label[0] != '\0') return -1;     /* label barrier */
            continue;                                     /* comment-only */
        }
        if (lines[i].label[0] != '\0') return -1;         /* labeled insn: barrier */
        return (long)i;
    }
    return -1;
}

/* --- Task 1.2: carry liveness for CLC;ADC #k / SEC;SBC #k folding --- */

/* Reads the carry as an INPUT (carry-only; V assumed dead — fcc emits no
 * BVC/BVS).  PHP snapshots P (incl. C); XCE swaps C<->E. */
static int
reads_carry(const char *m)
{
    return strcmp(m,"ADC")==0 || strcmp(m,"SBC")==0 ||
           strcmp(m,"ROL")==0 || strcmp(m,"ROR")==0 ||
           strcmp(m,"BCC")==0 || strcmp(m,"BCS")==0 ||
           strcmp(m,"PHP")==0 || strcmp(m,"XCE")==0;
}

/* Normalizes the carry (a stale carry is dead afterwards).  NOTE: REP/SEP are
 * deliberately NOT here — fcc only toggles M/X width (#$20/#$10/#$30), which
 * leaves carry untouched; treating them as carry-writers would wrongly fold a
 * CLC;ADC whose carry is read across a width toggle.  They fall through as
 * carry-neutral so the scan continues past them. */
static int
writes_carry(const char *m)
{
    return strcmp(m,"CLC")==0 || strcmp(m,"SEC")==0 ||
           strcmp(m,"CMP")==0 || strcmp(m,"CPX")==0 || strcmp(m,"CPY")==0 ||
           strcmp(m,"PLP")==0;
}

/* True if the carry set by line `idx` is provably dead on the fall-through path:
 * some op overwrites it (writes_carry) or we reach a return before any carry
 * read.  Conservative: a label, a non-return control transfer, or end-of-buffer
 * -> assume LIVE (0).  Skips lines an earlier pass marked dead, plus blanks and
 * comments.
 *
 * CARRY ONLY.  The CLC;ADC -> INC fold also drops the overflow flag V (ADC sets
 * V; INC does not), and this routine can return "dead" at a carry-writer that
 * leaves V untouched (CLC/SEC/CMP/CPX/CPY).  v_dead_after is the fold's second
 * gate: fcc's signed compares read V with BVC after an SBC. */
static int
carry_dead_after(Line *lines, size_t n, size_t idx)
{
    size_t i;
    for (i = idx + 1; i < n; i++) {
        Line *L = &lines[i];
        if (L->dead) continue;                          /* removed by a prior pass */
        if (L->raw[0] == '\0') continue;                /* blank */
        if (L->mnem[0] == '\0') {
            if (L->label[0] != '\0') return 0;          /* label = barrier */
            continue;                                   /* comment-only */
        }
        if (reads_carry(L->mnem))  return 0;            /* carry consumed: LIVE */
        if (is_return(L->mnem))    return 1;            /* carry dead at return */
        if (writes_carry(L->mnem)) return 1;            /* carry overwritten */
        if (is_control(L->mnem))   return 0;            /* other transfer: barrier */
        /* carry-neutral op (LDA/STA/REP/SEP/...) -> keep scanning */
    }
    return 0;                                            /* fell off end: live */
}

/* True if the overflow flag set by line `idx` is dead.  fcc reads V only with
 * BVC/BVS, and every one of those -- 4,238 in 424 files, measured 2026-10-23 --
 * takes V from an ADC, SBC or BIT earlier in its own block, so V is dead at a
 * block's end and a call; inside the block a V-writer kills it and a BVC/BVS
 * or a PHP keeps it. */
static int
v_dead_after(Line *lines, size_t n, size_t idx)
{
    size_t i;
    for (i = idx + 1; i < n; i++) {
        Line *L = &lines[i];
        const char *m = L->mnem;
        if (L->dead || L->raw[0] == '\0') continue;
        if (L->label[0] != '\0') return 1;
        if (m[0] == '\0') continue;
        if (strcmp(m,"BVC")==0 || strcmp(m,"BVS")==0 || strcmp(m,"PHP")==0) return 0;
        if (strcmp(m,"ADC")==0 || strcmp(m,"SBC")==0 || strcmp(m,"BIT")==0 ||
            strcmp(m,"CLV")==0 || strcmp(m,"PLP")==0) return 1;
        if (is_control(m)) return 1;
    }
    return 1;
}

/* Pattern: STA m ; LDA m (adjacent, same operand, LDA not a branch target)
 * -> the LDA reloads what A already holds; drop it when its NZ is dead. */
static void
pat_staload_forward(Line *lines, size_t n)
{
    size_t i;
    for (i = 0; i < n; i++) {
        long j;
        if (lines[i].dead) continue;
        if (strcmp(lines[i].mnem, "STA") != 0) continue;
        j = next_insn_no_label(lines, n, i + 1);
        if (j < 0) continue;
        if (strcmp(lines[(size_t)j].mnem, "LDA") != 0) continue;
        if (strcmp(lines[(size_t)j].operand, lines[i].operand) != 0) continue;
        if (nz_dead_after(lines, n, (size_t)j))
            lines[(size_t)j].dead = 1;
    }
}

/* Pattern: `BRA/BRL target` where the immediately-following labeled line is
 * exactly `target` -> the branch is a no-op fall-through; delete it. */
static void
pat_bra_to_next(Line *lines, size_t n)
{
    size_t i;
    for (i = 0; i < n; i++) {
        long j;
        if (lines[i].dead) continue;
        if (strcmp(lines[i].mnem, "BRA") != 0 &&
            strcmp(lines[i].mnem, "BRL") != 0) continue;
        j = next_labeled_line(lines, i + 1, n);
        if (j >= 0 && strcmp(lines[(size_t)j].label, lines[i].operand) == 0) {
            long k;
            lines[i].dead = 1;
            /* A far conditional (`B?? *+5' / `BRL L') skips this BRL by its
             * size: with the BRL gone, the skip would land 3 bytes past the
             * target, mid-instruction.  Both ways now reach L: drop it too. */
            for (k = (long)i - 1; k >= 0 && lines[(size_t)k].dead; k--)
                ;
            if (k >= 0 && lines[(size_t)k].label[0] == '\0' &&
                lines[(size_t)k].mnem[0] == 'B' &&
                strcmp(lines[(size_t)k].operand, "*+5") == 0)
                lines[(size_t)k].dead = 1;
        }
    }
}

/* Pattern: adjacent width directives with no instruction between.
 *   REP x ; REP x  -> drop 2nd    SEP x ; SEP x  -> drop 2nd
 *   SEP x ; REP x  -> drop both   REP x ; SEP x  -> drop both
 * "adjacent" = the next live instruction line, unlabeled, no op between. */
static void
pat_repsep_adjacent(Line *lines, size_t n)
{
    size_t i;
    for (i = 0; i < n; i++) {
        long j;
        int a_rep, a_sep, b_rep, b_sep;
        if (lines[i].dead) continue;
        a_rep = strcmp(lines[i].mnem, "REP") == 0;
        a_sep = strcmp(lines[i].mnem, "SEP") == 0;
        if (!a_rep && !a_sep) continue;
        j = next_insn_no_label(lines, n, i + 1);
        if (j < 0) continue;
        b_rep = strcmp(lines[(size_t)j].mnem, "REP") == 0;
        b_sep = strcmp(lines[(size_t)j].mnem, "SEP") == 0;
        if (!b_rep && !b_sep) continue;
        if (strcmp(lines[i].operand, lines[(size_t)j].operand) != 0) continue;
        if ((a_rep && b_rep) || (a_sep && b_sep)) {
            lines[(size_t)j].dead = 1;          /* duplicate: drop 2nd (unlabeled) */
        } else if (lines[i].label[0] == '\0') {
            /* cancel (SEP<->REP): drop both.  Guard the FIRST line being unlabeled
             * so we never delete a branch-target label.  (NOTE: this adjacent cancel
             * does not re-prove net-zero via MX like pat_empty_width_roundtrip does;
             * it is sound only because fcc never emits an adjacent same-operand
             * SEP/REP from a non-default width -- it always interposes an MX, which
             * routes such wrappers to pat_empty_width_roundtrip instead.  This branch
             * is dead on the real corpus.) */
            lines[i].dead = 1;
            lines[(size_t)j].dead = 1;
        }
    }
}

/* Decode "#<decimal>" in 1..2 (the fcc-emitted small increments), else -1.
 * fcc emits decimal immediates (`ADC #1`); the #$/#%/#' guards are defensive. */
static int
small_imm(const char *op)
{
    int v = 0;
    const char *p = op;
    if (*p != '#') return -1;
    p++;
    if (*p == '$' || *p == '%' || *p == '\'') return -1;   /* hex/bin/char imm */
    if (*p < '0' || *p > '9') return -1;
    for (; *p >= '0' && *p <= '9'; p++) v = v * 10 + (*p - '0');
    if (*p != '\0') return -1;                              /* trailing junk */
    return (v >= 1 && v <= 2) ? v : -1;
}

/* Pattern: CLC ; ADC #k (k in 1..2, carry output dead) -> k× INC ;
 *          SEC ; SBC #k                                -> k× DEC.
 * INC/DEC here are the IMPLIED-accumulator forms (Merlin32 spelling — it does
 * not accept the INA/DEA mnemonics); they do NOT affect carry, so the fold is
 * valid only when the add/sub's carry is provably dead (carry_dead_after).  A
 * labelled CLC/SEC is a branch target and is never folded.  Drops the CLC/SEC
 * (a byte + a cycle); common on pointer and index increments in hot loops. */
static void
pat_clcadc_to_ina(Line *lines, size_t n)
{
    size_t i;
    for (i = 0; i < n; i++) {
        long j;
        int k, is_add, is_sub;
        const char *mn;
        char buf[PH_TOK + 16];
        char *d1, *d2;
        if (lines[i].dead) continue;
        if (lines[i].label[0] != '\0') continue;        /* branch target — skip */
        is_add = strcmp(lines[i].mnem, "CLC") == 0;
        is_sub = strcmp(lines[i].mnem, "SEC") == 0;
        if (!is_add && !is_sub) continue;
        j = next_insn_no_label(lines, n, i + 1);
        if (j < 0) continue;
        if (is_add && strcmp(lines[(size_t)j].mnem, "ADC") != 0) continue;
        if (is_sub && strcmp(lines[(size_t)j].mnem, "SBC") != 0) continue;
        k = small_imm(lines[(size_t)j].operand);
        if (k < 0) continue;
        if (!carry_dead_after(lines, n, (size_t)j)) continue;
        if (!v_dead_after(lines, n, (size_t)j)) continue;

        mn = is_add ? "INC" : "DEC";                    /* implied-A (Merlin32) */
        snprintf(buf, sizeof buf, "                %s", mn);
        /* Allocate everything before mutating, so an OOM leaves the pair
         * untouched (never a half-fold that adds the wrong amount). */
        d1 = dup_range(buf, strlen(buf));
        d2 = (k == 2) ? dup_range(buf, strlen(buf)) : NULL;
        if (!d1 || (k == 2 && !d2)) { free(d1); free(d2); continue; }

        free(lines[i].raw);                             /* CLC/SEC -> INC/DEC */
        lines[i].raw = d1;
        parse_fields(&lines[i]);
        if (k == 2) {                                   /* ADC/SBC #2 -> 2nd INC/DEC */
            free(lines[(size_t)j].raw);
            lines[(size_t)j].raw = d2;
            parse_fields(&lines[(size_t)j]);
        } else {                                        /* ADC/SBC #1 -> drop it */
            lines[(size_t)j].dead = 1;
        }
    }
}

/* Memory-reading mnemonics (operand value is read).  PEI pushes the WORD
 * at its DP operand — a read (P3-2.2: the FPR arg pushes `PEI _fcc_fprK/
 * +2`; missing it made pat_dead_store delete a live bank store between
 * two same-slot stores, which broke every string arg in jsh). */
static int reads_mem(const char *m)
{
    return strcmp(m,"LDA")==0||strcmp(m,"ADC")==0||strcmp(m,"SBC")==0||
           strcmp(m,"CMP")==0||strcmp(m,"CPX")==0||strcmp(m,"CPY")==0||
           strcmp(m,"ORA")==0||strcmp(m,"AND")==0||strcmp(m,"EOR")==0||
           strcmp(m,"BIT")==0||strcmp(m,"LDX")==0||strcmp(m,"LDY")==0||
           strcmp(m,"PEI")==0;
}
/* Read-modify-write mnemonics (read loc, then write it). */
static int is_rmw(const char *m)
{
    return strcmp(m,"INC")==0||strcmp(m,"DEC")==0||strcmp(m,"ASL")==0||
           strcmp(m,"LSR")==0||strcmp(m,"ROL")==0||strcmp(m,"ROR")==0||
           strcmp(m,"TRB")==0||strcmp(m,"TSB")==0;
}
/* A plain store target: a named DP/abs location, no index, no indirect. */
static int is_plain_loc(const char *op)
{
    return op[0] != '\0' && strchr(op,'[')==NULL &&
           strchr(op,'(')==NULL && strchr(op,',')==NULL;
}
/* True if line L READS location `loc`.  THE safety-critical core -- must be
 * complete (a missed read => a removed live store => a miscompile):
 *   (1) direct/indexed read by a memory-reading or RMW mnemonic: operand is
 *       loc, "loc,X", or "loc,Y";
 *   (2) INDIRECT through loc by ANY mnemonic (incl. STA [loc],Y): operand has a
 *       [base]/(base) and loc is base, "base+1", or "base+2" (the 24-bit [dp]
 *       reads all three bytes; the bank `_fcc_ptr+2` IS read by `[_fcc_ptr]`).
 *       The exact-suffix test avoids conflating a different scratch (`_fcc_ptr2`
 *       is NOT read by `[_fcc_ptr]`). */
static int reads_loc(const Line *L, const char *loc)
{
    const char *op = L->operand;
    size_t ll = strlen(loc);
    if (reads_mem(L->mnem) || is_rmw(L->mnem)) {
        if (strcmp(op, loc) == 0) return 1;
        if (strncmp(op, loc, ll) == 0 &&
            (strcmp(op+ll, ",X")==0 || strcmp(op+ll, ",Y")==0)) return 1;
    }
    {
        const char *lb = strchr(op, '[');
        const char *rb = lb ? strchr(lb, ']') : NULL;
        if (!lb) { lb = strchr(op, '('); rb = lb ? strchr(lb, ')') : NULL; }
        if (lb && rb && rb > lb + 1) {
            char base[PH_TOK];
            size_t bl = (size_t)(rb - lb - 1);
            if (bl < PH_TOK) {
                memcpy(base, lb+1, bl); base[bl] = '\0';
                if (strcmp(loc, base) == 0) return 1;
                {
                    size_t bbl = strlen(base);
                    unsigned bn, ln;
                    if (strncmp(loc, base, bbl) == 0 &&
                        (strcmp(loc+bbl,"+1")==0 || strcmp(loc+bbl,"+2")==0)) return 1;
                    /* An img pair holding a pointer is two word cells, so
                     * the bank byte `[_fcc_img{n}]' reads is the next
                     * cell's: _fcc_img{n+1} by name, not _fcc_img{n}+2. */
                    if (sscanf(base, "_fcc_img%u", &bn) == 1 &&
                        sscanf(loc, "_fcc_img%u", &ln) == 1 && ln == bn + 1) {
                        char nm[PH_TOK];
                        snprintf(nm, sizeof nm, "_fcc_img%u", ln);
                        if (strcmp(loc, nm) == 0) return 1;
                    }
                }
            }
        }
    }
    return 0;
}

/* --- option C: A-register liveness (deletion of dead loads) ------------------
 * Mnemonics that OVERWRITE A WITHOUT reading the prior A (so an unread prior A is
 * dead here): LDA/PLA/TXA/TYA/TSC/TDC. */
static int defines_a(const char *m)
{
    return strcmp(m,"LDA")==0||strcmp(m,"PLA")==0||strcmp(m,"TXA")==0||
           strcmp(m,"TYA")==0||strcmp(m,"TSC")==0||strcmp(m,"TDC")==0;
}

/* A line that PROVABLY neither reads nor writes A and is not a control/P-state/
 * WIDTH barrier -- safe to scan PAST while proving a prior A dead.  POSITIVE
 * allowlist: anything not listed (unknown mnemonic, macro, A-reader, branch,
 * PHP/PLP, MVN/MVP, DO/ELSE/FIN) is opaque -> the scan stops and KEEPS the load
 * (fail-safe). */
static int is_a_neutral(const Line *L)
{
    const char *m = L->mnem;
    /* REP (widen) + MX (assemble-time annotation) are neutral.  SEP is NOT: a
     * width NARROWING means a later defines_a redefine may execute at 8-bit = a
     * PARTIAL (low-byte) overwrite, leaving a prior 16-bit A's high byte LIVE, so
     * we must not scan past a narrowing while trusting a later full-overwrite (a
     * REP widening is safe -- a wider redefine fully covers a narrower value). */
    if (strcmp(m,"REP")==0||strcmp(m,"MX")==0) return 1;
    if (strcmp(m,"CLC")==0||strcmp(m,"SEC")==0||strcmp(m,"CLD")==0||
        strcmp(m,"SED")==0||strcmp(m,"CLV")==0||strcmp(m,"CLI")==0||
        strcmp(m,"SEI")==0) return 1;
    if (strcmp(m,"LDX")==0||strcmp(m,"LDY")==0||strcmp(m,"STX")==0||
        strcmp(m,"STY")==0||strcmp(m,"STZ")==0||strcmp(m,"INX")==0||
        strcmp(m,"INY")==0||strcmp(m,"DEX")==0||strcmp(m,"DEY")==0||
        strcmp(m,"CPX")==0||strcmp(m,"CPY")==0||strcmp(m,"PHX")==0||
        strcmp(m,"PHY")==0||strcmp(m,"PLX")==0||strcmp(m,"PLY")==0) return 1;
    if (strcmp(m,"NOP")==0) return 1;
    /* memory RMW (operand form) -- A-neutral.  TSB/TRB are EXCLUDED: even in their
     * memory form they READ A (M |= A / M &= ~A), so they are A-readers, not
     * neutral (kept in is_rmw for the dead-store read scan, which is correct). */
    if ((strcmp(m,"INC")==0||strcmp(m,"DEC")==0||strcmp(m,"ASL")==0||
         strcmp(m,"LSR")==0||strcmp(m,"ROL")==0||strcmp(m,"ROR")==0)
        && L->operand[0]!='\0')
        return 1;
    return 0;
}

/* True if the accumulator DEFINED by line `idx` is provably dead: scanning the
 * fall-through path, A is redefined (defines_a) before being read, with only
 * is_a_neutral lines between.  Any label, A-reader, barrier, or unknown line stops
 * the scan and keeps the load.  Mirrors nz_dead_after / carry_dead_after. */
static int
dead_a_after(Line *lines, size_t n, size_t idx)
{
    size_t j;
    for (j = idx + 1; j < n; j++) {
        Line *L = &lines[j];
        if (L->dead) continue;
        if (L->raw[0] == '\0') continue;             /* blank */
        if (L->mnem[0] == '\0') {
            if (L->label[0] != '\0') return 0;       /* label-only = barrier */
            continue;                                /* comment-only */
        }
        if (L->label[0] != '\0') return 0;           /* labeled insn = branch target */
        if (defines_a(L->mnem)) return 1;            /* A overwritten unread -> dead */
        if (is_a_neutral(L)) continue;               /* provably no A touch -> skip */
        return 0;                                    /* A-reader / barrier / unknown -> keep */
    }
    return 0;                                         /* fell off end: A may be live-out */
}

/* Index of the (unlabeled) MX directive immediately following `from` (skipping
 * blank/comment/dead), or -1 if the next real line isn't an MX or is a labeled MX
 * (a labeled MX is a branch target -> never delete it -> bail). */
static long
mx_after(Line *lines, size_t n, size_t from)
{
    size_t j;
    for (j = from + 1; j < n; j++) {
        if (lines[j].dead) continue;
        if (lines[j].raw[0] == '\0') continue;
        if (lines[j].mnem[0] == '\0') { if (lines[j].label[0]!='\0') return -1; continue; }
        return (strcmp(lines[j].mnem,"MX")==0 && lines[j].label[0]=='\0') ? (long)j : -1;
    }
    return -1;
}

/* Index of the prevailing MX directive in effect just before line `i` (the most
 * recent MX, scanning back, before any BB boundary), or -1 if none in this BB. */
static long
mx_before(Line *lines, size_t n, size_t i)
{
    long j;
    (void)n;
    for (j = (long)i - 1; j >= 0; j--) {
        Line *L = &lines[(size_t)j];
        if (L->dead) continue;
        if (L->raw[0] == '\0') continue;
        if (L->mnem[0] == '\0') { if (L->label[0]!='\0') return -1; continue; }
        if (strcmp(L->mnem,"MX")==0) return j;
        if (L->label[0] != '\0') return -1;          /* BB boundary */
        if (is_control(L->mnem)) return -1;          /* BB boundary */
    }
    return -1;
}

/* Pattern: empty width round-trip.  A `SEP #$k` .. `REP #$k` (or REP..SEP) pair
 * with NO real instruction between (only MX/dead/comment) assembled nothing in the
 * toggled width.  It is removable iff the prevailing MX BEFORE the block equals the
 * MX after it (the assembler's own width ground-truth) -> net-zero -> dropping the
 * SEP, the REP, and their MX annotations leaves both merlin32's MX model and the
 * runtime P-width unchanged.  (Same-operand SEP/REP is NOT sufficient: if the bit
 * was already set, the pair is a net change.)  The adjacent (no-MX-between) case is
 * handled separately by pat_repsep_adjacent; this catches the MX-separated wrapper
 * around a removed bank store (which pat_repsep_adjacent's adjacency test misses). */
static void
pat_empty_width_roundtrip(Line *lines, size_t n)
{
    size_t i;
    for (i = 0; i < n; i++) {
        long j; size_t k; int a_sep, a_rep;
        if (lines[i].dead) continue;
        if (lines[i].label[0] != '\0') continue;
        a_sep = strcmp(lines[i].mnem,"SEP")==0;
        a_rep = strcmp(lines[i].mnem,"REP")==0;
        if (!a_sep && !a_rep) continue;
        j = -1;
        for (k = i + 1; k < n; k++) {
            Line *L = &lines[k];
            if (L->dead) continue;
            if (L->raw[0] == '\0') continue;
            if (L->mnem[0] == '\0') { if (L->label[0]!='\0') { j = -1; break; } continue; }
            if (strcmp(L->mnem,"MX")==0) {               /* skip width annotation */
                if (L->label[0]!='\0') { j = -1; break; }  /* labeled MX = barrier */
                continue;
            }
            j = (long)k; break;
        }
        if (j < 0) continue;
        {
            Line *J = &lines[(size_t)j];
            int b_sep = strcmp(J->mnem,"SEP")==0;
            int b_rep = strcmp(J->mnem,"REP")==0;
            long emx, xmx; size_t t;
            if (J->label[0] != '\0') continue;
            if (!((a_sep && b_rep) || (a_rep && b_sep))) continue;   /* must be opposite */
            emx = mx_before(lines, n, i);
            xmx = mx_after(lines, n, (size_t)j);
            if (emx < 0 || xmx < 0) continue;                        /* can't prove net-zero */
            if (strcmp(lines[(size_t)emx].operand, lines[(size_t)xmx].operand) != 0) continue;
            lines[i].dead = 1;
            J->dead = 1;
            /* EVERY MX strictly between the SEP and the REP (all unlabeled -- the
             * scan bailed on a labeled one), plus the exit MX after the REP.
             * Deleting ALL interior MX (not just the first) keeps the assembler's
             * width consistent even if more than one ever appears. */
            for (t = i + 1; t < (size_t)j; t++)
                if (!lines[t].dead && strcmp(lines[t].mnem,"MX")==0)
                    lines[t].dead = 1;
            lines[(size_t)xmx].dead = 1;                 /* MX annotating the removed REP */
        }
    }
}

/* Pattern: dead LDA.  An unlabeled `LDA <x>` whose loaded value is never read
 * before A is redefined -> drop it.  Runs AFTER pat_dead_store so the feeding
 * `LDA #k` left by a removed `STA _fcc_ptr+2` becomes dead here. */
static void
pat_dead_lda(Line *lines, size_t n)
{
    size_t i;
    for (i = 0; i < n; i++) {
        if (lines[i].dead) continue;
        if (strcmp(lines[i].mnem, "LDA") != 0) continue;
        if (lines[i].label[0] != '\0') continue;     /* labeled = branch target */
        if (dead_a_after(lines, n, i)) lines[i].dead = 1;
    }
}

/* (option C pattern 3 "redundant value re-store" was implemented + measured here:
 * 0 corpus yield -- fcc emits no LDA loc/STA loc or same-value re-store the prior
 * passes don't already cover -- so it was DROPPED.  Design retained in the plan
 * doc 2026-06-29-fcc2-deadcode-size-peephole-plan.md if ever revisited.) */

/* Pattern: dead store.  `STA <plain loc>` whose value is overwritten by a later
 * `STA <same loc>` in the same basic block, with NO read of loc between, is dead.
 * Conservative barriers (keep the store): a labeled line (branch target), any
 * control transfer (is_control), FGX2_FARCALL (far call), PHP/PLP (P-state),
 * MVN/MVP (block move may touch loc), an `STA loc,X`/`loc,Y` (ambiguous overwrite
 * of base==loc), or ANY read of loc (reads_loc, incl. [loc]/[loc],Y indirect and
 * STA [loc],Y).
 * INVARIANT: each scratch loc is stored at a single consistent M-width (fcc holds
 * _fcc_ptr/_fcc_img* at 16-bit, the bank byte _fcc_ptr+2 at 8-bit), so
 * the later STA fully overwrites the earlier one.  A SEP/REP between two same-loc
 * stores does not break this (both execute at the loc's fixed width).  If future
 * codegen ever stores the SAME loc at mixed widths with no read between, an 8-bit
 * STA would only partially overwrite a 16-bit one -> add M-width tracking then. */
static void
pat_dead_store(Line *lines, size_t n)
{
    size_t i, j;
    for (i = 0; i < n; i++) {
        const char *loc; size_t ll; int do_depth;
        if (lines[i].dead) continue;
        if (strcmp(lines[i].mnem, "STA") != 0) continue;
        if (lines[i].label[0] != '\0') continue;             /* never drop a labeled (branch-target) store */
        if (!is_plain_loc(lines[i].operand)) continue;
        /* correctness queue: ONLY fcc-internal scratch cells are dead-store
         * candidates.  A USER global's address can escape (`gpp = &gs`),
         * making a later read INDIRECT (`LDA [ptr]`) — textually invisible
         * to reads_loc, so the "no read between" proof is unsound for any
         * loc whose address can be taken.  Scratch (_fcc_*) addresses never
         * escape, which is the invariant this pass was designed around
         * (caught by M34/depth2: `gs = gbuf` dropped across an aliased
         * `(*gpp)[0]` read -> stale pointer). */
        if (strncmp(lines[i].operand, "_fcc_", 5) != 0) continue;
        loc = lines[i].operand; ll = strlen(loc);
        do_depth = 0;
        for (j = i + 1; j < n; j++) {
            Line *L = &lines[j];
            if (L->dead) continue;
            if (L->raw[0] == '\0') continue;                 /* blank */
            if (L->mnem[0] == '\0') {
                if (L->label[0] != '\0') break;              /* label = barrier */
                continue;                                    /* comment-only */
            }
            if (L->label[0] != '\0') break;                  /* labeled insn = barrier */
            if (reads_loc(L, loc)) break;                    /* loc read (any branch) -> keep */
            /* merlin32 conditional-assembly nesting (DO/ELSE/FIN): only one branch
             * assembles.  Scan THROUGH a block (a read in either branch already kept
             * us, above), but an overwrite is a SOUND dead-proof only at depth 0
             * (unconditional); a conditional overwrite (depth>0) might not assemble,
             * so keep scanning for a later depth-0 overwrite (or a read). */
            if (strcmp(L->mnem,"DO")==0)  { do_depth++; continue; }
            if (strcmp(L->mnem,"FIN")==0) { if (do_depth>0) do_depth--; continue; }
            if (strcmp(L->mnem,"ELSE")==0) continue;
            if (strcmp(L->mnem, "STA") == 0 && strcmp(L->operand, loc) == 0) {
                if (do_depth == 0) { lines[i].dead = 1; break; } /* unconditional -> dead */
                continue;                                    /* conditional overwrite -> keep looking */
            }
            if (is_control(L->mnem)) break;                  /* branch/call/return */
            /* FGX2 far call (--far-calls): emitted as the macro `FGX2_FARCALL fn`,
             * NOT a JSL, so is_control misses it.  It is a real cross-bank call whose
             * callee may read loc from memory -> a hard barrier (else a live store
             * before a far call, overwritten after, is wrongly dropped). */
            if (strcmp(L->mnem,"FGX2_FARCALL")==0) break;
            if (strcmp(L->mnem,"PHP")==0 || strcmp(L->mnem,"PLP")==0) break;
            if (strcmp(L->mnem,"MVN")==0 || strcmp(L->mnem,"MVP")==0) break;
            if (strcmp(L->mnem, "STA") == 0 &&
                strncmp(L->operand, loc, ll) == 0 &&
                (strcmp(L->operand+ll, ",X")==0 || strcmp(L->operand+ll, ",Y")==0))
                break;                                       /* STA loc,X/,Y ambiguous */
            /* else: does not touch loc (incl. STA loc+2, a different byte) -> continue */
        }
    }
}

/* "#<decimal>" or "#$<hex>" -> its value in 0..65535, else -1.  Anything
 * else (a symbol, an expression, a char or binary literal) is left alone. */
static long
imm16(const char *op)
{
    long v = 0;
    const char *p = op;
    if (*p++ != '#') return -1;
    if (*p == '$') {
        p++;
        if (!isxdigit((unsigned char)*p)) return -1;
        for (; isxdigit((unsigned char)*p); p++)
            v = v * 16 + (isdigit((unsigned char)*p) ? *p - '0'
                                                     : (toupper((unsigned char)*p) - 'A' + 10));
    } else {
        if (*p < '0' || *p > '9') return -1;
        for (; *p >= '0' && *p <= '9'; p++) v = v * 10 + (*p - '0');
    }
    if (*p != '\0' || v > 0xFFFFL) return -1;
    return v;
}

/* Replace a line's text with `                <mn>     <op>`. */
static int
set_insn(Line *L, const char *mn, const char *op)
{
    char buf[PH_TOK * 2 + 32];
    char *d;
    snprintf(buf, sizeof buf, "                %-7s %s", mn, op);
    d = dup_range(buf, strlen(buf));
    if (!d) return 0;
    free(L->raw);
    L->raw = d;
    parse_fields(L);
    return 1;
}

/* Pattern: a negated literal.  `LDA #k ; EOR #$FFFF ; INC` is -k computed at
 * run time; `LDA #(-k & $FFFF)` loads it and sets N and Z from the same value.
 * fcc spells a negative literal this way (`c != -1').  The EOR #$FFFF fixes
 * the width at 16 bits. */
static void
pat_neg_const(Line *lines, size_t n)
{
    size_t i;
    for (i = 0; i < n; i++) {
        long j, k, v;
        char op[16];
        if (lines[i].dead || lines[i].label[0] != '\0') continue;
        if (strcmp(lines[i].mnem, "LDA") != 0) continue;
        if ((v = imm16(lines[i].operand)) < 0) continue;
        j = next_insn_no_label(lines, n, i + 1);
        if (j < 0 || strcmp(lines[j].mnem, "EOR") != 0 ||
            strcmp(lines[j].operand, "#$FFFF") != 0) continue;
        k = next_insn_no_label(lines, n, (size_t)j + 1);
        if (k < 0 || strcmp(lines[k].mnem, "INC") != 0 ||
            lines[k].operand[0] != '\0') continue;
        snprintf(op, sizeof op, "#$%04lX", (0x10000L - v) & 0xFFFFL);
        if (!set_insn(&lines[i], "LDA", op)) continue;
        lines[j].dead = 1;
        lines[k].dead = 1;
    }
}

/* The fcc runtime routines that take _fcc_tmp_b as an input (fcc_runtime.s:
 * every routine that loads it, and every routine that calls one of those). */
static int
tmpb_reader_call(const Line *L)
{
    static const char *t[] = {
        "_fcc_divs16", "_fcc_divu16", "_fcc_mods16", "_fcc_modu16",
        "_fcc_udiv16", "_fcc_mul16", "_fcc_eq16", "_fcc_ne16",
        "_fcc_lts16", "_fcc_les16", "_fcc_gts16", "_fcc_ges16",
        "_fcc_ltu16", "_fcc_leu16", "_fcc_gtu16", "_fcc_geu16",
        "_fcc_shl16", "_fcc_shr16", "_fcc_shrs16", NULL
    };
    int i;
    if (strcmp(L->mnem, "JSR") != 0 && strcmp(L->mnem, "JSL") != 0 &&
        strcmp(L->mnem, "FGX2_FARCALL") != 0) return 0;
    for (i = 0; t[i]; i++) if (strcmp(L->operand, t[i]) == 0) return 1;
    return 0;
}

static int
reads_tmpb(const Line *L)
{
    return reads_loc(L, "_fcc_tmp_b") || tmpb_reader_call(L);
}

static int
defines_tmpb(const Line *L)
{
    return (strcmp(L->mnem, "STA") == 0 || strcmp(L->mnem, "STX") == 0 ||
            strcmp(L->mnem, "STY") == 0 || strcmp(L->mnem, "STZ") == 0) &&
           strcmp(L->operand, "_fcc_tmp_b") == 0;
}

/* A label or a branch, jump or return ends a basic block.  A call does not:
 * fcc's code resumes after it.  DO/ELSE/FIN (conditional assembly) are
 * straight-line code. */
static int
ends_block(const Line *L)
{
    return L->label[0] != '\0' ||
           (is_control(L->mnem) && strcmp(L->mnem, "JSR") != 0 &&
            strcmp(L->mnem, "JSL") != 0);
}

/* _fcc_tmp_b IS NEVER LIVE ACROSS A BASIC BLOCK in fcc's output: it is the
 * second operand of one 16-bit operation, stored just before that operation
 * reads it.  Measured 2026-10-23 over every fcc-compiled file in the tree --
 * 23,776 reads in 381 tool and library files, 3,448 in 45 kernel files, each
 * preceded by a store in its own block.  The rules below rely on that, so each
 * unit is CHECKED for it first, and a unit where any read lacks an in-block
 * store gets none of them.  A line of an __asm block carries a sentinel
 * label, so it starts a block of its own: a read there fails the check. */
static int
tmpb_block_local(Line *lines, size_t n)
{
    size_t i;
    int defined = 0;
    for (i = 0; i < n; i++) {
        Line *L = &lines[i];
        if (L->dead || L->raw[0] == '\0') continue;
        if (L->label[0] != '\0') defined = 0;
        if (L->mnem[0] == '\0') continue;
        if (reads_tmpb(L) && !defined) return 0;
        if (defines_tmpb(L)) defined = 1;
        if (ends_block(L)) defined = 0;
    }
    return 1;
}

/* After line `idx`, is _fcc_tmp_b's value dead?  Given tmpb_block_local, it is
 * dead at the end of the block; inside it, a store kills it and a read keeps
 * it. */
static int
tmpb_dead_after(Line *lines, size_t n, size_t idx)
{
    size_t j;
    for (j = idx + 1; j < n; j++) {
        Line *L = &lines[j];
        if (L->dead || L->raw[0] == '\0') continue;
        if (L->label[0] != '\0') return 1;
        if (L->mnem[0] == '\0') continue;
        if (reads_tmpb(L)) return 0;
        if (defines_tmpb(L)) return 1;
        if (ends_block(L)) return 1;
    }
    return 1;
}

/* Pattern: a constant passed through _fcc_tmp_b.  fcc materialises the
 * second operand of a 16-bit operation there even when it is a literal:
 *   LDA #k ; STA _fcc_tmp_b ; TXA ; CMP _fcc_tmp_b
 * The reader takes the literal instead -- `CMP #k', `SBC #k', `AND #k',
 * `LDX #k' -- and the store goes, when _fcc_tmp_b is dead after the reader.
 * An immediate operand gives the reader the same value and the same flags.
 * Between the store and the reader there may be no label, no control
 * transfer, no other store to _fcc_tmp_b and no width change (an 8-bit store
 * read at 16 bits is not the literal).  `LDA #k' itself is left for
 * pat_dead_lda, which drops it when A is overwritten unread, as it is by the
 * TXA above; when the load sat alone between a PHA and a PLA, the pair goes
 * with it. */
static int
imm_reader(const Line *L)
{
    static const char *t[] = { "CMP", "SBC", "ADC", "AND", "ORA", "EOR",
                               "LDA", "LDX", "LDY", "CPX", "CPY", NULL };
    int i;
    if (strcmp(L->operand, "_fcc_tmp_b") != 0) return 0;
    for (i = 0; t[i]; i++) if (strcmp(L->mnem, t[i]) == 0) return 1;
    return 0;
}

static void
pat_tmpb_const(Line *lines, size_t n)
{
    size_t i;
    for (i = 0; i < n; i++) {
        long b, r = -1, p, q;
        size_t j;
        if (lines[i].dead || lines[i].label[0] != '\0') continue;
        if (strcmp(lines[i].mnem, "LDA") != 0 || imm16(lines[i].operand) < 0)
            continue;
        b = next_insn_no_label(lines, n, i + 1);
        if (b < 0 || strcmp(lines[b].mnem, "STA") != 0 ||
            strcmp(lines[b].operand, "_fcc_tmp_b") != 0) continue;
        for (j = (size_t)b + 1; j < n; j++) {
            Line *L = &lines[j];
            if (L->dead || L->raw[0] == '\0') continue;
            if (L->label[0] != '\0') break;
            if (L->mnem[0] == '\0') continue;
            if (reads_tmpb(L)) { r = (long)j; break; }
            if (defines_tmpb(L) || ends_block(L) || is_control(L->mnem)) break;
            if (strcmp(L->mnem, "SEP") == 0 || strcmp(L->mnem, "REP") == 0 ||
                strcmp(L->mnem, "MX") == 0) break;
            if (strcmp(L->mnem, "DO") == 0 || strcmp(L->mnem, "ELSE") == 0 ||
                strcmp(L->mnem, "FIN") == 0) break;
        }
        if (r < 0 || !imm_reader(&lines[r])) continue;
        if (!tmpb_dead_after(lines, n, (size_t)r)) continue;
        if (!set_insn(&lines[r], lines[r].mnem, lines[i].operand)) continue;
        lines[b].dead = 1;
        if (!dead_a_after(lines, n, i)) continue;
        lines[i].dead = 1;
        /* A PHA ; LDA #k ; PLA bracket with nothing else inside is now empty. */
        p = -1;
        for (j = i; j-- > 0; ) {
            if (lines[j].dead || lines[j].raw[0] == '\0') continue;
            if (lines[j].mnem[0] == '\0' && lines[j].label[0] == '\0') continue;
            p = (long)j;
            break;
        }
        q = next_insn_no_label(lines, n, i + 1);
        if (p >= 0 && q >= 0 && lines[p].label[0] == '\0' &&
            strcmp(lines[p].mnem, "PHA") == 0 && strcmp(lines[q].mnem, "PLA") == 0 &&
            nz_dead_after(lines, n, (size_t)q)) {
            lines[p].dead = 1;
            lines[q].dead = 1;
        }
    }
}

/* Pattern: a store to _fcc_tmp_b that nothing reads.  pat_dead_store needs a
 * second store to prove the first dead; given tmpb_block_local, the end of the
 * block proves it too. */
static void
pat_tmpb_dead_store(Line *lines, size_t n)
{
    size_t i;
    for (i = 0; i < n; i++) {
        if (lines[i].dead || lines[i].label[0] != '\0') continue;
        if (defines_tmpb(&lines[i]) && tmpb_dead_after(lines, n, i))
            lines[i].dead = 1;
    }
}

/* --- branch relaxation --- */

static int
mn_is(const char *m, const char *const *t)
{
    for (; *t; t++) if (strcmp(m, *t) == 0) return 1;
    return 0;
}

static const char *const ph_cond_br[] = {
    "BEQ","BNE","BCC","BCS","BMI","BPL","BVC","BVS", NULL
};

/* The runtime's direct-page cells (fcc_runtime.s): an operand naming one,
 * with or without a +k, assembles to a one-byte address. */
static int
dp_operand(const char *o)
{
    static const char *const dp[] = {
        "_fcc_fb","_fcc_sfp","_fcc_stkfloor","_fcc_ptr","_fcc_ptr2",
        "_fcc_fp","_fcc_long_hi","_fcc_long_b_lo","_fcc_long_b_hi", NULL
    };
    char nm[PH_TOK];
    size_t k = 0;
    while (o[k] && o[k] != '+' && o[k] != ',' && k + 1 < sizeof nm) {
        nm[k] = o[k];
        k++;
    }
    nm[k] = '\0';
    if ((strncmp(nm, "_fcc_fpr", 8) == 0 && nm[8] >= '0' && nm[8] <= '7' && !nm[9]) ||
        (strncmp(nm, "_fcc_img", 8) == 0 && isdigit((unsigned char)nm[8])))
        return 1;
    return mn_is(nm, dp);
}

/* An upper bound on the bytes Merlin32 assembles line L to, or -1 when this
 * does not know the line. */
static int
insn_size_ub(const Line *L)
{
    static const char *const none[] = {
        "MX","ENT","EQU","=","ANOP","FGX2_EXPORT","FGX_SECT","FGX_ENDS",
        "FGX2_MODE","FGX2_RELOC_COUNT", NULL
    };
    static const char *const one[] = {
        "CLC","SEC","CLI","SEI","CLV","CLD","SED","TAX","TAY","TXA","TYA",
        "TSX","TXS","TCS","TSC","TCD","TDC","TXY","TYX","XBA","XCE","INX",
        "INY","DEX","DEY","NOP","PHA","PLA","PHX","PLX","PHY","PLY","PHB",
        "PLB","PHD","PLD","PHK","PHP","PLP","RTS","RTL","RTI","INA","DEA", NULL
    };
    static const char *const acc[] = {
        "INC","DEC","ASL","LSR","ROL","ROR", NULL
    };
    static const char *const longable[] = {
        "LDA","STA","ADC","SBC","AND","ORA","EOR","CMP", NULL
    };
    static const char *const mem[] = {
        "LDX","LDY","STX","STY","STZ","INC","DEC","ASL","LSR","ROL","ROR",
        "BIT","CPX","CPY","TSB","TRB", NULL
    };
    static const char *const lng[] = {
        "LDAL","STAL","ADCL","SBCL","ANDL","ORAL","EORL","CMPL","JSL","JML",
        "FGX2_FARCALL", NULL
    };
    const char *m = L->mnem, *o = L->operand;
    size_t ml = strlen(m);

    if (!m[0] || mn_is(m, none)) return 0;
    if (mn_is(m, one)) return 1;
    if (mn_is(m, acc) && (!o[0] || strcmp(o, "A") == 0)) return 1;
    if (mn_is(m, ph_cond_br) || strcmp(m, "BRA") == 0) return 2;
    if (strcmp(m, "BRL") == 0 || strcmp(m, "PER") == 0 ||
        strcmp(m, "PEA") == 0 || strcmp(m, "JSR") == 0) return 3;
    if (strcmp(m, "PEI") == 0 || strcmp(m, "REP") == 0 ||
        strcmp(m, "SEP") == 0) return 2;
    if (mn_is(m, lng) || strcmp(m, "JMP") == 0) return 4;
    if (!o[0]) return -1;
    if (ml > 1 && m[ml - 1] == ':') return 3;      /* forced absolute */
    if (!mn_is(m, longable) && !mn_is(m, mem)) return -1;
    if (o[0] == '#') return 3;
    if (o[0] == '(' || o[0] == '[' || strstr(o, ",S")) return 2;
    if (dp_operand(o)) return 2;
    return mn_is(m, longable) && !strstr(o, ",Y") ? 4 : 3;
}

/* A lower bound on the same, 0 when not known. */
static int
insn_size_lb(const Line *L)
{
    static const char *const exact[] = {
        "BRL","PER","PEA","JSR","LDAL","STAL","ADCL","SBCL","ANDL","ORAL",
        "EORL","CMPL","JSL","JML","FGX2_FARCALL", NULL
    };
    int ub = insn_size_ub(L);
    if (ub <= 1) return ub < 0 ? 0 : ub;
    return mn_is(L->mnem, exact) ? ub : 2;
}

typedef struct { const char *name; size_t line; } LabelRef;

static int
labelref_cmp(const void *a, const void *b)
{
    return strcmp(((const LabelRef *)a)->name, ((const LabelRef *)b)->name);
}

/* The unit's code labels, sorted by name.  Labels are never added, removed
 * or moved by a pattern, so one table serves the whole run. */
static LabelRef *g_lab;
static size_t    g_nlab;

static int
labels_build(Line *lines, size_t n)
{
    size_t i;
    g_nlab = 0;
    g_lab = malloc((n + 1) * sizeof *g_lab);
    if (!g_lab) return 0;
    for (i = 0; i < n; i++)
        if (lines[i].label[0] && strcmp(lines[i].mnem, "EQU") != 0 &&
            strcmp(lines[i].mnem, "=") != 0) {
            g_lab[g_nlab].name = lines[i].label;
            g_lab[g_nlab].line = i;
            g_nlab++;
        }
    qsort(g_lab, g_nlab, sizeof *g_lab, labelref_cmp);
    return 1;
}

/* The line a code label is defined on, or -1 if none or more than one. */
static long
label_line(const char *name)
{
    LabelRef key, *r;
    if (!g_lab) return -1;
    key.name = name;
    r = bsearch(&key, g_lab, g_nlab, sizeof *g_lab, labelref_cmp);
    if (!r) return -1;
    if ((r > g_lab && strcmp(r[-1].name, name) == 0) ||
        (r + 1 < g_lab + g_nlab && strcmp(r[1].name, name) == 0))
        return -1;
    return (long)r->line;
}

/* What a stretch of code does to the carry first: C_READ, C_WRITE, or
 * C_NONE when it does neither. */
enum { C_NONE, C_WRITE, C_READ };

static int
carry_effect(const Line *L)
{
    const char *m = L->mnem;
    if (reads_carry(m)) return C_READ;
    if (writes_carry(m) || strcmp(m, "ASL") == 0 || strcmp(m, "LSR") == 0)
        return C_WRITE;
    return C_NONE;
}

/* What a line does to X first, as carry_effect does for the carry.  A call
 * may take an argument in X -- setjmp and longjmp take the jmp_buf there --
 * and a caller may read it after a return, so dead_on_paths counts both as
 * reads; only a write on every path makes X dead. */
static int
x_effect(const Line *L)
{
    static const char *const r[] = {
        "TXA","TXY","TXS","STX","PHX","CPX","INX","DEX","MVN","MVP",
        "RTL","RTS","RTI", NULL
    };
    static const char *const w[] = {
        "LDX","TAX","TSX","TYX","PLX", NULL
    };
    if (mn_is(L->mnem, r) || strncmp(L->mnem, "FGX2_", 5) == 0 ||
        strstr(L->operand, ",X") || strstr(L->operand, ",x"))
        return C_READ;
    if (mn_is(L->mnem, w)) return C_WRITE;
    return C_NONE;
}

/* The first effect `eff' finds in the arms of the DO at line `d': C_WRITE
 * when both write before reading, C_READ when either may read (or holds what
 * this does not follow), else C_NONE.  *fin is the line of its FIN. */
static int
do_arms_effect(Line *lines, size_t n, size_t d, size_t *fin,
               int (*eff)(const Line *))
{
    int arm[2] = { C_NONE, C_NONE }, k = 0;
    size_t i;
    for (i = d + 1; i < n; i++) {
        const Line *L = &lines[i];
        if (L->dead || !L->mnem[0]) {
            if (L->label[0]) return C_READ;
            continue;
        }
        if (L->label[0]) return C_READ;
        if (strcmp(L->mnem, "ELSE") == 0) { k = 1; continue; }
        if (strcmp(L->mnem, "FIN") == 0) {
            *fin = i;
            if (arm[0] == C_READ || arm[1] == C_READ) return C_READ;
            return arm[0] == C_WRITE && arm[1] == C_WRITE ? C_WRITE : C_NONE;
        }
        if (strcmp(L->mnem, "DO") == 0 || L->mnem[0] == 'B' ||
            is_control(L->mnem) || insn_size_ub(L) < 0)
            return C_READ;
        if (arm[k] == C_NONE) arm[k] = eff(L);
    }
    return C_READ;
}

/* True if what `eff' tracks (the carry, X) is dead at line `from' on every
 * path: written, or the function returned, before anything reads it.  A
 * conditional branch that does not read it is followed to its label as well
 * as through, and BRA/BRL to theirs, `depth' branches deep.  A call `eff'
 * does not name, a jump, `__asm' text or a line this does not know reads it. */
static int is_helper_call(const Line *L);
/* Set while the img alias asks: an _fcc_ runtime helper touches only the
 * runtime's own cells ($E8 and up), so it is walked past like any other line. */
static int g_dop_helpers_pass;

static int
dead_on_paths(Line *lines, size_t n, size_t from, int depth,
              int (*eff)(const Line *))
{
    size_t i, fin;
    for (i = from; i < n && i < from + 512; i++) {
        Line *L = &lines[i];
        const char *m = L->mnem;
        if (strcmp(L->label, "@__asm") == 0) return 0;
        if (L->dead || !m[0]) continue;
        if (strcmp(m, "DO") == 0) {
            int e = do_arms_effect(lines, n, i, &fin, eff);
            if (e != C_NONE) return e == C_WRITE;
            i = fin;
            continue;
        }
        if (strcmp(m, "ELSE") == 0 || strcmp(m, "FIN") == 0) return 0;
        switch (eff(L)) {
        case C_READ:  return 0;
        case C_WRITE: return 1;
        }
        if (is_return(m)) return 1;
        if (reads_nz(m) || strcmp(m, "BVC") == 0 || strcmp(m, "BVS") == 0 ||
            strcmp(m, "BRA") == 0 || strcmp(m, "BRL") == 0) {
            const char *tgt = L->operand;
            long t;
            if (strcmp(tgt, "*+5") == 0 && m[1] != 'R') {  /* `B!cc *+5 ; BRL L' */
                long j = next_insn_no_label(lines, n, i + 1);
                if (j < 0 || strcmp(lines[j].mnem, "BRL") != 0) return 0;
                tgt = lines[j].operand;
                i = (size_t)j;                 /* the fall-through is past it */
            }
            if (depth == 0 || tgt[0] == '*') return 0;
            t = label_line(tgt);
            if (t < 0 || !dead_on_paths(lines, n, (size_t)t, depth - 1, eff))
                return 0;
            if (L->mnem[1] == 'R') return 1;   /* BRA/BRL: no fall-through */
            continue;
        }
        if (g_dop_helpers_pass && is_helper_call(L)) continue;
        if (is_control(m) || insn_size_ub(L) < 0) return 0;
    }
    return 0;
}

/* Sets N and Z from the value it leaves in A, at A's width. */
static int
sets_nz_from_a(const Line *L)
{
    static const char *const t[] = {
        "LDA","PLA","TXA","TYA","TDC","TSC","AND","ORA","EOR","ADC","SBC", NULL
    };
    static const char *const acc[] = {
        "ASL","LSR","ROL","ROR","INC","DEC", NULL
    };
    if (mn_is(L->mnem, t)) return 1;
    return mn_is(L->mnem, acc) && (!L->operand[0] || strcmp(L->operand, "A") == 0);
}

/* Leaves A, N and Z as they were: a store or a push. */
static int
keeps_a_and_nz(const Line *L)
{
    static const char *const t[] = {
        "STA","STX","STY","STZ","PHA","PHX","PHY","PHB","PHK","PHD","PEI",
        "PEA", NULL
    };
    return mn_is(L->mnem, t);
}

/* The live instruction line before `i', or -1 if a label or the start of the
 * buffer comes first. */
static long
prev_insn(Line *lines, size_t i)
{
    while (i-- > 0) {
        if (lines[i].dead) continue;
        if (lines[i].mnem[0]) return (long)i;
        if (lines[i].label[0]) return -1;
    }
    return -1;
}

/* Pattern: `CMP #0' after an instruction that set N and Z from A, with only
 * stores and pushes between.  The
 * compare sets the same N and Z (A - 0 is A), so it is needed only for the
 * carry it sets, and goes when nothing reads that. */
static void
pat_cmp_zero_after_nz(Line *lines, size_t n)
{
    size_t i;
    for (i = 0; i < n; i++) {
        long p;
        if (lines[i].dead || lines[i].label[0] ||
            strcmp(lines[i].mnem, "CMP") != 0 ||
            strcmp(lines[i].operand, "#0") != 0) continue;
        p = prev_insn(lines, i);
        while (p >= 0 && keeps_a_and_nz(&lines[p]))
            p = prev_insn(lines, (size_t)p);
        if (p < 0 || !sets_nz_from_a(&lines[p])) continue;
        if (dead_on_paths(lines, n, i + 1, 4, carry_effect))
            lines[i].dead = 1;
    }
}

/* Pattern: `TAX ; TXA' -- the allocator's register home for a push popped
 * at once.  TXA puts back what A already holds and sets N and Z as TAX did.
 * fcc never narrows X outside `__asm' text, so the round trip is exact. */
static void
pat_tax_txa(Line *lines, size_t n)
{
    size_t i;
    for (i = 0; i < n; i++) {
        long j;
        if (lines[i].dead || strcmp(lines[i].mnem, "TAX") != 0) continue;
        j = next_insn_no_label(lines, n, i + 1);
        if (j >= 0 && strcmp(lines[j].mnem, "TXA") == 0)
            lines[j].dead = 1;
    }
}

/* Pattern: a `TAX' whose X nothing reads -- what is left of a register home
 * once its `TXA' has gone.  TAX also sets N and Z, so it goes only when
 * those are dead after it. */
static void
pat_dead_tax(Line *lines, size_t n)
{
    size_t i;
    for (i = 0; i < n; i++) {
        if (lines[i].dead || lines[i].label[0] ||
            strcmp(lines[i].mnem, "TAX") != 0) continue;
        if (nz_dead_after(lines, n, i) &&
            dead_on_paths(lines, n, i + 1, 4, x_effect))
            lines[i].dead = 1;
    }
}

/* Pattern: a far branch whose target is in reach.  `B!cc *+5 ; BRL L'
 * becomes `Bcc L', and a lone `BRL L' becomes `BRA L', when L lies within
 * a branch's -128..+127.  The distance is summed from an upper bound on each
 * line's size, and a DO/ELSE/FIN block counts as its larger arm, so the real
 * distance is never greater; shortening a branch only shrinks the others, so
 * each pass stays sound and a second one finds what the first enabled.  A
 * line this cannot size refuses every branch across it.  A branch inside the
 * reach of a `*+N' or `*-N' is left as it is: the skip counts its bytes. */
static void
pat_relax_branches(Line *lines, size_t n)
{
    long     *off = malloc((n + 1) * sizeof *off);
    long     *unk = malloc((n + 1) * sizeof *unk);
    char     *pinned = calloc(n + 1, 1);
    size_t    i;
    int       pass, changed = 1;

    if (!off || !unk || !pinned) goto out;

    for (i = 0; i < n; i++) {                  /* the `*+N' skips' reach */
        const char *o = lines[i].operand;
        long span, at;
        size_t j;
        if (lines[i].dead || lines[i].mnem[0] != 'B' || o[0] != '*') continue;
        span = strtol(o + 2, NULL, 10);
        if (o[1] == '-') {                     /* every line it may cross */
            for (j = i; j-- > 0 && span > 0; )
                if (lines[j].mnem[0]) { pinned[j] = 1; span--; }
            continue;
        }
        /* Forward: a line is inside while its offset is surely below N.  An
         * instruction with an operand is at least 2 bytes; a line this does
         * not size, or a directive, counts 0; past a DO/ELSE/FIN every line
         * the walk reaches is pinned. */
        at = 2;
        for (j = i + 1; j < n && j < i + 64 && at < span; j++) {
            if (lines[j].dead || !lines[j].mnem[0]) continue;
            pinned[j] = 1;
            if (strcmp(lines[j].mnem, "DO") == 0 ||
                strcmp(lines[j].mnem, "ELSE") == 0 ||
                strcmp(lines[j].mnem, "FIN") == 0)
                at = -64 * 4;          /* an arm may not assemble: pin on */
            else
                at += insn_size_lb(&lines[j]);
        }
    }
    for (pass = 0; pass < 4 && changed; pass++) {
        long pos = 0, nunk = 0, base[16], arm[16];
        int  depth = 0;
        changed = 0;
        for (i = 0; i < n; i++) {
            const char *m = lines[i].mnem;
            int sz;
            off[i] = pos;
            unk[i] = nunk;
            if (lines[i].dead || !m[0]) continue;
            if (strcmp(m, "DO") == 0) {
                if (depth == 16) goto out;     /* nested this deep: none */
                base[depth] = pos;
                arm[depth++] = -1;
                continue;
            }
            if (strcmp(m, "ELSE") == 0 && depth > 0) {
                arm[depth - 1] = pos - base[depth - 1];
                pos = base[depth - 1];
                continue;
            }
            if (strcmp(m, "FIN") == 0 && depth > 0) {
                long b = pos - base[--depth];
                if (arm[depth] > b) b = arm[depth];
                pos = base[depth] + b;
                continue;
            }
            sz = insn_size_ub(&lines[i]);
            if (sz < 0) nunk++;
            else        pos += sz;
        }
        off[n] = pos;
        unk[n] = nunk;
        if (depth != 0) goto out;

        for (i = 0; i < n; i++) {
            long j = -1, t, d, lo, hi;
            int  pair;
            if (lines[i].dead || pinned[i]) continue;
            pair = mn_is(lines[i].mnem, ph_cond_br) &&
                   strcmp(lines[i].operand, "*+5") == 0;
            if (pair) {
                j = next_insn_no_label(lines, n, i + 1);
                if (j < 0 || strcmp(lines[j].mnem, "BRL") != 0)
                    continue;
            } else if (strcmp(lines[i].mnem, "BRL") != 0) {
                continue;
            }
            t = label_line(lines[pair ? (size_t)j : i].operand);
            if (t < 0) continue;
            lo = t < (long)i ? t : (long)i;
            hi = t < (long)i ? (long)i : t;
            if (unk[hi] != unk[lo]) continue;
            d = off[t] - (off[i] + 2);
            if (d < -128 || d > 127) continue;
            if (pair) {
                static const char *const inv[] = {
                    "BNE","BEQ","BCS","BCC","BPL","BMI","BVS","BVC"
                };
                size_t c;
                for (c = 0; strcmp(ph_cond_br[c], lines[i].mnem) != 0; c++)
                    ;
                if (!set_insn(&lines[i], inv[c], lines[j].operand)) goto out;
                lines[j].dead = 1;
            } else {
                char op[PH_TOK];
                snprintf(op, sizeof op, "%s", lines[i].operand);
                if (!set_insn(&lines[i], "BRA", op)) goto out;
            }
            changed = 1;
        }
    }
out:
    free(off);
    free(unk);
    free(pinned);
}

/* --- a promoted pointer's register copy, read in place ----------------------
 *
 * A pointer held in an img pair (ir.c's promotion) reaches member and element
 * access through a far-pointer register the load fills:
 *
 *      LDA _fcc_img{s+1} / STA _fcc_fpr{k}+2 / LDA _fcc_img{s} / STA _fcc_fpr{k}
 *
 * The pair is itself a direct-page pointer, so the register's readers can read
 * it instead: `[_fcc_fpr{k}],Y' becomes `[_fcc_img{s}],Y', and the copy goes,
 * all but the `LDA _fcc_img{s}' that leaves the offset in A as the load
 * promised.  Eight bytes per load.
 *
 * The readers taken are the ones up to the register's next write, the pair's
 * next write (a reader past it would see the new pointer), or any line this
 * does not follow (a label, a branch, a call, unknown text) -- and only if the
 * register is then dead on every path, so no reader is left wanting the copy.
 * A C call clobbers the far-pointer registers without reading them (they are
 * caller-saved and arguments travel on the stack); an `_fcc_' runtime helper
 * may read one, and a return reads _fcc_fpr0, the pointer return register. */

static char g_al_lo[PH_TOK], g_al_hi[PH_TOK];   /* the register's two words */
static int  g_al_k0;                             /* the register is _fcc_fpr0 */

static int
is_store_mn(const char *m)
{
    return strcmp(m, "STA") == 0 || strcmp(m, "STZ") == 0 ||
           strcmp(m, "STX") == 0 || strcmp(m, "STY") == 0;
}

static int
is_call(const Line *L)
{
    const char *m = L->mnem;
    return strcmp(m, "JSL") == 0 || strcmp(m, "JSR") == 0 ||
           strcmp(m, "FGX2_FARCALL") == 0;
}

/* A call to an _fcc_ runtime helper, which touches only the runtime's own
 * direct-page cells ($E8 and up): never a far-pointer register or an img. */
static int
is_helper_call(const Line *L)
{
    return is_call(L) && strncmp(L->operand, "_fcc_", 5) == 0;
}

static int
al_effect(const Line *L, const char *loc)
{
    if (reads_loc(L, loc)) return C_READ;
    if (is_store_mn(L->mnem) && strcmp(L->operand, loc) == 0) return C_WRITE;
    if (is_helper_call(L)) return C_NONE;
    if (is_call(L)) return C_WRITE;
    if (is_return(L->mnem) && g_al_k0) return C_READ;
    return C_NONE;
}
static int al_effect_lo(const Line *L) { return al_effect(L, g_al_lo); }
static int al_effect_hi(const Line *L) { return al_effect(L, g_al_hi); }

/* 1 iff operand `op' names `reg' in any form; *form gets which: 1 `reg',
 * 2 `reg+2', 3 `[reg]', 4 `[reg],Y', 0 anything else that mentions it. */
static int
names_reg(const char *op, const char *reg, int *form)
{
    char b[PH_TOK + 8];
    const char *hit = strstr(op, reg);
    size_t rl = strlen(reg);
    *form = 0;
    while (hit && isalnum((unsigned char)hit[rl]))      /* _fcc_img1 vs _fcc_img16 */
        hit = strstr(hit + 1, reg);
    if (!hit) return 0;
    if (strcmp(op, reg) == 0) { *form = 1; return 1; }
    snprintf(b, sizeof b, "%s+2", reg);
    if (strcmp(op, b) == 0) { *form = 2; return 1; }
    snprintf(b, sizeof b, "[%s]", reg);
    if (strcmp(op, b) == 0) { *form = 3; return 1; }
    snprintf(b, sizeof b, "[%s],Y", reg);
    if (strcmp(op, b) == 0) { *form = 4; return 1; }
    return 1;
}

/* 1 iff line L may write img word `w' (a store or read-modify-write naming it
 * directly, or any form this does not recognise as a read). */
static int
writes_word(const Line *L, const char *w)
{
    int form;
    if (!names_reg(L->operand, w, &form)) return 0;
    if (form == 3 || form == 4) return 0;               /* through it: a read */
    if (form == 1 && (reads_mem(L->mnem) && !is_rmw(L->mnem))) return 0;
    return 1;
}

/* 1 iff the `*+N' at line `sk' lands at or before line `at': the exact sizes
 * of the lines it skips reach N first.  0 when a size is not exact. */
static int
skip_lands_by(Line *lines, size_t n, size_t sk, size_t at)
{
    long want, got = 0;
    size_t j;
    if (strncmp(lines[sk].operand, "*+", 2) != 0) return 0;
    want = strtol(lines[sk].operand + 2, NULL, 10);
    got = insn_size_ub(&lines[sk]);
    if (got != insn_size_lb(&lines[sk])) return 0;
    for (j = sk + 1; j <= at && j < n; j++) {
        int ub, lb;
        if (got == want) return 1;
        if (got > want) return 0;
        if (lines[j].dead) continue;
        ub = insn_size_ub(&lines[j]);
        lb = insn_size_lb(&lines[j]);
        if (ub < 0 || ub != lb) return 0;
        got += ub;
    }
    return got == want;
}

static void
pat_img_fpr_alias(Line *lines, size_t n)
{
    size_t i;
    for (i = 0; i + 3 < n; i++) {
        Line *a = &lines[i], *b = &lines[i + 1], *c = &lines[i + 2], *d = &lines[i + 3];
        char k[PH_TOK], s0[PH_TOK], s1[PH_TOK];
        unsigned sn, kn;
        size_t j, e, back, rd[256];
        int nrd = 0, ok = 1, form;
        if (a->dead || b->dead || c->dead || d->dead) continue;
        if (a->label[0] || b->label[0] || c->label[0] || d->label[0]) continue;
        if (strcmp(a->mnem, "LDA") || strcmp(b->mnem, "STA") ||
            strcmp(c->mnem, "LDA") || strcmp(d->mnem, "STA")) continue;
        if (sscanf(c->operand, "_fcc_img%u", &sn) != 1 ||
            sscanf(d->operand, "_fcc_fpr%u", &kn) != 1) continue;
        snprintf(s0, sizeof s0, "_fcc_img%u", sn);
        snprintf(s1, sizeof s1, "_fcc_img%u", sn + 1);
        snprintf(k, sizeof k, "_fcc_fpr%u", kn);
        snprintf(g_al_lo, sizeof g_al_lo, "%s", k);
        snprintf(g_al_hi, sizeof g_al_hi, "%s+2", k);
        if (strcmp(c->operand, s0) || strcmp(a->operand, s1) ||
            strcmp(d->operand, g_al_lo) || strcmp(b->operand, g_al_hi)) continue;
        g_al_k0 = (kn == 0);
        /* a `*+N' skip may land past lines this deletes */
        for (back = i; back > 0 && back + 8 > i; back--)
            if (lines[back - 1].operand[0] == '*' &&
                !skip_lands_by(lines, n, back - 1, i)) { ok = 0; break; }
        if (!ok) continue;
        for (j = i + 4; j < n; j++) {
            Line *L = &lines[j];
            if (L->label[0]) break;
            if (L->dead || !L->mnem[0]) continue;
            if (strcmp(L->mnem, "DO") == 0) {          /* a frame gate: see through */
                size_t f;
                for (f = j + 1; f < n && strcmp(lines[f].mnem, "FIN"); f++) {
                    int fm;
                    if (lines[f].label[0] || is_control(lines[f].mnem) ||
                        names_reg(lines[f].operand, k, &fm) ||
                        names_reg(lines[f].operand, s0, &fm) ||
                        names_reg(lines[f].operand, s1, &fm))
                        break;
                }
                if (f >= n || strcmp(lines[f].mnem, "FIN")) break;
                j = f;
                continue;
            }
            if (writes_word(L, s0) || writes_word(L, s1)) break;
            if (names_reg(L->operand, k, &form)) {
                if (is_store_mn(L->mnem) && (form == 1 || form == 2)) break;
                if (form == 0 || is_rmw(L->mnem)) { ok = 0; break; }
                if (nrd >= 256) { ok = 0; break; }
                rd[nrd++] = j;
                continue;
            }
            if (is_helper_call(L)) continue;
            if (is_call(L) || is_control(L->mnem) ||
                strcmp(L->mnem, "ELSE") == 0 || strcmp(L->mnem, "FIN") == 0 ||
                insn_size_ub(L) < 0)
                break;
        }
        if (!ok) continue;
        e = j;
        g_dop_helpers_pass = 1;
        ok = e < n && dead_on_paths(lines, n, e, 4, al_effect_lo) &&
             dead_on_paths(lines, n, e, 4, al_effect_hi);
        g_dop_helpers_pass = 0;
        if (!ok)
            continue;
        for (j = 0; j < (size_t)nrd; j++) {
            Line *L = &lines[rd[j]];
            char op[PH_TOK + 8];
            names_reg(L->operand, k, &form);
            snprintf(op, sizeof op, form == 1 ? "%s" : form == 2 ? "%s" :
                                    form == 3 ? "[%s]" : "[%s],Y",
                     form == 2 ? s1 : s0);
            set_insn(L, L->mnem, op);
        }
        a->dead = b->dead = d->dead = 1;               /* c keeps A = offset */
        i += 3;
    }
}

char *
peephole_optimize(const char *asm_text)
{
    size_t n, len = strlen(asm_text);
    int had_nl = (len > 0 && asm_text[len - 1] == '\n');
    Line *lines = split_lines(asm_text, &n);
    char *out;
    int have_labels;
    if (!lines) return NULL;

    {   /* T5-C C4b __asm opacity: every line inside ;__ASM..;__ASM_END
         * gets a sentinel label — every pattern already treats a labeled
         * line as a branch-target barrier and never a candidate, which is
         * exactly the conservative contract a verbatim block needs. */
        size_t i; int in_asm = 0;
        for (i = 0; i < n; i++) {
            if (strncmp(lines[i].raw, ";__ASM_END", 10) == 0) { in_asm = 0; continue; }
            if (strncmp(lines[i].raw, ";__ASM", 6) == 0)      { in_asm = 1; continue; }
            if (in_asm && lines[i].label[0] == '\0')
                snprintf(lines[i].label, sizeof lines[i].label, "@__asm");
        }
    }
    have_labels = labels_build(lines, n);
    if (have_labels)
        pat_img_fpr_alias(lines, n);
    pat_bra_to_next(lines, n);
    pat_neg_const(lines, n);
    if (tmpb_block_local(lines, n)) {
        pat_tmpb_const(lines, n);
        pat_tmpb_dead_store(lines, n);
    }
    pat_staload_forward(lines, n);
    pat_repsep_adjacent(lines, n);
    pat_clcadc_to_ina(lines, n);
    pat_dead_store(lines, n);
    pat_dead_lda(lines, n);
    pat_empty_width_roundtrip(lines, n);
    if (have_labels) {
        pat_tax_txa(lines, n);
        pat_dead_tax(lines, n);
        pat_relax_branches(lines, n);       /* the carry walk follows Bcc L */
        pat_cmp_zero_after_nz(lines, n);
        pat_relax_branches(lines, n);
    }
    free(g_lab);
    g_lab = NULL;

    out = render(lines, n, had_nl);
    free_lines(lines, n);
    return out;
}

int
ph_test_nz_dead_after(const char *asm_text, int idx)
{
    size_t n;
    Line *lines = split_lines(asm_text, &n);
    int r;
    if (!lines || idx < 0 || (size_t)idx >= n) { free_lines(lines, n); return 0; }
    r = nz_dead_after(lines, n, (size_t)idx);
    free_lines(lines, n);
    return r;
}

int
ph_test_carry_dead_after(const char *asm_text, int idx)
{
    size_t n;
    Line *lines = split_lines(asm_text, &n);
    int r;
    if (!lines || idx < 0 || (size_t)idx >= n) { free_lines(lines, n); return 0; }
    r = carry_dead_after(lines, n, (size_t)idx);
    free_lines(lines, n);
    return r;
}

int
ph_test_dead_a_after(const char *asm_text, int idx)
{
    size_t n;
    Line *lines = split_lines(asm_text, &n);
    int r;
    if (!lines || idx < 0 || (size_t)idx >= n) { free_lines(lines, n); return 0; }
    r = dead_a_after(lines, n, (size_t)idx);
    free_lines(lines, n);
    return r;
}
