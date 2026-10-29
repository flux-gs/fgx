#include "fcc.h"

int
parse_struct_def(const char *tag_ptr, int tag_len, int is_union)
{
    char synth[MAX_IDENT];
    int  union_max = 0;   /* B-2: union total size = max field size */
    if (tag_ptr == NULL) {
        int n = snprintf(synth, sizeof synth, "@anon%d", g_anon_struct_n++);
        tag_ptr = synth;
        tag_len = n;
    }
    int sid = structs_lookup(tag_ptr, tag_len);
    Struct *s;
    if (sid < 0) {
        if (g_n_structs >= MAX_STRUCTS)
            die(g_cur.line, g_cur.col, "too many structs (max " FCC_STR(MAX_STRUCTS) ")");
        s = &g_structs[g_n_structs];
        int nl = tag_len < MAX_IDENT - 1 ? tag_len : MAX_IDENT - 1;
        s->name = lex_intern_ident(tag_ptr, nl);
        s->n_fields = 0;
        s->total_size = 0;
        s->is_forward = 1;
        s->is_union   = 0;
        s->scope_hidden = 0;
        s->scope_depth  = g_tag_scope_depth;
        sid = g_n_structs++;
    } else if (g_structs[sid].scope_depth < g_tag_scope_depth) {
        /* K&R A.11.1: "If an identifier is explicitly declared at the head of
         * a block, including the block constituting a function, any
         * declaration of the identifier outside the block is suspended until
         * the end of the block."  So a tag DEFINED here shadows the outer one
         * instead of colliding with it -- and it must be a NEW entry, because
         * the outer type has to come back intact at the closing brace. */
        if (g_n_structs >= MAX_STRUCTS)
            die(g_cur.line, g_cur.col, "too many structs (max " FCC_STR(MAX_STRUCTS) ")");
        s = &g_structs[g_n_structs];
        int nl = tag_len < MAX_IDENT - 1 ? tag_len : MAX_IDENT - 1;
        s->name = lex_intern_ident(tag_ptr, nl);
        s->n_fields = 0;
        s->total_size = 0;
        s->is_forward = 1;
        s->is_union   = 0;
        s->scope_hidden = 0;
        s->scope_depth  = g_tag_scope_depth;
        sid = g_n_structs++;
    } else {
        s = &g_structs[sid];
        if (!s->is_forward)
            die(g_cur.line, g_cur.col, "redefinition of struct");
    }
    expect(TOK_LBRACE, "'{'");
    int cur          = 0;
    int bf_container = -1;
    int bf_used      = 0;
    while (g_cur.kind != TOK_RBRACE) {
        TypeSpec t = parse_type_spec();
        /* M18: function-pointer field: T (*name)(params); */
        {
            const char *ff_name_ptr;
            int         ff_name_len;
            int         ff_sig_id;
            if (parse_fn_ptr_declarator(t, &ff_name_ptr, &ff_name_len, &ff_sig_id)) {
                expect(TOK_SEMI, "';' after fn-pointer field");
                if (s->n_fields >= MAX_FIELDS_PER_STRUCT)
                    die(g_cur.line, g_cur.col, "too many struct fields");
                Field *ff = &s->fields[s->n_fields++];
                int fnl = ff_name_len < MAX_IDENT - 1 ? ff_name_len : MAX_IDENT - 1;
                ff->name = lex_intern_ident(ff_name_ptr, fnl);
                ff->type        = LT_FN_PTR;
                ff->struct_id   = -1;
                ff->fn_sig_id   = ff_sig_id;
                ff->n_elems     = 1;
                cur = (cur + 1) & ~1;  /* even-align: a packed char before
                                          this field leaves cur odd (B-8) */
                ff->byte_offset = cur;
                ff->byte_size   = 4;
                ff->is_bit_field = 0;
                ff->bit_offset  = 0;
                ff->bit_width   = 0;
                cur += 4;
                bf_container = -1;     /* end any bit-field run */
                continue;
            }
        }
        /* M18: typedef-resolved fn-ptr field: cb_t handler; */
        if (t.base == LT_FN_PTR) {
            if (g_cur.kind != TOK_IDENT)
                die(g_cur.line, g_cur.col, "expected fn-ptr field name");
            if (s->n_fields >= MAX_FIELDS_PER_STRUCT)
                die(g_cur.line, g_cur.col, "too many struct fields");
            Field *ff = &s->fields[s->n_fields++];
            int fnl = g_cur.id_len < MAX_IDENT - 1 ? g_cur.id_len : MAX_IDENT - 1;
            ff->name = lex_intern_ident(g_cur.id_ptr, fnl);
            ff->type        = LT_FN_PTR;
            ff->struct_id   = -1;
            ff->fn_sig_id   = t.struct_id;   /* overloaded */
            ff->n_elems     = 1;
            cur = (cur + 1) & ~1;  /* even-align after a packed char (B-8) */
            ff->byte_offset = cur;
            ff->byte_size   = 4;
            ff->is_bit_field = 0;
            ff->bit_offset  = 0;
            ff->bit_width   = 0;
            cur += 4;
            bf_container = -1;
            next_tok();
            expect(TOK_SEMI, "';' after fn-ptr field");
            continue;
        }
        for (;;) {
            /* declarator-refactor Increment 2: the field's `*name[N]`
             * declarator flows through the ONE parse_declarator (byte-identical
             * -- same type_for_decl merge + n_elems; depth-2+ pointer fields
             * `char **pp` and `T *arr[N]` already worked via the depth-aware
             * tword).  Bit-fields (`:` width) are struct syntax, handled below
             * on the returned name (they carry no array).  The fn-ptr field
             * shapes are handled above (parse_fn_ptr_declarator) until Inc 4. */
            Declarator md = parse_declarator(t, /*allow_abstract=*/0);
            if (md.is_func_proto)
                die(g_cur.line, g_cur.col, "function-typed struct field not supported");
            if (md.sizeless)
                die(g_cur.line, g_cur.col, "struct array field needs an explicit size");
            if (s->n_fields >= MAX_FIELDS_PER_STRUCT)
                die(g_cur.line, g_cur.col, "too many struct fields");
            Field *f = &s->fields[s->n_fields];
            int nl2 = md.name_len < MAX_IDENT - 1 ? md.name_len : MAX_IDENT - 1;
            f->name = lex_intern_ident(md.name, nl2);
            f->struct_id    = t.struct_id;
            f->fn_sig_id    = -1;
            f->is_bit_field = 0;
            f->bit_offset   = 0;
            f->bit_width    = 0;
            f->n_elems      = 1;

            /* Bit-field syntax: ':' <width> (Task 11). */
            if (g_cur.kind == TOK_COLON) {
                next_tok();
                if (g_cur.kind != TOK_INT_LIT)
                    die(g_cur.line, g_cur.col, "bit-field width literal");
                int bw = (int)g_cur.value;
                if (bw < 1 || bw > 16)
                    die(g_cur.line, g_cur.col, "bit-field width must be 1..16");
                if (t.base != LT_INT && t.base != LT_CHAR)
                    die(g_cur.line, g_cur.col,
                        "bit-field must be int/char-typed");
                next_tok();
                /* STORAGE UNITS ARE 2.11BSD ccom's (usr/lib/ccom/c03.c,
                 * align()): a char-typed field takes a BYTE unit with no word
                 * alignment, an int field a word-aligned WORD unit, and a field
                 * that does not fit the current unit starts the next one.  K&R
                 * A.8.3 leaves the units to the implementation ("Adjacent field
                 * members of structures are packed into implementation-
                 * dependent storage units"); this is the layout 2.11BSD's
                 * headers were written against -- struct ip's ip_hl and ip_v
                 * share its first byte.  After an int unit using more than
                 * eight bits a char field starts past those bits, where ccom
                 * would overlap them.
                 *
                 * A byte unit is ACCESSED as the aligned word holding it,
                 * shifted: the struct is rounded to an even size below, so that
                 * word is always inside it, and the field arms in emit.c stay
                 * one 16-bit shape. */
                int is_cf = (t.base == LT_CHAR);
                if (is_cf && bw > 8)
                    die(g_cur.line, g_cur.col, "char bit-field wider than 8");
                if (bf_container >= 0 && !is_cf && (bf_container & 1))
                    bf_container = -1;          /* an int unit is word aligned */
                if (bf_container < 0 || bf_used + bw > (is_cf ? 8 : 16)) {
                    if (bf_container >= 0 &&
                        cur < bf_container + (bf_used + 7) / 8)
                        cur = bf_container + (bf_used + 7) / 8;
                    if (!is_cf)
                        cur = (cur + 1) & ~1;
                    bf_container = cur;
                    bf_used = 0;
                }
                {
                    int end = bf_container +
                              (is_cf ? (bf_used + bw + 7) / 8 : 2);
                    if (cur < end)
                        cur = end;
                }
                f->is_bit_field = 1;
                f->bit_offset   = bf_used + 8 * (bf_container & 1);
                f->bit_width    = bw;
                f->byte_offset  = bf_container & ~1;
                f->byte_size    = 2;
                f->type         = LT_INT;  /* always unsigned int container */
                bf_used += bw;
                s->n_fields++;
                if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
                break;
            }
            bf_container = -1;
            bf_used      = 0;

            /* Array `[N]...` was already consumed by parse_declarator above,
             * which also computed dims[], n_dims and row_stride -- the M19
             * machinery locals and globals have used since it landed.  This
             * used to `die' on n_dims > 1 while holding all of that, which is
             * what apple/fgx#477 was.
             *
             * n_elems IS THE PRODUCT so the size switch below stays
             * byte-identical for 1-D and sizes a 2-D field correctly without a
             * second arm: K&R A.8.6.2 -- "An array may be constructed from ...
             * another array (to generate a multi-dimensional array)" and "the
             * first subscript in the declaration helps determine the amount of
             * storage consumed by an array, but plays no other part in
             * subscript calculations".  The storage is the product; the stride
             * is the inner dimensions, which is `row_stride' below.
             */
            if (md.n_dims > 2)
                die(g_cur.line, g_cur.col,
                    "struct field of rank > 2 not supported (fcc lowers rank 2)");
            int n_elems = 1;
            if (md.n_dims >= 1) {
                int d;
                for (d = 0; d < md.n_dims; d++)
                    n_elems *= md.dims[d];
            }
            f->type    = md.type;
            f->n_elems = n_elems;
            f->n_dims  = (md.n_dims >= 1) ? md.n_dims : 1;
            f->is_unsigned = t.is_unsigned;   /* A-1 */

            int align = 2, size = 2;
            if (is_ptr_array(f->type)) {
                /* array of N long pointers, 4 bytes each — elvis's regexp
                 * struct `char *startp[NSUBEXP]`. */
                align = 2;
                size  = 4 * n_elems;
            } else if (ISPTR(f->type)) {
                /* uniform 4-byte long pointer at ANY depth (queue 4a:
                 * subsumes the depth-1 labels below). */
                align = 2;
                size  = 4;
            } else
            switch (f->type) {
                case LT_CHAR:        align = 1; size = 1;                    break;  /* B-8: byte-packed
                                                                                       (PDP-11 layout; was a
                                                                                       2-byte slot, 2026-07-06) */
                case LT_CHAR_ARRAY:  align = 1; size = n_elems;              break;
                case LT_INT:         align = 2; size = 2;                    break;
                case LT_INT_ARRAY:   align = 2; size = 2 * n_elems;          break;
                case LT_LONG:        align = 2; size = 4;                    break;  /* B-4 */
                case LT_LONG_ARRAY:  align = 2; size = 4 * n_elems;          break;  /* B-4 */
                case LT_FLOAT:       align = 2; size = 4;                    break;  /* B-6 */
                case LT_FLOAT_ARRAY: align = 2; size = 4 * n_elems;          break;  /* B-6 */
                case LT_LLONG:       align = 2; size = 8;                    break;  /* long long */
                case LT_LLONG_ARRAY: align = 2; size = 8 * n_elems;          break;
                case LT_DOUBLE:      align = 2; size = 8;                    break;  /* long double */
                case LT_DOUBLE_ARRAY: align = 2; size = 8 * n_elems;         break;
                case LT_LONG_PTR:
                case LT_FLOAT_PTR:
                case LT_INT_PTR:
                case LT_CHAR_PTR:
                case LT_VOID_PTR:
                case LT_STRUCT_PTR:  align = 2; size = 4;                    break;  /* uniform 4-byte long ptr (offset+bank+pad) */
                case LT_STRUCT: {
                    if (f->struct_id < 0 || g_structs[f->struct_id].is_forward)
                        die(g_cur.line, g_cur.col,
                            "by-value struct field requires complete type");
                    align = 2;
                    size = (g_structs[f->struct_id].total_size + 1) & ~1;
                    break;
                }
                case LT_STRUCT_ARRAY: {
                    if (f->struct_id < 0 || g_structs[f->struct_id].is_forward)
                        die(g_cur.line, g_cur.col,
                            "array of incomplete struct not allowed");
                    align = 2;
                    int es = (g_structs[f->struct_id].total_size + 1) & ~1;
                    size = es * n_elems;
                    break;
                }
                default:
                    die(g_cur.line, g_cur.col, "bad field type");
            }
            /* M19b: the outermost-index step, in BYTES, which is what
             * Local.row_stride holds and what the member-access lowering wants.
             * parse_declarator gives the inner-dims product in ELEMENTS, so
             * scale it by the element size -- `size' is the whole field and
             * n_elems its element count, so size/n_elems is one element
             * whatever arm of the switch above ran.  Zero for 1-D, which is the
             * value every existing caller already assumes. */
            f->row_stride = 0;
            if (f->n_dims >= 2 && n_elems > 0)
                f->row_stride = md.row_stride * (size / n_elems);
            if (is_union) {                 /* B-2: all members overlap at 0 */
                f->byte_offset = 0;
                f->byte_size = size;
                if (size > union_max) union_max = size;
            } else {
                cur = (cur + (align - 1)) & ~(align - 1);
                f->byte_offset = cur;
                f->byte_size = size;
                cur += size;
            }
            s->n_fields++;
            if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
            break;
        }
        expect(TOK_SEMI, "';'");
    }
    expect(TOK_RBRACE, "'}'");
    s->total_size = ((is_union ? union_max : cur) + 1) & ~1;
    s->is_forward = 0;
    s->is_union   = is_union;
    return sid;
}

/* In a pointer / fn-ptr struct-field initializer, consume a leading cast so
 * `(char *)0` and `(MARK (*)())0` (elvis's NO_FUNC) reduce to the value that
 * follows (0 / string / name).  A '(' in this position is always a cast (a
 * bare parenthesised value isn't an init idiom here), so skip balanced parens. */
static void
skip_field_init_cast(void)
{
    if (g_cur.kind != TOK_LPAREN) return;
    int depth = 0;
    do {
        if (g_cur.kind == TOK_LPAREN)      depth++;
        else if (g_cur.kind == TOK_RPAREN) depth--;
        next_tok();
    } while (depth > 0);
}

/* Peel leading grouping parens and pointer casts in a pointer-global
 * initializer, landing g_cur on the operand (&global / global-name / 0).
 * Returns the count of GROUPING parens descended into -- their matching ')'
 * trail the operand and must be consumed by the caller.  A '(' whose next
 * token starts a type-name is a CAST (skip the whole balanced group, no
 * trailing ')'); any other '(' is a grouping paren (descend, +1 trailing).
 * 2.11BSD sh: BLK(end) == ((BLKPTR)(end)) -- a grouping wrap around a cast of
 * a grouped operand.  K&R A.7.5 (cast), A.7.2 (grouping), A.7.1 (array decay). */
static int
peel_ptr_init_prefix(void)
{
    int grouping = 0;
    while (g_cur.kind == TOK_LPAREN) {
        next_tok();                            /* past '(' */
        int is_type = (g_cur.kind == TOK_INT_KW   || g_cur.kind == TOK_CHAR_KW ||
                       g_cur.kind == TOK_VOID_KW   || g_cur.kind == TOK_STRUCT_KW ||
                       g_cur.kind == TOK_UNION_KW  || g_cur.kind == TOK_ENUM_KW  ||
                       g_cur.kind == TOK_LONG_KW ||
                       g_cur.kind == TOK_FLOAT_KW  ||
                       (g_cur.kind == TOK_IDENT &&
                        (typedefs_lookup(g_cur.id_ptr, g_cur.id_len) >= 0 ||
                         is_type_modifier_ident(g_cur.id_ptr, g_cur.id_len))));
        if (is_type) {
            int depth = 1;                     /* balanced cast '(' TYPE ')' */
            while (depth > 0 && g_cur.kind != TOK_EOF) {
                if (g_cur.kind == TOK_LPAREN)      depth++;
                else if (g_cur.kind == TOK_RPAREN) depth--;
                next_tok();
            }
        } else {
            grouping++;                        /* grouping paren: descend */
        }
    }
    return grouping;
}

/* Is the current struct-field initializer item a NULL pointer constant?
 * K&R A.6.6 (p.160): an integral constant 0, optionally cast (and here
 * optionally parenthesized), is a null pointer.  Handles `0`, `(char*)0`, and
 * the 2.11BSD Bourne shell's NIL == `((char*)0)` (a cast-0 wrapped in a
 * grouping paren that skip_field_init_cast over-consumes).  On a match, leaves
 * g_cur AT the item's last token (the shared post-branch next_tok() consumes
 * it) and returns 1; otherwise restores g_cur and returns 0. */
static int
field_init_is_null(void)
{
    LexPeek pk, last;
    lex_peek_save(&pk);
    lex_peek_save(&last);
    int depth = 0, zeros = 0, other = 0;
    for (;;) {
        TokKind k = g_cur.kind;
        /* TOK_SEMI TERMINATES TOO, and it was missing.  This started as a
         * STRUCT-FIELD test, where an initializer ends at ',' or '}' and a
         * ';' cannot appear -- so adding it costs those callers nothing.  A
         * static-local initializer ends at ';' and nowhere else, and without
         * this the scan ran past it, counted the ';' as "other", and reported
         * `static Char *home_ptr = NULL;' as not-a-null. */
        if (depth == 0 && (k == TOK_COMMA || k == TOK_RBRACE ||
                           k == TOK_SEMI  || k == TOK_EOF))
            break;
        if (k == TOK_LPAREN)       depth++;
        else if (k == TOK_RPAREN)  depth--;
        else if (k == TOK_INT_LIT && g_cur.value == 0 && g_cur.value_hi == 0)
            zeros++;
        else if (k == TOK_CHAR_KW || k == TOK_INT_KW  || k == TOK_VOID_KW ||
                 k == TOK_LONG_KW || k == TOK_STAR ||
                 (k == TOK_IDENT &&
                  typedefs_lookup(g_cur.id_ptr, g_cur.id_len) >= 0))
            /* cast type tokens are allowed */ ;
        else { other = 1; }
        lex_peek_save(&last);      /* g_cur is a valid item token; remember it */
        next_tok();
    }
    if (zeros == 1 && !other) {
        lex_peek_restore(&last);   /* leave g_cur AT the item's last token */
        return 1;
    }
    lex_peek_restore(&pk);
    return 0;
}

/* The specifiers after an int, char or long base, in any order: K&R A.8.2,
 * "At most one of the words long or short may be specified together with
 * int; the meaning is the same if int is not mentioned ... At most one of
 * signed or unsigned may be specified together with int or any of its short
 * or long varieties, or with char", and A.8's declaration-specifiers are a
 * sequence with no order.  So `int long', `long unsigned' and `int signed'
 * are the types `long', `unsigned long' and `int'.  joe's utils.h
 * `int_min(signed int a, int signed b)' and 4.3BSD-Reno doprnt.c's
 * `va_arg(argp, long unsigned)' are the cases.  parse_type_spec and a cast's
 * type name both end here. */
void
consume_trailing_specifiers(LocalType *base, int *is_unsigned)
{
    for (;;) {
        if (g_cur.kind == TOK_IDENT &&
            ((g_cur.id_len == 8 && memcmp(g_cur.id_ptr, "unsigned", 8) == 0) ||
             (g_cur.id_len == 6 && memcmp(g_cur.id_ptr, "signed", 6) == 0))) {
            *is_unsigned = (g_cur.id_len == 8);
        } else if (g_cur.kind == TOK_IDENT && *base == LT_INT &&
                   g_cur.id_len == 5 && memcmp(g_cur.id_ptr, "short", 5) == 0) {
            ;                                   /* short is int here */
        } else if (g_cur.kind == TOK_INT_KW &&
                   (*base == LT_INT || *base == LT_LONG || *base == LT_LLONG)) {
            ;
        } else if (g_cur.kind == TOK_LONG_KW &&
                   (*base == LT_INT || *base == LT_LONG)) {
            *base = (*base == LT_INT) ? LT_LONG : LT_LLONG;
        } else {
            return;
        }
        next_tok();
    }
}

/* `long' followed by a floating keyword.  K&R A.4.2: float, double and "extra
 * precision floating point (long double) may be synonymous, but the ones
 * later in the list are at least as precise as those before".  long double
 * and double are one type here, fcc's 64-bit IEEE double
 * (docs/history/plans/2026-09-23-fcc-64bit-double-plan.md).  The same
 * paragraph withdraws the other spelling:
 * "The first edition made long float equivalent to double; the locution has
 * been withdrawn."  Consumes the keyword. */
void
long_double_or_die(void)
{
    if (g_cur.value != 1)
        die(g_cur.line, g_cur.col,
            "'long float' is not a type (K&R A.4.2); use double");
    next_tok();
}

TypeSpec
parse_type_spec(void)
{
    TypeSpec t;
    t.base = LT_INT;
    t.struct_id = -1;
    t.is_static = 0;
    t.is_extern = 0;
    t.is_unsigned = 0;
    int had_modifier = 0;
    /* multi-TU: 'static' (TOK_STATIC_KW) and 'extern' (TOK_IDENT) may
     * appear interleaved with other type-modifiers.  Consume them all. */
    for (;;) {
        if (g_cur.kind == TOK_STATIC_KW) {
            t.is_static = 1;
            had_modifier = 1;
            next_tok();
            continue;
        }
        if (g_cur.kind == TOK_IDENT &&
            is_type_modifier_ident(g_cur.id_ptr, g_cur.id_len)) {
            if (g_cur.id_len == 6 && memcmp(g_cur.id_ptr, "extern", 6) == 0)
                t.is_extern = 1;
            else if (g_cur.id_len == 8 && memcmp(g_cur.id_ptr, "unsigned", 8) == 0)
                t.is_unsigned = 1;
            else if (g_cur.id_len == 6 && memcmp(g_cur.id_ptr, "signed", 6) == 0)
                t.is_unsigned = 0;
            had_modifier = 1;
            next_tok();
            continue;
        }
        break;
    }
    /* Bare 'unsigned'/'signed'/'short' with no following type ⇒ int. */
    if (had_modifier && g_cur.kind != TOK_INT_KW &&
        g_cur.kind != TOK_CHAR_KW && g_cur.kind != TOK_VOID_KW &&
        g_cur.kind != TOK_STRUCT_KW && g_cur.kind != TOK_UNION_KW &&
        g_cur.kind != TOK_ENUM_KW &&
        g_cur.kind != TOK_LONG_KW && g_cur.kind != TOK_FLOAT_KW &&
        !(g_cur.kind == TOK_IDENT &&
          typedefs_lookup(g_cur.id_ptr, g_cur.id_len) >= 0)) {
        t.base = LT_INT;
        return t;
    }
    if (g_cur.kind == TOK_LONG_KW) {
        t.base = LT_LONG;
        next_tok();
        if (g_cur.kind == TOK_FLOAT_KW) {
            long_double_or_die();
            t.base = LT_DOUBLE;
            return t;
        }
        /* `long long': the C99 type fcc adopts as an extension -- not in K&R
         * (docs/history/plans/2026-09-23-fcc-long-long-plan.md). */
        if (g_cur.kind == TOK_LONG_KW) {
            t.base = LT_LLONG;
            next_tok();
        }
        /* Accept optional 'int' for K&R `long int` shape. */
        if (g_cur.kind == TOK_INT_KW) next_tok();
        consume_trailing_specifiers(&t.base, &t.is_unsigned);
        return t;
    }
    if (g_cur.kind == TOK_FLOAT_KW) {
        t.base = (g_cur.value == 1) ? LT_DBL : LT_FLOAT;   /* double : float */
        next_tok();
        return t;
    }
    if (g_cur.kind == TOK_INT_KW) {
        t.base = LT_INT;
        next_tok();
        consume_trailing_specifiers(&t.base, &t.is_unsigned);
    } else if (g_cur.kind == TOK_CHAR_KW) {
        t.base = LT_CHAR;
        next_tok();
        consume_trailing_specifiers(&t.base, &t.is_unsigned);
    } else if (g_cur.kind == TOK_VOID_KW) {
        t.base = LT_VOID;
        next_tok();
    } else if (g_cur.kind == TOK_STRUCT_KW || g_cur.kind == TOK_UNION_KW) {
        int is_union = (g_cur.kind == TOK_UNION_KW);   /* B-2 */
        next_tok();
        const char *tag_ptr = NULL;
        int tag_len = 0;
        if (g_cur.kind == TOK_IDENT) {
            tag_ptr = g_cur.id_ptr;
            tag_len = g_cur.id_len;
            next_tok();
        }
        int sid;
        if (g_cur.kind == TOK_LBRACE) {
            sid = parse_struct_def(tag_ptr, tag_len, is_union);
        } else if (tag_ptr != NULL) {
            sid = structs_lookup(tag_ptr, tag_len);
            if (sid < 0) {
                /* Forward ref: auto-create. */
                if (g_n_structs >= MAX_STRUCTS)
                    die(g_cur.line, g_cur.col, "too many structs (max " FCC_STR(MAX_STRUCTS) ")");
                Struct *s = &g_structs[g_n_structs];
                int nl = tag_len < MAX_IDENT - 1 ? tag_len : MAX_IDENT - 1;
                s->name = lex_intern_ident(tag_ptr, nl);
                s->n_fields    = 0;
                s->total_size  = 0;
                s->is_forward  = 1;
                s->is_union    = 0;
                s->scope_hidden = 0;
                s->scope_depth  = g_tag_scope_depth;
                sid = g_n_structs++;
            }
        } else {
            die(g_cur.line, g_cur.col, "expected struct tag or body");
        }
        t.base = LT_STRUCT;
        t.struct_id = sid;
    } else if (g_cur.kind == TOK_IDENT) {
        int tid = typedefs_lookup(g_cur.id_ptr, g_cur.id_len);
        if (tid < 0)
            die(g_cur.line, g_cur.col, "unknown type name");
        Typedef *td = &g_typedefs[tid];
        /* M18: fn-pointer typedef — surface as LT_FN_PTR with fn_sig_id
         * stashed in TypeSpec.struct_id (overload).  parse_decl /
         * parse_global_decl recognise this and pick up the IDENT
         * directly. */
        if (td->base_type == LT_FN_PTR) {
            t.base = LT_FN_PTR;
            t.struct_id = td->fn_sig_id;
            next_tok();
            return t;
        }
        /* Keep the typedef's full type, including pointer derivations.  t.base
         * is a TWORD, so a pointer typedef (`typedef char *T`) resolves to its
         * pointer tword (PTR<CHAR>); type_for_decl then applies any further
         * declarator '*'s via INCREF.  So `T x` is char* and `T *x` is char**
         * — no use-site '*' reapplication needed (was: M8 reject). */
        t.base = td->base_type;
        t.struct_id = td->struct_id;
        t.is_unsigned = td->is_unsigned;
        next_tok();
    } else if (g_cur.kind == TOK_ENUM_KW) {
        /* enum as a TYPE: `typedef enum {..} T;` (tcsh tw.h COMMAND), plus
         * enum-typed params/locals/globals.  An enum's value type is int; the
         * body registers its constants.  (Top-level `enum {..};` definitions
         * still route through parse_program's own enum arm.) */
        next_tok();
        parse_enum_body();
        t.base = LT_INT;
    } else {
        die(g_cur.line, g_cur.col,
            "expected type (int / char / void / struct / typedef-name)");
    }
    return t;
}

/* parse_declarator — the ONE recursive declarator parser the campaign
 * (docs/history/plans/2026-07-22-fcc-declarator-refactor.md) converges on.
 * Conforms to the pcc K&R grammar's nfdeclarator/fdeclarator recursion
 * (examples/2.11BSD/usr/lib/mip/cgram.y): leading `*`s (pointer), a
 * direct-declarator (NAME or `( declarator )` grouping), then trailing `[]`
 * (array) / `( params )` (function).  Applies that derivation to `base` and
 * returns the finished per-symbol bundle (Declarator).
 *
 * Taken here: the leading-`*` pointer chain, a NAME / abstract name or a
 * `( declarator )` group around one, trailing `[]`s, and a function `(` left
 * for the caller.  Pointer to function has its own parser
 * (parse_fn_ptr_declarator, and build_primary_ast for a cast). */
Declarator
parse_declarator(TypeSpec base, int allow_abstract)
{
    Declarator d;
    d.name        = NULL;
    d.name_len    = 0;
    d.name_line   = g_cur.line;
    d.name_col    = g_cur.col;
    d.struct_id   = (BTYPE(base.base) == BT_STRUCT) ? base.struct_id : -1;
    d.fn_sig_id   = -1;
    d.n_dims      = 0;
    d.row_stride  = 0;
    for (int i = 0; i < MAX_DIMS; i++) d.dims[i] = 0;
    d.is_unsigned = base.is_unsigned;
    d.sizeless    = 0;
    d.is_func_proto = 0;

    /* leading pointer `*`s (nfdeclarator: MUL nfdeclarator) */
    int stars = 0;
    while (g_cur.kind == TOK_STAR) { stars++; next_tok(); }

    /* direct-declarator: NAME (concrete) or empty (abstract).  `( ... )` is
     * grouping/function -> a later increment. */
    if (g_cur.kind == TOK_IDENT) {
        d.name      = g_cur.id_ptr;
        d.name_len  = g_cur.id_len;
        d.name_line = g_cur.line;
        d.name_col  = g_cur.col;
        next_tok();
    } else if (g_cur.kind == TOK_LPAREN) {
        /* grouping `( D1 )` (K&R A.8.6: "the type of the identifier in D1 is
         * the same as that of D.  The parentheses do not alter the type, but
         * may change the binding of complex declarators").  Nested groups and
         * `*`s inside them are taken; a `*` inside is the same pointer as one
         * outside UNLESS a `[` or `(` follows the group, which is the binding
         * change -- pointer to array / pointer to function.  Pointer to
         * function never reaches here (parse_fn_ptr_declarator owns it), and
         * pointer to array has no tword, so that one case is refused. */
        int depth = 0, inner = 0;
        while (g_cur.kind == TOK_LPAREN) {
            depth++;
            next_tok();
            while (g_cur.kind == TOK_STAR) { inner++; next_tok(); }
        }
        if (g_cur.kind != TOK_IDENT)
            die(g_cur.line, g_cur.col,
                "parse_declarator: expected a name inside `( declarator )'");
        d.name      = g_cur.id_ptr;
        d.name_len  = g_cur.id_len;
        d.name_line = g_cur.line;
        d.name_col  = g_cur.col;
        next_tok();
        while (depth-- > 0)
            expect(TOK_RPAREN, "')'");
        if (inner && (g_cur.kind == TOK_LBRACKET || g_cur.kind == TOK_LPAREN))
            die(g_cur.line, g_cur.col,
                "parse_declarator: pointer to array/function declared as "
                "`(*name)[...]'/`(*name)(...)' is not supported here");
        stars += inner;
    } else if (!allow_abstract) {
        die(g_cur.line, g_cur.col, "expected declarator name");
    }

    /* function `( params )` DIRECTLY after the NAME (G27 function declaration:
     * `T *name(...)`).  The declarator's grammar says "function"; the base says
     * "of what".  Increment 3 does NOT consume the params or intern a FnSig
     * (that is Increment 4) -- it flags the shape and returns with g_cur left AT
     * the '(' so the caller's existing prototype-registration path handles it.
     * d.type carries the RETURN type (base + stars), byte-identical to the
     * per-context `type_for_decl(t, stars, 0)` those paths compute. */
    if (g_cur.kind == TOK_LPAREN) {
        d.is_func_proto = 1;
        d.type = (stars == 0) ? (tword)base.base
                              : type_for_decl(base, stars, 0);
        return d;
    }

    /* trailing `[ const ]` array, repeatable (multidim `[a][b]...`).  Each size
     * is an integer constant EXPRESSION (G33).  A leading `[]` with no size is
     * the sizeless outer dim (`char s[] = "..."`, `int t[] = {...}`): recorded
     * as dims[0]=0 + d.sizeless, size resolved by the caller from the
     * initializer (only the OUTERMOST dim may be implicit). */
    int is_array = 0;
    while (g_cur.kind == TOK_LBRACKET) {
        if (d.n_dims >= MAX_DIMS)
            die(g_cur.line, g_cur.col, "too many array dimensions (max 4)");
        next_tok();
        if (g_cur.kind == TOK_RBRACKET && d.n_dims == 0) {
            d.sizeless    = 1;
            d.dims[d.n_dims++] = 0;   /* placeholder; caller sizes from init */
            next_tok();               /* past ']' */
            is_array = 1;
            continue;
        }
        {
            long asz = parse_const_bin(0);
            if (asz <= 0)
                die(g_cur.line, g_cur.col,
                    "array size must be a positive integer constant");
            d.dims[d.n_dims++] = (int)asz;
        }
        expect(TOK_RBRACKET, "']'");
        is_array = 1;
    }
    if (d.n_dims > 1) {
        /* inner stride in ELEMENTS (callers scale by element size). */
        int inner = 1;
        for (int i = 1; i < d.n_dims; i++) inner *= d.dims[i];
        d.row_stride = inner;
    }

    /* Array-typedef base used with no further declarator: the object IS an
     * array (K&R A.8.9 -- `MSG greeting` == `char greeting[]`, where
     * `typedef char MSG[]`).  base.base is already the array tword; produce
     * the SAME Declarator a literal sizeless `[]` would (n_dims=1, sizeless),
     * so the caller's existing init-sizing path (A.8.7) completes it.  sh's
     * array typedefs are all sizeless; a use-site `[`/`*` is not part of the
     * Bourne source and falls through to the normal merge below. */
    if (!is_array && stars == 0 && ISARY(base.base)) {
        d.n_dims   = 1;
        d.dims[0]  = 0;
        d.sizeless = 1;
        d.type     = base.base;             /* already the array tword */
        return d;
    }

    /* merge: base + `stars` pointer groups + optional outer ARY.  Byte-identical
     * to type_for_decl(base, stars, is_array) — the encoding the whole tree
     * already depends on (goldens: depth-1 == old LT_*_PTR). */
    d.type = ((stars == 0) && !is_array)
                 ? (tword)base.base
                 : type_for_decl(base, stars, is_array);
    return d;
}

/* B-7: set by parse_fn_ptr_declarator when the declarator is an ARRAY of
 * fn-ptrs `T (*name[N])(args)` (e.g. od's conv_vec).  0 = scalar fn-ptr,
 * -1 = `[]` (size from init list), N = `[N]`.  Read by the caller right
 * after a 1 return. */
static int g_fnptr_decl_arr = 0;

/* lex_peek_save/restore (cursor {idx,cur} checkpoints) live in lex_pp.c;
 * declared in fcc.h.  Since Increment 1 tokenized the whole TU up front, a
 * lookahead rewind is frame-safe by construction. */
static void emit_deref_lvalue_rmw(Local *lc, Global *gv, int is_inc,
                                  int ln, int cl);   /* defined below */

/* fcc2 P1.4 loop-scoped promotion: monotonic loop-region id, stamped into the
 * IR_LOOP_BEGIN/END marker pair each loop records so ir_promote_locals can match
 * a region.  Never reset (uniqueness within a function's g_ir is all that's
 * needed; g_ir is per-function). */
static unsigned g_loop_seq = 0;
static int build_stmt(void);
static void put_array_init_item(Global *g, int n, LocalType at);
static int stmt_wide_opassign(TokKind op, int rhs);
static int build_decl(TypeSpec t);

/* Stores are A-preserving: a statement-context store node carries the RHS's
 * result descriptor (same rule as the expression classifier), keeping the
 * FCC_AST_CHECK walk-time assertion meaningful for statement trees too. */
static void
ast_copy_desc(int dst, int src)
{
    g_ast[dst].type        = g_ast[src].type;
    g_ast[dst].struct_id   = g_ast[src].struct_id;
    g_ast[dst].is_unsigned = g_ast[src].is_unsigned;
    g_ast[dst].fn_sig      = g_ast[src].fn_sig;
}

/* Store-target conversion mirror: emit_store_local converts an int/char RHS
 * to float for a float-typed target (itof) — the node descriptor must match
 * the post-store runtime state. */
static void
ast_store_conv(int dst, Local *lc, Global *gv)
{
    LocalType tt = lc ? lc->type : (gv ? gv->type : LT_INT);
    if (tt == LT_FLOAT &&
        (g_ast[dst].type == LT_INT || g_ast[dst].type == LT_CHAR))
        g_ast[dst].type = LT_FLOAT;
}

/* K&R-canonical uniform lvalue-address walker (docs plan
 * 2026-07-23-fcc-uniform-lvalue-walker.md).  Walk an N_LV_CHAIN into an fpr
 * holding the lvalue's ADDRESS.  Invariant: address == kd + off; `.field`
 * accumulates off, `->field`/`[i]`-on-a-ptr/`*` flush it via a deref
 * (emit_fpr_deref_field preserves the bank byte -- so &p[i] on a ptr-to-ptr
 * keeps its bank for free).  Returns kd with the pending offset flushed, so a
 * caller derefs/stores at (kd, 0).  Sets g_expr_type/struct_id to the leaf.
 * Non-static: the expression walk (parse_expr.c) reuses it for value-leaving
 * lvalue stores/incdec/address-of (N_LV_STORE_E/N_LV_INCDEC_E). */
int
emit_lvalue_addr(int head)
{
    int off, kd = emit_lvalue_addr_off(head, &off);
    emit_fpr_add_const(kd, off);
    return kd;
}

/* emit_lvalue_addr with the final offset left to the caller: the address is
 * kd + *offp, and kd is unchanged by it. */
int
emit_lvalue_addr_off(int head, int *offp)
{
    int kd;
    if (g_ast[head].c >= 0)
        kd = walk_fpr(g_ast[head].c);        /* computed pointer value = pointee addr */
    else
        kd = fpr_addr_sym(g_ast[head].sym_lc, g_ast[head].sym_gv);  /* &named var */
    int off = 0;
    for (int s = g_ast[head].b; s >= 0; s = g_ast[s].a) {
        switch (g_ast[s].kind) {
        case N_LV_STEP_DOT:
            off += (int)g_ast[s].val;                       /* same object */
            break;
        case N_LV_STEP_ARROW:
            emit_fpr_deref_field(kd, LT_STRUCT_PTR, off);   /* follow the pointer */
            off = (int)g_ast[s].val;
            break;
        case N_LV_STEP_DEREF:
            emit_fpr_deref_field(kd, LT_STRUCT_PTR, off);
            off = 0;
            break;
        case N_LV_STEP_INDEX:
            if (g_ast[s].flags & 1) {                       /* pointer base: deref */
                emit_fpr_deref_field(kd, LT_STRUCT_PTR, off);
                off = 0;
            } else if (off) {                               /* array base: flush */
                emit_fpr_add_const(kd, off);
                off = 0;
            }
            emit_fpr_add_index(kd, g_ast[s].b, g_ast[s].val);
            break;
        default:
            die(g_ast[s].line, g_ast[s].col, "bad lvalue step (internal)");
        }
    }
    *offp            = off;
    g_expr_type      = g_ast[head].type;
    g_expr_struct_id = g_ast[head].struct_id;
    return kd;
}

/* Increment 3b: the statement walker.  Phase 1 converts parse_stmt's
 * dispatcher arms one at a time to build+walk-immediately (statement emission
 * is sequential, so each arm flips independently with goldens green); phase 2
 * turns control flow into trees and moves the walk to the top. */
void
walk_stmt(int n)
{
    g_stmt_line = g_ast[n].line;
    g_stmt_col  = g_ast[n].col;
    switch (g_ast[n].kind) {
    case S_LABEL: {
        int idx = user_labels_intern(g_ast[n].name, g_ast[n].name_len,
                                     g_ast[n].line, g_ast[n].col);
        if (g_user_labels[idx].defined)
            die(g_ast[n].line, g_ast[n].col, "duplicate label");
        g_user_labels[idx].defined = 1;
        ir_emitf("%s_uL_%s\n", g_func_name, g_user_labels[idx].name);
        g_last_stmt_returned = 0;
        if (g_ast[n].a >= 0)
            walk_stmt(g_ast[n].a);   /* the labeled statement itself */
        break;
    }
    case S_GOTO: {
        int idx = user_labels_intern(g_ast[n].name, g_ast[n].name_len,
                                     g_ast[n].line, g_ast[n].col);
        /* P2', apple/fgx#237: A BACKWARD `goto' IS A LOOP BACK EDGE AND GETS
         * THE SAFEPOINT, exactly as S_WHILE / S_DO / S_FOR do.
         *
         * K&R A.9.6 (2nd ed, p.184) is what settles it rather than a judgement
         * about which loops "look like" loops.  Defining `continue', the text
         * says: "a continue not contained in a smaller iteration statement is
         * the same as goto contin."  The language draws no line between a
         * loop's back edge and a `goto' to a label above it -- it defines one
         * in terms of the other -- so a safepoint that belongs on one belongs
         * on the other.  `continue' reaches one today only because it branches
         * to a loop top that already has one.
         *
         * THE TEST IS SINGLE-PASS AND NEEDS NO NEW STATE.  walk_stmt runs in
         * source order and S_LABEL sets `defined' when it is walked, so a label
         * that is ALREADY defined at the `goto' is by construction above it.
         * A forward `goto' -- an error exit, a skip over a block -- sees
         * `defined' clear and emits nothing, which is right: it is not a back
         * edge and cannot spin.
         *
         * A IS DEAD HERE, as it is at the three loop arms: a `goto' is a
         * statement, so nothing downstream reads the previous expression's
         * value, and the BRL below is unconditional so the flags do not
         * survive either. */
        if (g_user_labels[idx].defined)
            emit_safepoint();
        g_user_labels[idx].referenced = 1;
        ir_emitf("                BRL     %s_uL_%s\n",
                g_func_name, g_user_labels[idx].name);
        g_last_stmt_returned = 0;
        break;
    }
    case S_BREAK:
        if (g_loop_ctx_top == 0)
            die(g_ast[n].line, g_ast[n].col, "'break' outside loop/switch");
        emit_bra_label(g_loop_ctx[g_loop_ctx_top - 1].break_label);
        g_last_stmt_returned = 0;
        break;
    case S_CONTINUE: {
        if (g_loop_ctx_top == 0)
            die(g_ast[n].line, g_ast[n].col, "'continue' outside loop");
        int lab = g_loop_ctx[g_loop_ctx_top - 1].continue_label;
        if (lab < 0)
            die(g_ast[n].line, g_ast[n].col,
                "'continue' inside switch with no enclosing loop");
        emit_bra_label(lab);
        g_last_stmt_returned = 0;
        break;
    }
    case S_RETURN: {
        if (g_ast[n].a < 0) {
            emit_epilogue_return();
            g_last_stmt_returned = 1;
            break;
        }
        {
        LocalType ret_t = (LocalType)g_ast[n].val;
        if (ISPTR(ret_t)) {
            /* Pointer return: the value rides an FPR; an int RHS (NULL)
             * materializes with a ZERO bank inside walk_fpr — the c35
             * normalization in ONE place.  P3-2.4 ABI: the return home
             * is FPR0 (the epilogue never touches the FPR band and the
             * caller captures before its spill restore). */
            int k = walk_fpr(g_ast[n].a);        /* #12: bank per constness */
            emit_fpr_ret(k);
            fpr_drop(k);
        } else {
            walk_val(g_ast[n].a);
            /* Widen an int/char return expression to a LONG return type —
             * SIGNED sign-extends, UNSIGNED zero-extends (emit_promote_a_to_
             * long).  Without this `code_int getcode(){ ...; return -1; }`
             * returned 0x0000FFFF (=65535), so compress(1) decompress()'s
             * `while ((code = getcode()) > -1)` never saw EOF and over-read
             * (garbage-long uncompress output). */
            if (ret_t == LT_LONG &&
                (g_expr_type == LT_INT || g_expr_type == LT_CHAR))
                emit_promote_a_to_long();
            /* K&R A.9.6: "The expression is converted, as by assignment, to
             * the type returned by the function" -- the float crossings too
             * (apple/fgx#396). */
            if (ret_t == LT_FLOAT &&
                (g_expr_type == LT_INT || g_expr_type == LT_CHAR))
                emit_int_to_float();
            if (ret_t == LT_INT || ret_t == LT_CHAR ||
                ret_t == LT_LONG || ret_t == LT_FLOAT)
                emit_assign_conv(ret_t);
            if (IS_QUAD(ret_t))
                emit_to_quad(ret_t);
        }
        }
        emit_epilogue_return();
        g_last_stmt_returned = 1;
        break;
    }
    case S_PREINC_DEREF:
        emit_deref_lvalue_rmw(g_ast[n].sym_lc, g_ast[n].sym_gv,
                              (g_ast[n].flags & AF_IS_INC) ? 1 : 0,
                              g_ast[n].line, g_ast[n].col);
        g_last_stmt_returned = 0;
        break;
    case S_PREINC_STMT: {
        Local  *lc = g_ast[n].sym_lc;
        Global *gv = g_ast[n].sym_gv;
        int is_inc = (g_ast[n].flags & AF_IS_INC) != 0;
        if (IS_QUAD(lc ? lc->type : gv->type)) {
            emit_llong_incdec(lc, gv, is_inc, /*return_old=*/0);
            break;
        }
        if ((lc ? lc->type : gv->type) == LT_FLOAT) {
            emit_float_var_incdec(lc, gv, is_inc, /*return_old=*/0);
            break;
        }
        if (lc != NULL) {
            if (lc->type == LT_INT || lc->type == LT_CHAR) {
                emit_incdec_local(lc, is_inc);
            } else if (lc->type == LT_LONG) {
                emit_long_incdec_local(lc, is_inc, /*return_old=*/0);   /* full 32-bit ±1 w/ carry */
            } else {
                int st = (int)g_ast[n].val;
                emit_load_local(lc);
                if (is_inc) {
                    ir_record_raw(IR_ADD_CONST, (unsigned)(st), 0, NULL);
                } else {
                    ir_record_raw(IR_SUB_CONST, (unsigned)(st), 0, NULL);
                }
                emit_incdec_store_local(lc);
            }
        } else if (gv->type == LT_LONG) {
            emit_load_global(gv);
            if (is_inc) {
                ir_emitf("                CLC\n");
                ir_emitf("                ADC     #1\n");
                ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(gname(gv)));
                ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
                ir_emitf("                ADC     #0\n");
                ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(gname(gv)));
            } else {
                ir_emitf("                SEC\n");
                ir_emitf("                SBC     #1\n");
                ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(gname(gv)));
                ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
                ir_emitf("                SBC     #0\n");
                ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(gname(gv)));
            }
        } else if (ISPTR(gv->type)) {
            /* global pointer for-step (tcsh ed.inputl `Cursor++`, Cursor a
             * Char*): stride precomputed at build; bump the offset word,
             * emit_store_global_int round-trips the stored bank.  Mirrors the
             * S_POSTINC_VAR_STMT G36 global-pointer path. */
            emit_load_global(gv);
            if (is_inc) {
                ir_record_raw(IR_ADD_CONST, (unsigned)((int)g_ast[n].val), 0, NULL);
            } else {
                ir_record_raw(IR_SUB_CONST, (unsigned)((int)g_ast[n].val), 0, NULL);
            }
            emit_store_global_int(gv);
        } else {
            emit_load_global(gv);
            if (is_inc) {
                ir_emitf("                CLC\n");
                ir_emitf("                ADC     #1\n");
            } else {
                ir_emitf("                SEC\n");
                ir_emitf("                SBC     #1\n");
            }
            if (gv->type == LT_CHAR) emit_store_global_char(gv);
            else                     emit_store_global_int(gv);
        }
        g_last_stmt_returned = 0;
        break;
    }
    case S_DSTORE_COMPOUND: {
        Local  *lc = g_ast[n].sym_lc;
        Global *gv = g_ast[n].sym_gv;      /* queue 4b: global twin */
        TokKind op = g_ast[n].op;
        int post = (int)g_ast[n].val - 1;          /* -1/0/+1 */
        LocalType ptr_type = lc ? lc->type : gv->type;
        int is_byte = (ptr_type == LT_CHAR_PTR || ptr_type == LT_VOID_PTR);
        int kd = fpr_load_sym(lc, gv);     /* kd = OLD value; A = old offset */
        if (post) {
            int st = elem_size_for(ptr_type, lc ? lc->struct_id
                                               : gv->struct_id);
            if (st == 0) st = 1;
            if (post > 0) {
                ir_record_raw(IR_ADD_CONST, (unsigned)(st), 0, NULL);
            } else {
                ir_record_raw(IR_SUB_CONST, (unsigned)(st), 0, NULL);
            }
            if (lc == NULL)
                die(g_ast[n].line, g_ast[n].col,
                    "post inc/dec deref-compound on a global (internal)");
            emit_incdec_store_local(lc);   /* home = old±st; deref base = OLD */
        }
        if (DECREF(ptr_type) == LT_LONG || DECREF(ptr_type) == LT_FLOAT) {
            /* A 4-BYTE POINTEE IS READ, COMBINED AND WRITTEN WHOLE.  The word
             * path below read sixteen bits, took the high word from whatever
             * _fcc_long_hi held, and stored sixteen back: `*pl += 70000L'
             * kept the old high word (apple/fgx#396).  K&R A.7.17: E1 op= E2
             * is E1 = E1 op (E2), in E1's type after the usual conversions. */
            LocalType et = DECREF(ptr_type);
            emit_fpr_deref_field(kd, et, 0);   /* A:_fcc_long_hi = current */
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
            emit_compound_op(op, lc ? lc->is_unsigned : gv->is_unsigned, et);
            emit_fpr_deref_store_long(kd, 0);
            fpr_drop(kd);
            g_last_stmt_returned = 0;
            break;
        }
        emit_fpr_deref_field(kd, is_byte ? LT_CHAR : LT_INT, 0);  /* current */
        emit_push_a();                     /* current @ 1,S */
        walk_val(g_ast[n].a);
        /* The object being modified is the POINTEE.  When that is itself a
         * pointer -- `struct foo **p; *p += 1' -- the operand scales by what
         * IT points at, not by one (apple/fgx#154). */
        emit_scale_compound_ptr(DECREF(ptr_type),
                                lc ? lc->struct_id : gv->struct_id, op);
        emit_stash_rhs();
        emit_pop_a();
        emit_compound_op(op, promoted_unsigned(is_byte ? LT_CHAR : LT_INT,
                                               lc ? lc->is_unsigned
                                                  : gv->is_unsigned),
                         LT_INT);  /* A-1 closure: pointee signedness (queue
                                    * 3b), after promotion (A.6.1) */
        if (is_byte) emit_fpr_deref_store_byte(kd, 0);
        else         emit_fpr_deref_store_word(kd, 0);
        fpr_drop(kd);
        g_last_stmt_returned = 0;
        break;
    }
    case S_DSTORE_LOCAL: {
        Local *lc = g_ast[n].sym_lc;
        int post = (int)g_ast[n].val - 1;
        LocalType ptr_type = lc->type;
        /* B1c-2a-step-2: post-form on a promotable int/char/void-pointee
         * pointer routes through the structured SETUP/STORE pair.  The
         * promotability query runs at WALK time — emission history at this
         * point is identical to the historical parse-time query. */
        if (post && ir_ptr_promotable(lc) &&
            (ptr_type == LT_CHAR_PTR || ptr_type == LT_VOID_PTR ||
             ptr_type == LT_INT_PTR)) {
            int st = elem_size_for(ptr_type, lc->struct_id);
            if (st == 0) st = 1;
            emit_walk_store_setup(lc, st, post > 0);
            walk_expr_root(g_ast[n].a);
            emit_walk_store(lc, st, post > 0);
            g_last_stmt_returned = 0;
            break;
        }
        int kd = fpr_load_sym(lc, NULL);       /* kd = OLD value; A = old offset */
        if (post) {
            int st = elem_size_for(ptr_type, lc->struct_id);
            if (st == 0) st = 1;
            if (post > 0) {
                ir_record_raw(IR_ADD_CONST, (unsigned)(st), 0, NULL);
            } else {
                ir_record_raw(IR_SUB_CONST, (unsigned)(st), 0, NULL);
            }
            emit_incdec_store_local(lc);       /* home = old±st; deref base = OLD */
        }
        tword target = DECREF(ptr_type);
        if (ISPTR(target)) {
            int ks = walk_fpr(g_ast[n].a);
            emit_fpr_deref_store_ptr(kd, ks, 0);
            fpr_drop(ks);
        } else if (BTYPE(target) == BT_LONG || BTYPE(target) == BT_FLOAT) {
            walk_val(g_ast[n].a);
            if (BTYPE(target) == BT_FLOAT &&
                (g_expr_type == LT_INT || g_expr_type == LT_CHAR)) {
                emit_itof_rt();
            } else if (g_expr_type == LT_INT || g_expr_type == LT_CHAR) {
                emit_promote_a_to_long();   /* sign/zero-extend int RHS→long */
            }
            emit_assign_conv((BTYPE(target) == BT_FLOAT) ? LT_FLOAT : LT_LONG);
            emit_fpr_deref_store_long(kd, 0);
        } else if (BTYPE(target) == BT_CHAR || BTYPE(target) == BT_VOID) {
            walk_val(g_ast[n].a);
            emit_assign_conv(LT_CHAR);      /* float RHS narrows via ftoi */
            emit_fpr_deref_store_byte(kd, 0);
        } else {
            walk_val(g_ast[n].a);
            emit_assign_conv(LT_INT);
            emit_fpr_deref_store_word(kd, 0);
        }
        fpr_drop(kd);
        g_last_stmt_returned = 0;
        break;
    }
    case S_DSTORE_GENERAL: {
        int kd = walk_fpr(g_ast[n].a);         /* dest pointer */
        tword target = DECREF((tword)g_ast[n].val);
        if (ISPTR(target)) {
            int ks = walk_fpr(g_ast[n].b);     /* int RHS -> bank 0 */
            emit_fpr_deref_store_ptr(kd, ks, 0);
            fpr_drop(ks);
        } else if (IS_QUAD((LocalType)target)) {
            /* A double or long long target: all eight bytes, the right
             * operand converted to it first (K&R A.7.17).  This fell to the
             * int arm and stored two -- doscan.c's `**(double **)ptr =
             * atof(numbuf)'. */
            walk_val(g_ast[n].b);
            emit_to_quad((LocalType)target);
            emit_fpr_deref_store_llong(kd, 0);
        } else if (BTYPE(target) == BT_LONG || BTYPE(target) == BT_FLOAT) {
            walk_val(g_ast[n].b);
            if (BTYPE(target) == BT_FLOAT &&
                (g_expr_type == LT_INT || g_expr_type == LT_CHAR)) {
                emit_itof_rt();
            } else if (g_expr_type == LT_INT || g_expr_type == LT_CHAR) {
                emit_promote_a_to_long();   /* sign/zero-extend int RHS→long */
            }
            emit_assign_conv((BTYPE(target) == BT_FLOAT) ? LT_FLOAT : LT_LONG);
            emit_fpr_deref_store_long(kd, 0);
        } else if (BTYPE(target) == BT_CHAR || BTYPE(target) == BT_VOID) {
            walk_val(g_ast[n].b);
            emit_assign_conv(LT_CHAR);      /* float RHS narrows via ftoi */
            emit_fpr_deref_store_byte(kd, 0);
        } else {
            walk_val(g_ast[n].b);
            emit_assign_conv(LT_INT);
            emit_fpr_deref_store_word(kd, 0);
        }
        fpr_drop(kd);
        g_last_stmt_returned = 0;
        break;
    }
    case S_DSTORE_STRUCT_COPY: {
        int kd = walk_fpr(g_ast[n].a);         /* dest ptr / dest addr */
        int ks = walk_fpr(g_ast[n].b);         /* src address */
        emit_fpr_struct_copy(kd, ks, (int)g_ast[n].val);
        fpr_drop(ks);
        fpr_drop(kd);
        g_last_stmt_returned = 0;
        break;
    }
    case S_STORE_DOT_ARRFIELD: {
        Field *leaf = g_ast[n].sym_f;
        Field *f2   = g_ast[n].sym_f2;         /* struct-array subfield or NULL */
        int kd = fpr_addr_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        emit_fpr_add_const(kd, (int)g_ast[n].val);
        walk_val(g_ast[n].a);                  /* index -> A */
        emit_index_scale(g_ast[n].val_hi);     /* elem size */
        emit_fpr_add_a(kd);
        int is_byte = (leaf->type == LT_CHAR_ARRAY);
        if (f2 != NULL) {
            is_byte = (f2->type == LT_CHAR);
            emit_fpr_add_const(kd, f2->byte_offset);
        }
        if (g_ast[n].op != TOK_EOF) {
            /* correctness queue 2b: op= — load the current element
             * through kd, apply the RHS, store back (the 4-byte arm
             * mirrors S_ARR_STORE's compound type handling). */
            if (leaf->type == LT_LONG_ARRAY || leaf->type == LT_FLOAT_ARRAY) {
                LocalType et = (leaf->type == LT_FLOAT_ARRAY) ? LT_FLOAT
                                                              : LT_LONG;
                emit_fpr_deref_field(kd, et, 0);
                g_expr_type = et;
                emit_push_long();
                walk_val(g_ast[n].b);
                {
                    LocalType rt = g_ast[g_ast[n].b].type;
                    if (et == LT_FLOAT) {
                        if (rt == LT_INT || rt == LT_CHAR) emit_int_to_float();
                        else if (rt == LT_LONG)            emit_long_to_float();
                    } else {
                        if (rt == LT_INT || rt == LT_CHAR) emit_promote_a_to_long();
                    }
                }
                if (g_expr_type != LT_FLOAT) g_expr_type = et;
                emit_stash_rhs();
                emit_pop_long();
                if (g_expr_type != LT_FLOAT) g_expr_type = et;
                emit_compound_op(g_ast[n].op, leaf->is_unsigned, et);
                emit_fpr_deref_store_long(kd, 0);
            } else {
                int lhs_u = f2 ? f2->is_unsigned : leaf->is_unsigned;
                emit_fpr_deref_field(kd, is_byte ? LT_CHAR : LT_INT, 0);
                emit_push_a();
                walk_val(g_ast[n].b);
                emit_stash_rhs();
                emit_pop_a();
                emit_compound_op(g_ast[n].op, lhs_u, LT_INT);
                if (is_byte) emit_fpr_deref_store_byte(kd, 0);
                else         emit_fpr_deref_store_word(kd, 0);
            }
            fpr_drop(kd);
            break;
        }
        walk_val(g_ast[n].b);                  /* rhs -> A */
        if (leaf->type == LT_LONG_ARRAY || leaf->type == LT_FLOAT_ARRAY) {
            /* int RHS: promote — float target converts (itof), long target
             * zero-extends (the scalar-field store idiom above). */
            if (g_expr_type == LT_INT || g_expr_type == LT_CHAR) {
                if (leaf->type == LT_FLOAT_ARRAY) {
                    emit_itof_rt();
                } else {
                    emit_promote_a_to_long();   /* sign/zero-extend int RHS→long */
                }
            }
            emit_assign_conv(leaf->type == LT_FLOAT_ARRAY ? LT_FLOAT : LT_LONG);  /* A.7.17 */
            emit_fpr_deref_store_long(kd, 0);
        } else if (is_byte) {
            emit_fpr_deref_store_byte(kd, 0);
        } else {
            emit_fpr_deref_store_word(kd, 0);
        }
        fpr_drop(kd);
        break;
    }
    case S_COMPOUND_DOTFIELD: {
        Field synth = *g_ast[n].sym_f;
        synth.byte_offset = (int)g_ast[n].val;
        /* A POINTER field under `+=' / `-=' moves within one bank, so only the
         * OFFSET WORD is read and written and the bank byte is never touched.
         *
         * Loading it and putting it back is not equivalent, and that is a trap
         * worth naming: the load stages the bank in _fcc_ptr+2, the RHS is
         * evaluated NEXT, and _fcc_ptr is direct-page scratch that any call --
         * or any pointer load inside the RHS -- is free to overwrite.
         * `x.f += g()' would then store whatever the callee happened to leave
         * there.  The fpr chain paths already store word-only for this reason
         * (apple/fgx#154).  fldty keeps the real type for the scale below. */
        LocalType fldty = synth.type;
        if (ISPTR(fldty) &&
            (g_ast[n].op == TOK_PLUSEQ || g_ast[n].op == TOK_MINUSEQ))
            synth.type = LT_INT;                  /* offset word only */
        if (g_ast[n].sym_lc) emit_load_local_field(g_ast[n].sym_lc, &synth);
        else                 emit_load_global_field(g_ast[n].sym_gv, &synth);
        {
        int lhs_u = g_expr_unsigned;   /* A-1: LHS signedness at load */
        if (synth.type == LT_LONG || synth.type == LT_FLOAT) {
            /* 4-byte field: save BOTH words across the RHS walk and promote
             * an int/char RHS — the lone push_a here dropped the LHS high
             * word (same class as the N_COMPOUND_VAR fix; date(1)'s
             * `tv.tv_sec += ...` gtime tail is the load-bearing user). */
            emit_push_long();
            walk_expr_root(g_ast[n].a);
            {
                LocalType rt = g_ast[g_ast[n].a].type;
                if (synth.type == LT_FLOAT) {
                    if (rt == LT_INT || rt == LT_CHAR) emit_int_to_float();
                    else if (rt == LT_LONG)            emit_long_to_float();
                } else {
                    if (rt == LT_INT || rt == LT_CHAR) emit_promote_a_to_long();
                }
            }
            if (g_expr_type != LT_FLOAT) g_expr_type = synth.type;
            emit_stash_rhs();
            emit_pop_long();
            if (g_expr_type != LT_FLOAT) g_expr_type = synth.type;
            emit_compound_op(g_ast[n].op, lhs_u, synth.type);
        } else {
            emit_push_a();
            walk_expr_root(g_ast[n].a);
            /* A pointer field scales its operand (apple/fgx#154); `++x.f'
             * desugars to `x.f += 1' and landed here unscaled. */
            emit_scale_compound_ptr(fldty, synth.struct_id, g_ast[n].op);
            emit_stash_rhs();
            emit_pop_a();
            emit_compound_op(g_ast[n].op, lhs_u, LT_INT);
        }
        }
        if (g_ast[n].sym_lc) emit_store_local_field(g_ast[n].sym_lc, &synth);
        else                 emit_store_global_field(g_ast[n].sym_gv, &synth);
        break;
    }
    case S_AV_STORE: {
        Field *leaf = g_ast[n].sym_f;
        int kd = fpr_load_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        emit_fpr_add_const(kd, (int)g_ast[n].val);   /* kd = &leaf */
        if (ISPTR(leaf->type)) {               /* pointer leaf: 4-byte ptr store */
            int ks = walk_fpr(g_ast[n].b);     /* RHS pointer into an fpr */
            emit_fpr_deref_store_ptr(kd, ks, 0);
            fpr_drop(ks);
            fpr_drop(kd);
            break;
        }
        if (leaf->type == LT_LONG || leaf->type == LT_FLOAT) {
            /* 4-byte scalar leaf.  The promotion handling is S_STORE_DOT_
             * ARRFIELD's, verbatim: an int/char RHS zero/sign-extends for a
             * long target and converts for a float one.  Without it
             * `p->s.longfield = 1;` would store a 16-bit RHS's stack garbage
             * as the high word -- which is why the fixture assigns from an INT
             * as well as from a long. */
            walk_val(g_ast[n].b);              /* rhs -> A */
            if (g_expr_type == LT_INT || g_expr_type == LT_CHAR) {
                if (leaf->type == LT_FLOAT) emit_itof_rt();
                else                        emit_promote_a_to_long();
            }
            emit_assign_conv(leaf->type);          /* A.7.17: long<->float */
            emit_fpr_deref_store_long(kd, 0);
            fpr_drop(kd);
            break;
        }
        if (g_ast[n].a >= 0) {                 /* indexed array leaf */
            int is_byte = (leaf->type == LT_CHAR_ARRAY);
            int is_long = (leaf->type == LT_LONG_ARRAY ||
                           leaf->type == LT_FLOAT_ARRAY);
            walk_val(g_ast[n].a);              /* index -> A */
            /* SCALE BY THE ELEMENT, which is the whole of what makes a long
             * array different here: one ASL for a 2-byte element, two for a
             * 4-byte one, none for a byte.  Getting this wrong is apple/fgx
             * #154's shape -- a stride that moves the wrong distance and
             * writes a plausible value into the wrong slot. */
            if (is_long)       { ir_emitf("                ASL\n");
                                 ir_emitf("                ASL\n"); }
            else if (!is_byte)   ir_emitf("                ASL\n");
            emit_fpr_add_a(kd);
            walk_val(g_ast[n].b);              /* rhs -> A */
            if (is_long) {
                /* The promotion is the 4-byte scalar arm's, for its reason:
                 * without it `p->s.longarr[i] = 1;` stores a 16-bit RHS's
                 * stack garbage as the high word. */
                if (g_expr_type == LT_INT || g_expr_type == LT_CHAR) {
                    if (leaf->type == LT_FLOAT_ARRAY) emit_itof_rt();
                    else                              emit_promote_a_to_long();
                }
                emit_assign_conv(leaf->type == LT_FLOAT_ARRAY ? LT_FLOAT : LT_LONG);  /* A.7.17 */
                emit_fpr_deref_store_long(kd, 0);
            }
            else if (is_byte) emit_fpr_deref_store_byte(kd, 0);
            else              emit_fpr_deref_store_word(kd, 0);
            fpr_drop(kd);
            break;
        }
        /* scalar int/char leaf store */
        {
            int is_byte = (leaf->type == LT_CHAR);
            walk_val(g_ast[n].b);              /* rhs -> A */
            if (is_byte) emit_fpr_deref_store_byte(kd, 0);
            else         emit_fpr_deref_store_word(kd, 0);
            fpr_drop(kd);
        }
        break;
    }
    case S_CHAIN_STORE: {
        Field *f = g_ast[n].sym_f;
        /* flags&1: the base is a struct VAR (aggregate), not a pointer -- use
         * its ADDRESS (fpr_addr_sym), since the first hop derefs *(base+off)
         * to reach a struct-ptr member (the `structvar.ptr->...` dot-bridge).
         * The arrow case (a struct-ptr base) uses fpr_load_sym (its value). */
        int kd = (g_ast[n].flags & 1)
                   ? fpr_addr_sym(g_ast[n].sym_lc, g_ast[n].sym_gv)
                   : fpr_load_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        for (int h = 0; h < g_ast[n].n_kids; h++) {
            Field *hop = g_ast_fields[g_ast[n].kid0 + h];
            emit_fpr_deref_field(kd, LT_STRUCT_PTR, hop->byte_offset);
        }
        if (g_ast[n].a >= 0) {                 /* G32: chain -> p[i] = rhs */
            int is_byte = (f->type == LT_CHAR_PTR || f->type == LT_VOID_PTR);
            emit_fpr_deref_field(kd, f->type, f->byte_offset); /* kd = p value */
            walk_val(g_ast[n].a);              /* index -> A */
            if (!is_byte)
                ir_emitf("                ASL\n");
            emit_fpr_add_a(kd);
            walk_val(g_ast[n].b);              /* rhs -> A */
            if (is_byte) emit_fpr_deref_store_byte(kd, 0);
            else         emit_fpr_deref_store_word(kd, 0);
            fpr_drop(kd);
            break;
        }
        if (g_ast[n].op != TOK_EOF) {          /* compound op= via the chain */
            /* A POINTER leaf, twice over (apple/fgx#154).  Asking
             * emit_fpr_deref_field for the pointer lands it back in kd and
             * loses the lvalue's ADDRESS, so the store went through the
             * pointer instead of into it; the offset word keeps kd intact and
             * the word store leaves the bank alone.  And the operand has to be
             * scaled by the pointee, or `p->q->next += 1' moves one byte. */
            emit_fpr_deref_field(kd, ISPTR(f->type) ? LT_INT : f->type,
                                 f->byte_offset);               /* current */
            emit_push_a();
            walk_val(g_ast[n].b);
            emit_scale_compound_ptr(f->type, f->struct_id, g_ast[n].op);
            emit_stash_rhs();
            emit_pop_a();
            emit_compound_op(g_ast[n].op, f->is_unsigned, LT_INT);
            if (f->type == LT_CHAR)
                emit_fpr_deref_store_byte(kd, f->byte_offset);
            else if (f->type == LT_LONG || f->type == LT_FLOAT)
                emit_fpr_deref_store_long(kd, f->byte_offset);
            else
                emit_fpr_deref_store_word(kd, f->byte_offset);
            fpr_drop(kd);
            break;
        }
        if (ISPTR(f->type)) {
            int ks = walk_fpr(g_ast[n].b);     /* int RHS -> bank 0 */
            emit_fpr_deref_store_ptr(kd, ks, f->byte_offset);
            fpr_drop(ks);
        } else if (f->type == LT_LONG || f->type == LT_FLOAT) {
            walk_val(g_ast[n].b);
            if (f->type == LT_FLOAT &&
                (g_expr_type == LT_INT || g_expr_type == LT_CHAR)) {
                emit_itof_rt();
            } else if (g_expr_type == LT_INT || g_expr_type == LT_CHAR) {
                emit_promote_a_to_long();   /* sign/zero-extend int RHS→long */
            }
            emit_assign_conv(f->type);             /* A.7.17: long<->float */
            emit_fpr_deref_store_long(kd, f->byte_offset);
        } else if (f->type == LT_CHAR) {
            walk_val(g_ast[n].b);
            emit_fpr_deref_store_byte(kd, f->byte_offset);
        } else {
            walk_val(g_ast[n].b);
            emit_fpr_deref_store_word(kd, f->byte_offset);
        }
        fpr_drop(kd);
        break;
    }
    case S_STORE_ARROW_ARRFIELD: {
        Field *f  = g_ast[n].sym_f;
        Field *f2 = g_ast[n].sym_f2;
        int kd = fpr_load_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        emit_fpr_add_const(kd, f->byte_offset);
        walk_val(g_ast[n].a);                  /* index -> A */
        emit_index_scale(g_ast[n].val_hi);
        emit_fpr_add_a(kd);
        int is_byte = (f->type == LT_CHAR_ARRAY);
        if (f2 != NULL) {
            is_byte = (f2->type == LT_CHAR);
            emit_fpr_add_const(kd, f2->byte_offset);
        }
        if (g_ast[n].op != TOK_EOF) {
            /* correctness queue 2b: op= (arrow twin — see the dot case). */
            if (f->type == LT_LONG_ARRAY || f->type == LT_FLOAT_ARRAY) {
                LocalType et = (f->type == LT_FLOAT_ARRAY) ? LT_FLOAT
                                                           : LT_LONG;
                emit_fpr_deref_field(kd, et, 0);
                g_expr_type = et;
                emit_push_long();
                walk_val(g_ast[n].b);
                {
                    LocalType rt = g_ast[g_ast[n].b].type;
                    if (et == LT_FLOAT) {
                        if (rt == LT_INT || rt == LT_CHAR) emit_int_to_float();
                        else if (rt == LT_LONG)            emit_long_to_float();
                    } else {
                        if (rt == LT_INT || rt == LT_CHAR) emit_promote_a_to_long();
                    }
                }
                if (g_expr_type != LT_FLOAT) g_expr_type = et;
                emit_stash_rhs();
                emit_pop_long();
                if (g_expr_type != LT_FLOAT) g_expr_type = et;
                emit_compound_op(g_ast[n].op, f->is_unsigned, et);
                emit_fpr_deref_store_long(kd, 0);
            } else {
                int lhs_u = f2 ? f2->is_unsigned : f->is_unsigned;
                emit_fpr_deref_field(kd, is_byte ? LT_CHAR : LT_INT, 0);
                emit_push_a();
                walk_val(g_ast[n].b);
                emit_stash_rhs();
                emit_pop_a();
                emit_compound_op(g_ast[n].op, lhs_u, LT_INT);
                if (is_byte) emit_fpr_deref_store_byte(kd, 0);
                else         emit_fpr_deref_store_word(kd, 0);
            }
            fpr_drop(kd);
            break;
        }
        if (is_ptr_array(f->type)) {
            int ks = walk_fpr(g_ast[n].b);     /* ptr elem: full pair */
            emit_fpr_deref_store_ptr(kd, ks, 0);
            fpr_drop(ks);
        } else if (f->type == LT_LONG_ARRAY || f->type == LT_FLOAT_ARRAY) {
            walk_val(g_ast[n].b);
            if (g_expr_type == LT_INT || g_expr_type == LT_CHAR) {
                if (f->type == LT_FLOAT_ARRAY) {
                    emit_itof_rt();
                } else {
                    emit_promote_a_to_long();   /* sign/zero-extend int RHS→long */
                }
            }
            emit_assign_conv(f->type == LT_FLOAT_ARRAY ? LT_FLOAT : LT_LONG);  /* A.7.17 */
            emit_fpr_deref_store_long(kd, 0);
        } else if (is_byte) {
            walk_val(g_ast[n].b);
            emit_fpr_deref_store_byte(kd, 0);
        } else {
            walk_val(g_ast[n].b);
            emit_fpr_deref_store_word(kd, 0);
        }
        fpr_drop(kd);
        break;
    }
    case S_STORE_PTRFIELD_IDX: {
        Field *f = g_ast[n].sym_f;
        int kd = fpr_load_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        emit_fpr_deref_field(kd, f->type, f->byte_offset);  /* kd = ptr value */
        walk_val(g_ast[n].a);                          /* index -> A */
        int is_byte = (f->type == LT_CHAR_PTR || f->type == LT_VOID_PTR);
        if (!is_byte)
            ir_emitf("                ASL\n");
        emit_fpr_add_a(kd);
        walk_val(g_ast[n].b);
        if (is_byte) emit_fpr_deref_store_byte(kd, 0);
        else         emit_fpr_deref_store_word(kd, 0);
        fpr_drop(kd);
        break;
    }
    case S_MEMBER_INCDEC_STMT: {
        Field *f = g_ast[n].sym_f;
        if (f->type == LT_LONG || f->type == LT_FLOAT || IS_QUAD(f->type)) {
            /* 32-bit ++/-- on a long or float member as a statement (value
             * discarded); the 16-bit ADD/SUB_CONST below loses a long's carry
             * into the high word (tcsh sh.time `tsum->tv_sec++`) and adds one
             * to a float's mantissa bits. */
            emit_wide_member_incdec(g_ast[n].sym_lc, g_ast[n].sym_gv,
                                    f->byte_offset, f->type,
                                    (g_ast[n].flags & AF_IS_INC) ? 1 : 0,
                                    /*return_old=*/0);
            break;
        }
        int st = (int)g_ast[n].val;
        int kd = fpr_load_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        /* read the member's OFFSET WORD (a ptr member's ++ rewrites only
         * the offset; the stored bank byte is untouched in memory — and a
         * ptr-typed deref_field would consume kd, losing the base). */
        emit_fpr_deref_field(kd, (f->type == LT_CHAR) ? LT_CHAR : LT_INT,
                             f->byte_offset);
        if (g_ast[n].flags & AF_IS_INC) {
            ir_record_raw(IR_ADD_CONST, (unsigned)(st), 0, NULL);
        } else {
            ir_record_raw(IR_SUB_CONST, (unsigned)(st), 0, NULL);
        }
        if (f->type == LT_CHAR) emit_fpr_deref_store_byte(kd, f->byte_offset);
        else                    emit_fpr_deref_store_word(kd, f->byte_offset);
        fpr_drop(kd);
        break;
    }
    case S_COMPOUND_MEMBER: {
        Field *f = g_ast[n].sym_f;
        int kd = fpr_load_sym(g_ast[n].sym_lc, g_ast[n].sym_gv);
        if (f->type == LT_LONG || f->type == LT_FLOAT) {
            /* 4-byte member compound-assign / `++`/`--` (which desugar to
             * `f += 1`).  The 16-bit path below dropped the high word -- a
             * long member RMW must save/combine/store BOTH words.  Mirrors the
             * long/float array-element compound path (S_STORE_DOT_ARRFIELD):
             * deref-load the 32-bit member, push_long, walk+promote the RHS,
             * stash, pop_long, 32-bit binop, deref-store-long. */
            LocalType et = f->type;
            emit_fpr_deref_field(kd, et, f->byte_offset);   /* acc = old (32-bit) */
            g_expr_type = et;
            emit_push_long();
            walk_val(g_ast[n].a);
            {
                LocalType rt = g_ast[g_ast[n].a].type;
                if (et == LT_FLOAT) {
                    if (rt == LT_INT || rt == LT_CHAR) emit_int_to_float();
                    else if (rt == LT_LONG)            emit_long_to_float();
                } else {
                    if (rt == LT_INT || rt == LT_CHAR) emit_promote_a_to_long();
                }
            }
            if (g_expr_type != LT_FLOAT) g_expr_type = et;
            emit_stash_rhs();
            emit_pop_long();
            if (g_expr_type != LT_FLOAT) g_expr_type = et;
            emit_compound_op(g_ast[n].op, f->is_unsigned, et);
            emit_fpr_deref_store_long(kd, f->byte_offset);
        } else {
            emit_fpr_deref_field(kd, (f->type == LT_CHAR) ? LT_CHAR : LT_INT,
                                 f->byte_offset);       /* A = current (offset word) */
            emit_push_a();                              /* current @ 1,S */
            walk_val(g_ast[n].a);
            /* A POINTER member scales its operand like any other pointer
             * (apple/fgx#154).  Missing here, `p->next += 1' -- and `++p->next',
             * which desugars to exactly that -- advanced ONE BYTE.  The
             * pointer-variable twin (N_COMPOUND_VAR) has always done this. */
            emit_scale_compound_ptr(f->type, f->struct_id, g_ast[n].op);
            emit_stash_rhs();
            emit_pop_a();                                /* A = current */
            emit_compound_op(g_ast[n].op, f->is_unsigned, LT_INT);
            if (f->type == LT_CHAR) emit_fpr_deref_store_byte(kd, f->byte_offset);
            else                    emit_fpr_deref_store_word(kd, f->byte_offset);
        }
        fpr_drop(kd);
        break;
    }
    case S_LV_STORE: {
        /* Uniform lvalue store: `chain [op]= rhs`.  Compute the address once,
         * then store/RMW by leaf type -- the K&R-canonical replacement for the
         * per-shape store handlers, used (as a fallback) for chains they miss. */
        int head = g_ast[n].a;
        LocalType leaf = g_ast[head].type;
        int is_byte = (leaf == LT_CHAR);
        int is_long = (leaf == LT_LONG || leaf == LT_FLOAT);
        int is_ptr  = ISPTR(leaf);
        if (g_ast[n].op == TOK_EQ) {                 /* plain store */
            int kd = emit_lvalue_addr(head);
            if (is_ptr) {
                int ks = walk_fpr(g_ast[n].c);
                emit_fpr_deref_store_ptr(kd, ks, 0);
                fpr_drop(ks);
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
                emit_fpr_deref_store_long(kd, 0);
            } else if (leaf == LT_STRUCT) {
                /* A STRUCT LEAF IS COPIED, NOT STORED -- the statement twin of
                 * N_LV_STORE_E's struct arm, and the same K&R A.7.17 reason:
                 * `=' on "structures or unions of the same type" replaces the
                 * OBJECT, all of it.  The word store below would write two
                 * bytes of the source's ADDRESS into the member (`s.p->u = v'
                 * reaches here).  Dest address in kd, source address in ks,
                 * one Y-indexed copy. */
                int sid = g_ast[head].struct_id;
                int nb  = (g_structs[sid].total_size + 1) & ~1;
                int ks  = walk_fpr(g_ast[n].c);
                if (ks < 0) { ks = fpr_alloc(); emit_fpr_from_carrier(ks); }
                emit_fpr_struct_copy(kd, ks, nb);
                fpr_drop(ks);
            } else {
                walk_val(g_ast[n].c);
                if (is_byte) emit_fpr_deref_store_byte(kd, 0);
                else         emit_fpr_deref_store_word(kd, 0);
            }
            fpr_drop(kd);
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
            } else {
                emit_fpr_deref_field(kd, is_byte ? LT_CHAR : LT_INT, 0);
                emit_push_a();
                walk_val(g_ast[n].c);
                /* A pointer LEAF scales its operand (apple/fgx#154).  The
                 * store below is word-only and leaves the bank alone, so the
                 * scale is the whole of it here. */
                emit_scale_compound_ptr(leaf, g_ast[head].struct_id,
                                        g_ast[n].op);
                emit_stash_rhs();
                emit_pop_a();
                emit_compound_op(g_ast[n].op, 0, LT_INT);
                if (is_byte) emit_fpr_deref_store_byte(kd, 0);
                else         emit_fpr_deref_store_word(kd, 0);
            }
            fpr_drop(kd);
        }
        break;
    }
    case S_LV_INCDEC: {
        /* Uniform lvalue ++/-- (statement, value discarded). */
        int head = g_ast[n].a;
        LocalType leaf = g_ast[head].type;
        int is_inc = (g_ast[n].flags & AF_IS_INC) != 0;
        int kd = emit_lvalue_addr(head);
        if (leaf == LT_LONG || leaf == LT_FLOAT) {
            emit_wide_incdec_at_fpr(kd, 0, leaf, is_inc, 0);
        } else if (ISPTR(leaf)) {
            /* elem_size_for: ptr_stride returns 0 for a STRUCT pointer and
             * the `st = 1' fallback made this walk one byte (apple/fgx#154). */
            int st = elem_size_for(leaf, g_ast[head].struct_id);
            /* LT_INT, not LT_STRUCT_PTR: emit_fpr_deref_field lands a POINTER
             * result back in fprK, so asking for the pointer overwrote the
             * lvalue's ADDRESS with its VALUE and the store below then wrote
             * through the pointer instead of into the object.  The comment
             * already said "offset word"; the argument did not (apple/fgx#154). */
            emit_fpr_deref_field(kd, LT_INT, 0);          /* A = offset word */
            if (is_inc) ir_record_raw(IR_ADD_CONST, (unsigned)st, 0, NULL);
            else        ir_record_raw(IR_SUB_CONST, (unsigned)st, 0, NULL);
            emit_fpr_deref_store_word(kd, 0);             /* offset only; bank intact */
        } else {
            int is_byte = (leaf == LT_CHAR);
            emit_fpr_deref_field(kd, is_byte ? LT_CHAR : LT_INT, 0);
            if (is_inc) ir_record_raw(IR_ADD_CONST, 1, 0, NULL);
            else        ir_record_raw(IR_SUB_CONST, 1, 0, NULL);
            if (is_byte) emit_fpr_deref_store_byte(kd, 0);
            else         emit_fpr_deref_store_word(kd, 0);
        }
        fpr_drop(kd);
        break;
    }
    case S_POSTINC_VAR_STMT: {
        Local  *lc = g_ast[n].sym_lc;
        Global *gv = g_ast[n].sym_gv;
        int is_inc = (g_ast[n].flags & AF_IS_INC) != 0;
        if (IS_QUAD(lc ? lc->type : gv->type)) {
            emit_llong_incdec(lc, gv, is_inc, /*return_old=*/0);
            break;
        }
        if ((lc ? lc->type : gv->type) == LT_FLOAT) {
            emit_float_var_incdec(lc, gv, is_inc, /*return_old=*/0);
            break;
        }
        if (lc != NULL) {
            if (lc->type == LT_INT || lc->type == LT_CHAR) {
                emit_incdec_local(lc, is_inc);
            } else if (lc->type == LT_LONG) {
                emit_long_incdec_local(lc, is_inc, /*return_old=*/0);   /* full 32-bit ±1 w/ carry */
            } else {
                int st = (int)g_ast[n].val;
                emit_load_local(lc);
                if (is_inc) {
                    ir_record_raw(IR_ADD_CONST, (unsigned)(st), 0, NULL);
                } else {
                    ir_record_raw(IR_SUB_CONST, (unsigned)(st), 0, NULL);
                }
                emit_incdec_store_local(lc);
            }
        } else if (gv->type == LT_LONG) {
            emit_load_global(gv);
            if (is_inc) {
                ir_emitf("                CLC\n");
                ir_emitf("                ADC     #1\n");
                ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(gname(gv)));
                ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
                ir_emitf("                ADC     #0\n");
                ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(gname(gv)));
            } else {
                ir_emitf("                SEC\n");
                ir_emitf("                SBC     #1\n");
                ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(gname(gv)));
                ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
                ir_emitf("                SBC     #0\n");
                ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp2(gname(gv)));
            }
        } else if (gv->type == LT_INT || gv->type == LT_CHAR) {
            emit_load_global(gv);
            if (is_inc) {
                ir_record_raw(IR_ADD_CONST, (unsigned)(1), 0, NULL);
            } else {
                ir_record_raw(IR_SUB_CONST, (unsigned)(1), 0, NULL);
            }
            if (gv->type == LT_CHAR) {
                emit_store_global_char(gv);
            } else {
                emit_store_global_int(gv);
            }
        } else {
            /* pointer global (G36) — stride precomputed at build */
            emit_load_global(gv);
            if (is_inc) {
                ir_record_raw(IR_ADD_CONST, (unsigned)((int)g_ast[n].val), 0, NULL);
            } else {
                ir_record_raw(IR_SUB_CONST, (unsigned)((int)g_ast[n].val), 0, NULL);
            }
            emit_store_global_int(gv);
        }
        g_last_stmt_returned = 0;
        break;
    }
    case S_SARR_FIELD_IDX: {
        /* arr[i].field[j] = rhs — P3-2.7b FPR-native (mirrors S_AV_STORE):
         * the &arr[i] node carries offset+bank in an FPR, so the old
         * bank re-establish (_fcc_fb+2 / PHB) on _fcc_ptr is gone. */
        Field *f = g_ast[n].sym_f;
        int is_byte = (f->type == LT_CHAR_ARRAY);
        int kd = walk_fpr(g_ast[n].a);              /* &arr[i] */
        emit_fpr_add_const(kd, f->byte_offset);     /* kd = &arr[i].field */
        walk_val(g_ast[n].b);                       /* j -> A */
        if (!is_byte) ir_emitf("                ASL\n");
        emit_fpr_add_a(kd);                         /* kd = &field[j] */
        walk_val(g_ast[n].c);                       /* rhs -> A */
        if (is_byte) emit_fpr_deref_store_byte(kd, 0);
        else         emit_fpr_deref_store_word(kd, 0);
        fpr_drop(kd);
        break;
    }
    case S_FIELD_STORE_AT: {
        Field *f = g_ast[n].sym_f;
        int kd = walk_fpr(g_ast[n].a);              /* &elem */
        if (ISPTR(f->type)) {
            int ks = walk_fpr(g_ast[n].b);          /* int RHS -> bank 0 */
            emit_fpr_deref_store_ptr(kd, ks, f->byte_offset);
            fpr_drop(ks);
        } else if (f->type == LT_LONG || f->type == LT_FLOAT) {
            walk_val(g_ast[n].b);
            if (f->type == LT_FLOAT &&
                (g_expr_type == LT_INT || g_expr_type == LT_CHAR)) {
                emit_itof_rt();
            } else if (g_expr_type == LT_INT || g_expr_type == LT_CHAR) {
                emit_promote_a_to_long();   /* sign/zero-extend int RHS→long */
            }
            emit_assign_conv(f->type);             /* A.7.17: long<->float */
            emit_fpr_deref_store_long(kd, f->byte_offset);
        } else if (f->type == LT_CHAR) {
            walk_val(g_ast[n].b);
            emit_fpr_deref_store_byte(kd, f->byte_offset);
        } else {
            walk_val(g_ast[n].b);
            emit_fpr_deref_store_word(kd, f->byte_offset);
        }
        fpr_drop(kd);
        break;
    }
    case S_FIELD_INCDEC_AT: {
        Field *f = g_ast[n].sym_f;
        int st = (int)g_ast[n].val;
        int kd = walk_fpr(g_ast[n].a);              /* &elem */
        emit_fpr_deref_field(kd, (f->type == LT_CHAR) ? LT_CHAR : LT_INT,
                             f->byte_offset);       /* A = current (offset word) */
        if (g_ast[n].flags & AF_IS_INC) {
            ir_record_raw(IR_ADD_CONST, (unsigned)(st), 0, NULL);
        } else {
            ir_record_raw(IR_SUB_CONST, (unsigned)(st), 0, NULL);
        }
        if (f->type == LT_CHAR) emit_fpr_deref_store_byte(kd, f->byte_offset);
        else                    emit_fpr_deref_store_word(kd, f->byte_offset);
        fpr_drop(kd);
        break;
    }
    case S_FIELD_COMPOUND_AT: {
        Field *f = g_ast[n].sym_f;
        int kd = walk_fpr(g_ast[n].a);              /* &elem */
        emit_fpr_deref_field(kd, (f->type == LT_CHAR) ? LT_CHAR : LT_INT,
                             f->byte_offset);       /* A = current (offset word) */
        emit_push_a();                              /* current @ 1,S */
        walk_val(g_ast[n].b);
        emit_stash_rhs();
        emit_pop_a();                               /* A = current */
        emit_compound_op(g_ast[n].op, f->is_unsigned, LT_INT);
        if (f->type == LT_CHAR) emit_fpr_deref_store_byte(kd, f->byte_offset);
        else                    emit_fpr_deref_store_word(kd, f->byte_offset);
        fpr_drop(kd);
        break;
    }
    case S_ARR_STORE: {
        Local  *lc = g_ast[n].sym_lc;
        Global *gv = g_ast[n].sym_gv;
        LocalType atype = lc ? lc->type : gv->type;
        int is_byte = (atype == LT_CHAR_ARRAY ||
                       atype == LT_CHAR_PTR  ||
                       atype == LT_VOID_PTR);
        int is_ptr_target = (g_ast[n].flags & AF_EL_PTR) != 0;
        int sa_n_dims     = lc ? lc->n_dims     : gv->n_dims;
        int *sa_dims      = lc ? lc->dims       : gv->dims;
        int sa_row_stride = lc ? lc->row_stride : gv->row_stride;
        if (lc) emit_load_base(lc);
        else if (is_ptr_target) emit_load_global(gv);
        else {
            refuse_block_static(gv, "the S_ARR_STORE base");
            ir_emitf("                LDA     #%s\n", gname(gv));
        }
        emit_push_a();                       /* base @ 1,S */
        int cio_snap = ir_cur_n();
        walk_cio(g_ast[n].kid0, g_ast[n].n_kids,
                 sa_n_dims, sa_dims, sa_row_stride);
        ir_emitf("                CLC\n");
        ir_emitf("                ADC     1,S\n");
        ir_record_raw(IR_TAY, 0, 0, NULL);
        ir_record_raw(IR_POP_A, 0, 0, NULL);
        g_s_delta -= 2;
        ir_record_raw(IR_TYA, 0, 0, NULL);   /* A = element address */
        if ((lc ? ISPTR(lc->type) : is_ptr_target) && ir_call_since(cio_snap))
            emit_restage_base_bank(lc, lc ? NULL : gv);
        if (g_ast[n].op != TOK_EOF) {
            TokKind op = g_ast[n].op;
            if (atype == LT_LONG_ARRAY || atype == LT_FLOAT_ARRAY) {
                LocalType et = (atype == LT_FLOAT_ARRAY) ? LT_FLOAT : LT_LONG;
                emit_push_a();                    /* elem addr @ 1,S */
                ir_emitf("                LDA     1,S\n");
                ir_record_raw(IR_TAX, 0, 0, NULL);   /* X = elem addr */
                if (lc) {
                    ir_emitf("                STX     _fcc_ptr\n");
                    emit_stage_frame_bank("_fcc_ptr+2");
                    ir_record_raw(IR_LDA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));   /* low @ +0 */
                    ir_record_raw(IR_PUSH_A, 0, 0, NULL);
                    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
                    ir_emitf("                CLC\n");
                    ir_emitf("                ADC     #2\n");
                    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
                    ir_record_raw(IR_LDA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));   /* high @ +2 */
                    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
                    ir_record_raw(IR_POP_A, 0, 0, NULL);                  /* A = low */
                } else {
                    ir_emitf("                LDA:    $0002,X\n");
                    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
                    ir_emitf("                LDA:    $0000,X\n");
                }
                g_expr_type = et;
                emit_push_long();                 /* current @ 1,S; addr @ 5,S */
                walk_expr_root(g_ast[n].b);            /* RHS -> A */
                LocalType rt = g_ast[g_ast[n].b].type;   /* walker purity */
                if (et == LT_FLOAT) {
                    if (rt == LT_INT || rt == LT_CHAR)
                        emit_int_to_float();
                    else if (rt == LT_LONG)
                        emit_long_to_float();
                } else {
                    if (rt == LT_INT || rt == LT_CHAR)
                        emit_promote_a_to_long();
                }
                if (g_expr_type != LT_FLOAT) g_expr_type = et;
                emit_stash_rhs();
                emit_pop_long();
                if (g_expr_type != LT_FLOAT) g_expr_type = et;
                emit_compound_op(op, 0, et);
                ir_record_raw(IR_TAY, 0, 0, NULL);          /* new low -> Y */
                ir_emitf("                LDA     1,S\n");
                ir_record_raw(IR_TAX, 0, 0, NULL);          /* X = elem addr */
                ir_record_raw(IR_TYA, 0, 0, NULL);
                if (lc) {
                    ir_emitf("                STX     _fcc_ptr\n");
                    ir_record_raw(IR_PUSH_A, 0, 0, NULL);                  /* save low */
                    emit_stage_frame_bank("_fcc_ptr+2");
                    ir_record_raw(IR_POP_A, 0, 0, NULL);                  /* low */
                    ir_record_raw(IR_STA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));   /* low @ +0 */
                    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
                    ir_emitf("                CLC\n");
                    ir_emitf("                ADC     #2\n");
                    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
                    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
                    ir_record_raw(IR_STA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));   /* high @ +2 */
                } else {
                    ir_emitf("                STA:    $0000,X\n");
                    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
                    ir_emitf("                STA:    $0002,X\n");
                }
                ir_record_raw(IR_POP_A, 0, 0, NULL);          /* drop addr */
                g_s_delta -= 2;
                break;
            }
            /* B-3'' (T5-C batch 13): a POINTER-target element address must
             * ride the stack as the FULL 4-byte long-ptr — the deref
             * store-backs read the bank at 3,S and pop 4.  The old 2-byte
             * push made the store-back write through a garbage bank AND
             * pop two words for one, driving the emitter's depth ledger
             * negative (garbage n,S reads downstream — the jsh fgetc
             * boot wedge: `e[1] |= _IOEOF` never signaled EOF). */
            if (is_ptr_target) {
                emit_push_ptr();                  /* addr @ 1,S, bank @ 3,S */
            } else {
                emit_push_a();                    /* addr @ 1,S */
            }
            ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
            if (!lc && !is_ptr_target) {
                emit_m8();
                ir_emitf("                PHB\n");
                ir_record_raw(IR_POP_A, 0, 0, NULL);
                ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
                emit_m16();
            }
            ir_record_raw(IR_LDA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));
            if (is_byte) ir_emitf("                AND     #$00FF\n");
            emit_push_a();                        /* current @ 1,S, addr below */
            walk_expr_root(g_ast[n].b);
            /* A POINTER ELEMENT scales its operand like any other pointer
             * (apple/fgx#154).  `parr[i] += 1' computed the element ADDRESS
             * correctly -- that scaling was never in doubt -- and then added
             * the operand raw, so an `int *' element moved one byte instead of
             * two and a `struct foo *' element one instead of its size. */
            if (ISPTR(DECREF(atype)))
                emit_scale_compound_ptr(DECREF(atype),
                                        lc ? lc->struct_id : gv->struct_id, op);
            emit_stash_rhs();
            emit_pop_a();                          /* A = current */
            emit_compound_op(op, 0, LT_INT);
            if (is_byte) {
                if (is_ptr_target) {
                    emit_deref_store_byte();      /* reads 1,S/3,S; pops 4 */
                    break;
                }
                ir_record_raw(IR_TAY, 0, 0, NULL);
                ir_emitf("                LDA     1,S\n");
                ir_record_raw(IR_TAX, 0, 0, NULL);
                ir_record_raw(IR_TYA, 0, 0, NULL);
                emit_m8();
                if (lc) {
                    ir_emitf("                STX     _fcc_ptr\n");
                    ir_record_raw(IR_PUSH_A, 0, 0, NULL);
                    emit_frame_bank_a();
                    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
                    ir_record_raw(IR_POP_A, 0, 0, NULL);
                    ir_record_raw(IR_STA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));
                } else {
                    ir_emitf("                STA:    $0000,X\n");
                }
                emit_m16();
                ir_record_raw(IR_POP_A, 0, 0, NULL);
                g_s_delta -= 2;
            } else if (is_ptr_target) {
                emit_deref_store();
            } else if (lc) {
                emit_soft_local_store_ptr();
                ir_record_raw(IR_STA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));
                ir_record_raw(IR_POP_A, 0, 0, NULL);
                g_s_delta -= 2;
            } else {
                ir_record_raw(IR_TAY, 0, 0, NULL);
                ir_emitf("                LDA     1,S\n");
                ir_record_raw(IR_TAX, 0, 0, NULL);
                ir_record_raw(IR_TYA, 0, 0, NULL);
                ir_emitf("                STA:    $0000,X\n");
                ir_record_raw(IR_POP_A, 0, 0, NULL);
                g_s_delta -= 2;
            }
            break;
        }
        /* Plain assignment. */
        if (is_ptr_target) {
            emit_push_ptr();        /* 4-byte long-ptr */
        } else {
            emit_push_a();
        }
        walk_expr_root(g_ast[n].b);
        /* A.7.17: the element takes the right operand converted to its own
         * arithmetic type -- a float truncates, long and float cross. */
        if (is_byte)
            emit_assign_conv(LT_CHAR);
        else if (atype == LT_LONG_ARRAY || atype == LT_LONG_PTR)
            emit_assign_conv(LT_LONG);
        else if (atype == LT_FLOAT_ARRAY || atype == LT_FLOAT_PTR)
            emit_assign_conv(LT_FLOAT);
        else if (atype == LT_INT_ARRAY || atype == LT_INT_PTR)
            emit_assign_conv(LT_INT);
        if (is_byte) {
            if (is_ptr_target) {
                emit_deref_store_byte();
            } else if (lc) {
                emit_soft_local_store_ptr();
                emit_m8();
                ir_record_raw(IR_STA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));
                emit_m16();
                ir_record_raw(IR_POP_A, 0, 0, NULL);
                g_s_delta -= 2;
            } else {
                ir_record_raw(IR_TAY, 0, 0, NULL);
                ir_emitf("                LDA     1,S\n");
                ir_record_raw(IR_TAX, 0, 0, NULL);
                ir_record_raw(IR_TYA, 0, 0, NULL);
                emit_m8();
                ir_emitf("                STA:    $0000,X\n");
                emit_m16();
                ir_record_raw(IR_POP_A, 0, 0, NULL);
                g_s_delta -= 2;
            }
        } else {
            if (is_ptr_target) {
                emit_deref_store_dispatch(atype);
            } else if (atype == LT_LONG_ARRAY || atype == LT_FLOAT_ARRAY) {
                LocalType prt = g_ast[g_ast[n].b].type;   /* walker purity */
                if (atype == LT_FLOAT_ARRAY &&
                    (prt == LT_INT || prt == LT_CHAR)) {
                    emit_itof_rt();
                } else if (prt == LT_INT || prt == LT_CHAR) {
                    emit_promote_a_to_long();   /* sign/zero-extend int RHS→long */
                }
                if (lc) {
                    emit_soft_local_store_ptr();
                    ir_record_raw(IR_STA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));
                    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
                    ir_emitf("                CLC\n");
                    ir_emitf("                ADC     #2\n");
                    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_ptr"));
                    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
                    ir_record_raw(IR_STA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));
                } else {
                    ir_record_raw(IR_TAY, 0, 0, NULL);
                    ir_emitf("                LDA     1,S\n");
                    ir_record_raw(IR_TAX, 0, 0, NULL);
                    ir_record_raw(IR_TYA, 0, 0, NULL);
                    ir_emitf("                STA:    $0000,X\n");
                    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
                    ir_emitf("                STA:    $0002,X\n");
                }
                ir_record_raw(IR_POP_A, 0, 0, NULL);
                g_s_delta -= 2;
            } else if (lc) {
                if (is_ptr_array(atype)) {
                    /* LOCAL pointer-element array (ptr_typedef `cp v[4];
                     * v[0] = "Z"`): same 4-byte rule as the global arm below,
                     * but emit_soft_local_store_ptr re-stages _fcc_ptr+2 to
                     * bank 0 (the frame bank) — stash the RHS carrier bank first
                     * and store it at element+2 after the offset word. */
                    ir_record_raw(IR_TAY, 0, 0, NULL);
                    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
                    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
                    ir_record_raw(IR_TYA, 0, 0, NULL);
                    emit_soft_local_store_ptr();
                    ir_record_raw(IR_STA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));
                    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_tmp_b"));
                    ir_emitf("                LDY     #2\n");
                    ir_record_raw(IR_STA_DEREF, 1, 0, (void *)cellp("_fcc_ptr"));
                    ir_record_raw(IR_POP_A, 0, 0, NULL);
                    g_s_delta -= 2;
                } else {
                    emit_soft_local_store_ptr();
                    ir_record_raw(IR_STA_DEREF, 0, 0, (void *)cellp("_fcc_ptr"));
                    ir_record_raw(IR_POP_A, 0, 0, NULL);
                    g_s_delta -= 2;
                }
            } else if (is_ptr_array(atype)) {
                /* Pointer-element array (char*[], int*[], struct*[], fn-ptr
                 * tables): store the FULL 4-byte element — offset word plus
                 * the carrier bank byte walk_expr_root bridged to _fcc_ptr+2.
                 * A 2-byte store leaves the element's bank byte stale, which
                 * single-bank FGX1 masked (reader PHK-recovered its own bank)
                 * but the FGX2 stored-bank convention consumes (ptr_pinc_wide
                 * sum_pp / od_probe4 `vec[0] = &a` oracle regressions). */
                ir_record_raw(IR_TAY, 0, 0, NULL);
                ir_emitf("                LDA     1,S\n");
                ir_record_raw(IR_TAX, 0, 0, NULL);
                ir_record_raw(IR_TYA, 0, 0, NULL);
                ir_emitf("                STA:    $0000,X\n");
                /* #12: the bank test must see the WHOLE 16-bit offset, so it
                 * runs before the SEP below -- in 8-bit mode A holds only the
                 * low byte and a 0x??00 offset would read as null. */
                if (g_expr_type == LT_LONG)
                    emit_long_hi_bank();                /* its high word */
                else if (!is_ptr_type(g_expr_type) && !g_expr_const_int)
                    emit_jsr_rt("_fcc_bank_for_int");   /* A=offset -> A=bank */
                emit_m8();
                /* The bank byte comes from the RHS CARRIER (_fcc_ptr+2) only
                 * when the RHS actually IS a pointer.  An INTEGER RHS -- above
                 * all the NULL terminator `v[n] = 0` that every BSD argv-style
                 * table ends with -- never bridges a carrier, so taking the
                 * bank from _fcc_ptr+2 stored a STALE bank: the element read
                 * back with offset 0 but a garbage bank, so `v[n] != 0` was
                 * TRUE and NULL-terminated walks ran off the end.  Silent, and
                 * invisible on single-bank FGX1.  A null pointer is bank 0. */
                if (is_ptr_type(g_expr_type)) {
                    ir_record_raw(IR_LDA_CELL, 0, 0, (void *)cellp("_fcc_ptr+2"));
                } else if (g_expr_const_int && g_expr_type != LT_LONG) {
                    /* a CONSTANT int here is that NULL terminator: bank 0. */
                    ir_emitf("                LDA     #0\n");
                }
                /* else: A already holds the bank, from the call above. */
                ir_emitf("                STA:    $0002,X\n");
                emit_m16();
                ir_record_raw(IR_POP_A, 0, 0, NULL);
                g_s_delta -= 2;
            } else {
                ir_record_raw(IR_TAY, 0, 0, NULL);
                ir_emitf("                LDA     1,S\n");
                ir_record_raw(IR_TAX, 0, 0, NULL);
                ir_record_raw(IR_TYA, 0, 0, NULL);
                ir_emitf("                STA:    $0000,X\n");
                ir_record_raw(IR_POP_A, 0, 0, NULL);
                g_s_delta -= 2;
            }
        }
        break;
    }
    case S_EMPTY:
        g_last_stmt_returned = 0;
        break;
    case S_EXPR:
        walk_expr_stmt(g_ast[n].a);  /* the value is discarded */
        g_last_stmt_returned = 0;
        break;
    case S_IF: {
        int lab_else_or_end = new_label();
        walk_cond_branch(g_ast[n].a, lab_else_or_end, 0);
        walk_stmt(g_ast[n].b);
        if (g_ast[n].c >= 0) {
            int lab_end = new_label();
            emit_bra_label(lab_end);
            emit_label(lab_else_or_end);
            walk_stmt(g_ast[n].c);
            emit_label(lab_end);
        } else {
            emit_label(lab_else_or_end);
        }
        g_last_stmt_returned = 0;
        break;
    }
    case S_WHILE: {
        g_loop_depth++;                          /* P1.3-inc2: loop-hot mark */
        unsigned loop_id = g_loop_seq++;
        int lab_top = new_label();
        int lab_end = new_label();
        ir_record_op1(IR_LOOP_BEGIN, loop_id);
        emit_label(lab_top);
        emit_safepoint();                        /* P2': A/flags dead here */
        walk_cond_branch(g_ast[n].a, lab_end, 0);
        push_loop_ctx(lab_end, lab_top);         /* M9: continue -> re-test */
        walk_stmt(g_ast[n].b);
        pop_loop_ctx();
        emit_bra_label(lab_top);
        emit_label(lab_end);
        ir_record_op1(IR_LOOP_END, loop_id);
        g_loop_depth--;
        g_last_stmt_returned = 0;
        break;
    }
    case S_DO: {
        g_loop_depth++;
        unsigned loop_id = g_loop_seq++;
        int lab_top  = new_label();
        int lab_cont = new_label();
        int lab_end  = new_label();
        ir_record_op1(IR_LOOP_BEGIN, loop_id);
        emit_label(lab_top);
        emit_safepoint();                        /* P2': body entry, A/flags dead */
        push_loop_ctx(lab_end, lab_cont);
        walk_stmt(g_ast[n].b);                   /* body */
        pop_loop_ctx();
        emit_label(lab_cont);
        walk_cond_branch(g_ast[n].a, lab_end, 0);      /* cond */
        emit_bra_label(lab_top);
        emit_label(lab_end);
        ir_record_op1(IR_LOOP_END, loop_id);
        g_loop_depth--;
        g_last_stmt_returned = 0;
        break;
    }
    case S_FOR: {
        g_loop_depth++;
        int n_init = (int)g_ast[n].val;
        int n_step = (int)g_ast[n].val_hi;
        for (int i2 = 0; i2 < n_init; i2++)
            walk_stmt(g_ast_kids[g_ast[n].kid0 + i2]);
        unsigned loop_id = g_loop_seq++;
        int lab_top  = new_label();
        int lab_cont = new_label();
        int lab_end  = new_label();
        ir_record_op1(IR_LOOP_BEGIN, loop_id);
        emit_label(lab_top);
        emit_safepoint();                        /* P2': A/flags dead here */
        if (g_ast[n].a >= 0)
            walk_cond_branch(g_ast[n].a, lab_end, 0);
        push_loop_ctx(lab_end, lab_cont);
        walk_stmt(g_ast[n].b);                   /* body */
        pop_loop_ctx();
        emit_label(lab_cont);
        for (int i2 = 0; i2 < n_step; i2++)      /* the step, AFTER the body —
                                                  * a tree walk now, no cursor
                                                  * replay */
            walk_stmt(g_ast_kids[g_ast[n].kid0 + n_init + i2]);
        emit_brl_label(lab_top);
        emit_label(lab_end);
        ir_record_op1(IR_LOOP_END, loop_id);
        g_loop_depth--;
        g_last_stmt_returned = 0;
        break;
    }
    case S_SWITCH: {
        walk_val(g_ast[n].a);                         /* switch expr -> A */
        /* A.9.4: the controlling expression "must have integral type".  A
         * float or a pointer compared its low word against the cases. */
        if (g_expr_type == LT_FLOAT || g_expr_type == LT_DOUBLE ||
            ISPTR(g_expr_type) || g_expr_type == LT_STRUCT)
            die(g_ast[n].line, g_ast[n].col,
                "switch expression must have integral type");
        if (g_sw_top >= MAX_SWITCH_NESTING)
            die(g_ast[n].line, g_ast[n].col, "switch nesting too deep (max 4)");
        g_sw_stack[g_sw_top].n_cases       = g_n_sw_cases;
        g_sw_stack[g_sw_top].default_label = g_sw_default_label;
        g_sw_stack[g_sw_top].end_label     = g_sw_end_label;
        memcpy(g_sw_stack[g_sw_top].cases, g_sw_cases,
               sizeof(SwitchCase) * g_n_sw_cases);
        g_sw_top++;
        g_n_sw_cases       = 0;
        g_sw_default_label = -1;
        g_sw_end_label     = new_label();
        /* Label allocation in ENCOUNTER order over the collected case/default
         * kids — reproduces the historical pre-scan numbering exactly. */
        for (int i2 = 0; i2 < g_ast[n].n_kids; i2++) {
            int k = g_ast_kids[g_ast[n].kid0 + i2];
            if (g_ast[k].kind == S_CASE) {
                g_sw_cases[g_n_sw_cases].value    = g_ast[k].val;
                g_sw_cases[g_n_sw_cases].value_hi = g_ast[k].val_hi;
                g_sw_cases[g_n_sw_cases].value2   = g_ast[k].val2;
                g_sw_cases[g_n_sw_cases].value3   = g_ast[k].val3;
                g_sw_cases[g_n_sw_cases].label = new_label();
                g_sw_cases[g_n_sw_cases].line  = g_ast[k].line;
                g_sw_cases[g_n_sw_cases].col   = g_ast[k].col;
                g_ast[k].val_hi = (unsigned)g_n_sw_cases;   /* case idx (value_hi
                                                             * copied out above) */
                g_n_sw_cases++;
            } else if (g_ast[k].kind == S_DEFAULT) {
                g_sw_default_label = new_label();
            }
        }
        if (g_ast[g_ast[n].a].type == LT_LLONG) {
            /* Four words, the top one first: most cases differ there. */
            ir_emitf("                STA     _fcc_long_b_lo\n");
            for (int i2 = 0; i2 < g_n_sw_cases; i2++) {
                int skip = new_label();
                ir_emitf("                LDA     _fcc_q3\n");
                ir_emitf("                CMP     #%u\n",
                        g_sw_cases[i2].value3 & 0xFFFF);
                emit_bcond(IRC_BNE, skip, 1);
                ir_emitf("                LDA     _fcc_q2\n");
                ir_emitf("                CMP     #%u\n",
                        g_sw_cases[i2].value2 & 0xFFFF);
                emit_bcond(IRC_BNE, skip, 1);
                ir_emitf("                LDA     _fcc_long_hi\n");
                ir_emitf("                CMP     #%u\n",
                        g_sw_cases[i2].value_hi & 0xFFFF);
                emit_bcond(IRC_BNE, skip, 1);
                ir_emitf("                LDA     _fcc_long_b_lo\n");
                ir_emitf("                CMP     #%u\n",
                        g_sw_cases[i2].value & 0xFFFF);
                emit_bcond(IRC_BEQ, g_sw_cases[i2].label, 1);
                emit_label(skip);
            }
        } else if (g_ast[g_ast[n].a].type == LT_LONG) {
            /* LONG selector (frotz quetzal's 4-char chunk IDs): the value
             * travels A(lo) + _fcc_long_hi(hi).  Stash the low word in
             * _fcc_long_b_lo (fcc-owned RHS scratch, nothing runs between
             * walk_val above and these compares) so each case reloads
             * from a known place, then compare BOTH words per case. */
            ir_emitf("                STA     _fcc_long_b_lo\n");
            for (int i2 = 0; i2 < g_n_sw_cases; i2++) {
                int skip = new_label();
                ir_emitf("                LDA     _fcc_long_hi\n");
                ir_emitf("                CMP     #%u\n",
                        g_sw_cases[i2].value_hi & 0xFFFF);
                emit_bcond(IRC_BNE, skip, 1);
                ir_emitf("                LDA     _fcc_long_b_lo\n");
                ir_emitf("                CMP     #%u\n",
                        g_sw_cases[i2].value & 0xFFFF);
                emit_bcond(IRC_BEQ, g_sw_cases[i2].label, 1);
                emit_label(skip);
            }
        } else {
        for (int i2 = 0; i2 < g_n_sw_cases; i2++) {
            ir_emitf("                CMP     #%u\n",
                    g_sw_cases[i2].value & 0xFFFF);
            emit_bcond(IRC_BEQ, g_sw_cases[i2].label, 1);   /* BNE *+5 / BRL */
        }
        }
        if (g_sw_default_label >= 0) {
            emit_br(g_sw_default_label, 1);
        } else {
            emit_br(g_sw_end_label, 1);
        }
        int inherited_cont = -1;
        if (g_loop_ctx_top > 0)
            inherited_cont = g_loop_ctx[g_loop_ctx_top - 1].continue_label;
        push_loop_ctx(g_sw_end_label, inherited_cont);
        for (int i2 = 0; i2 < g_ast[n].n_kids; i2++)
            walk_stmt(g_ast_kids[g_ast[n].kid0 + i2]);
        pop_loop_ctx();
        emit_label(g_sw_end_label);
        g_sw_top--;
        g_n_sw_cases       = g_sw_stack[g_sw_top].n_cases;
        g_sw_default_label = g_sw_stack[g_sw_top].default_label;
        g_sw_end_label     = g_sw_stack[g_sw_top].end_label;
        memcpy(g_sw_cases, g_sw_stack[g_sw_top].cases,
               sizeof(SwitchCase) * g_n_sw_cases);
        g_last_stmt_returned = 0;
        break;
    }
    case S_CASE:
        emit_label(g_sw_cases[g_ast[n].val_hi].label);
        break;
    case S_DEFAULT:
        emit_label(g_sw_default_label);
        break;
    case S_ASM: {
        /* T5-C C4b: verbatim block bracketed by peephole-opacity markers. */
        ir_emitf(";__ASM\n");
        for (int k = 0; k < g_ast[n].n_kids; k++) {
            int ln = g_ast_kids[g_ast[n].kid0 + k];
            const char *t = g_ast[ln].name;
            int         tl = g_ast[ln].name_len;
            if (g_libso)
                refuse_block_static_in_asm(t, tl, g_ast[n].line, g_ast[n].col);
            if (tl > 0 && t[0] == '@')
                ir_emitf("%.*s\n", tl, t);           /* @-local label: col 1 */
            else
                ir_emitf("                %.*s\n", tl, t);
        }
        ir_emitf(";__ASM_END\n");
        break;
    }
    case S_BLOCK:
        for (int i2 = 0; i2 < g_ast[n].n_kids; i2++)
            walk_stmt(g_ast_kids[g_ast[n].kid0 + i2]);
        break;
    case S_DECL:
        for (int i2 = 0; i2 < g_ast[n].n_kids; i2++)
            walk_stmt(g_ast_kids[g_ast[n].kid0 + i2]);
        g_last_stmt_returned = 0;
        break;
    case S_DECL_ARRINIT: {
        Local *lc = g_ast[n].sym_lc;
        int es = (int)g_ast[n].val;
        int n_elems = (int)g_ast[n].val_hi;
        int is_ptr = is_ptr_array(lc->type);    /* P3-2.7b: far elements */
        int idx = 0;
        if (lc->type == LT_LLONG_ARRAY || lc->type == LT_DOUBLE_ARRAY) {
            /* Eight bytes an element, through the array's address; the
             * elements past the initializers are zeroed (A.8.7), and a zero
             * long double is all-zero bits. */
            int k = fpr_addr_sym(lc, NULL);
            for (; idx < n_elems; idx++) {
                if (idx < g_ast[n].n_kids) {
                    walk_val(g_ast_kids[g_ast[n].kid0 + idx]);
                    emit_to_quad(DECREF(lc->type));
                } else {
                    ir_emitf("                LDA     #0\n");
                    ir_emitf("                STA     _fcc_q3\n");
                    ir_emitf("                STA     _fcc_q2\n");
                    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp("_fcc_long_hi"));
                }
                emit_fpr_deref_store_llong(k, idx * 8);
            }
            fpr_drop(k);
            lc->n_stores++;
            break;
        }
        for (; idx < g_ast[n].n_kids; idx++) {
            int kid = g_ast_kids[g_ast[n].kid0 + idx];
            if (is_ptr) {
                /* 4-byte far element (offset+bank) straight from the
                 * FPR — the pre-2.7b lowering stored a 2-byte offset
                 * with the bank DROPPED (and es=2 mis-strode reads). */
                int k = walk_fpr(kid);
                emit_fpr_store_local_4(lc, idx * es, k);
                fpr_drop(k);
                continue;
            }
            walk_expr_root(kid);
            emit_store_local_elem(lc, idx * es, es, g_expr_type);
        }
        for (; idx < n_elems; idx++) {          /* zero-fill rest */
            ir_emitf("                LDA     #0\n");
            g_expr_type = LT_INT;
            emit_store_local_elem(lc, idx * es, es, LT_INT);
        }
        break;
    }
    case S_DECL_STRUCTINIT: {
        Local *lc = g_ast[n].sym_lc;
        Struct *st = &g_structs[lc->struct_id];
        int fi = 0;
        for (; fi < g_ast[n].n_kids; fi++) {
            int kid = g_ast_kids[g_ast[n].kid0 + fi];
            Field *f = &st->fields[fi];
            if (ISPTR(f->type) || f->type == LT_FN_PTR) {
                /* P3-2.7b: ptr / fn-ptr field straight from the FPR
                 * (was carrier-fed via fpr_out + _fcc_ptr+2). */
                int k = walk_fpr(kid);
                emit_fpr_store_local_4(lc, f->byte_offset, k);
                fpr_drop(k);
                continue;
            }
            walk_expr_root(kid);
            emit_store_local_field(lc, f);
        }
        for (; fi < st->n_fields; fi++) {       /* zero-fill scalar fields */
            Field *f = &st->fields[fi];
            if (f->type == LT_STRUCT || f->type == LT_CHAR_ARRAY ||
                f->type == LT_INT_ARRAY || f->type == LT_LONG_ARRAY ||
                f->type == LT_LLONG_ARRAY || f->type == LT_DOUBLE_ARRAY ||
                f->type == LT_STRUCT_ARRAY)
                continue;
            ir_emitf("                LDA     #0\n");
            g_expr_type = LT_INT;
            if (f->type == LT_DOUBLE) {          /* +0.0 is all-zero bits */
                ir_emitf("                STA     _fcc_q3\n");
                ir_emitf("                STA     _fcc_q2\n");
                ir_emitf("                STA     _fcc_long_hi\n");
                g_expr_type = LT_DOUBLE;
            }
            emit_store_local_field(lc, f);
        }
        break;
    }
    default:
        /* Expression-kind node used as a statement (store/call arms):
         * delegate to the expression walker; the value is discarded, so
         * a pointer result is dropped, never carrier-bridged. */
        if (g_ast[n].kind < S_LABEL) {
            walk_expr_stmt(n);
            g_last_stmt_returned = 0;
            break;
        }
        die(g_ast[n].line, g_ast[n].col,
            "fcc-ast: statement walker: unhandled node kind");
    }
}

int
parse_fn_ptr_declarator(TypeSpec base_t,
                        const char **out_name_ptr, int *out_name_len,
                        int *out_sig_id)
{
    g_fnptr_decl_arr = 0;
    if (g_cur.kind != TOK_LPAREN && g_cur.kind != TOK_STAR) return 0;

    /* Snapshot lexer state. */
    LexPeek save_pk;
    lex_peek_save(&save_pk);

    /* P3-2: pointer-returning fn-ptr — `T *(*name)(...)`.  Consume the
     * return-type stars before requiring `(*`; the bail-restore below
     * keeps ordinary `T *name` / `T **name` declarators (and the paren'd
     * `T *(name)()` form) on their existing paths.  Struct-by-value
     * return stays deferred; struct POINTER return works (base+PTR). */
    int ret_stars = 0;
    while (g_cur.kind == TOK_STAR) { ret_stars++; next_tok(); }
    if (g_cur.kind != TOK_LPAREN) {
        lex_peek_restore(&save_pk);
        return 0;
    }

    next_tok();                            /* past first '(' */
    if (g_cur.kind != TOK_STAR) {
        lex_peek_restore(&save_pk);
        return 0;
    }
    next_tok();                            /* past '*' */
    /* Name is OPTIONAL: `(*name)(...)` OR the abstract `(*)(...)`.  The abstract
     * form appears in prototype externs, e.g. `extern int f(int (*)(int), int)`.
     * fcc previously required a name here and rejected such a declaration with
     * "expected parameter name"; a prototype only needs the type. */
    const char *id_ptr = "";
    int id_len = 0;
    if (g_cur.kind == TOK_IDENT) {
        id_ptr = g_cur.id_ptr;
        id_len = g_cur.id_len;
        next_tok();                        /* past IDENT */
    }
    /* B-7: array of fn-ptrs — `T (*name[N])(args)` / `(*name[])(args)`. */
    if (g_cur.kind == TOK_LBRACKET) {
        next_tok();                        /* past '[' */
        if (g_cur.kind == TOK_RBRACKET) {
            g_fnptr_decl_arr = -1;         /* [] — size from init list */
        } else {
            long an = parse_const_bin(0);
            if (an <= 0)
                die(g_cur.line, g_cur.col,
                    "fn-ptr array size must be a positive integer constant");
            g_fnptr_decl_arr = (int)an;
        }
        if (g_cur.kind != TOK_RBRACKET) {
            lex_peek_restore(&save_pk);
            return 0;
        }
        next_tok();                        /* past ']' */
    }
    if (g_cur.kind != TOK_RPAREN) {
        lex_peek_restore(&save_pk);
        return 0;
    }
    next_tok();                            /* past ')' */
    if (g_cur.kind != TOK_LPAREN) {
        lex_peek_restore(&save_pk);
        return 0;
    }
    next_tok();                            /* past '(' (start of params) */

    /* Parse the param list into a fresh signature.  Params can be int,
     * char, void, pointer types, struct (by-value) — same as a regular
     * function's params, but unnamed.  Permit optional unnamed IDENT
     * for K&R-style prototypes that name the params. */
    LocalType params[MAX_LOCALS];
    int param_struct_ids[MAX_LOCALS];
    int n_params = 0;
    int is_variadic = 0;
    if (g_cur.kind != TOK_RPAREN) {
        for (;;) {
            if (g_cur.kind == TOK_ELLIPSIS) {
                is_variadic = 1;
                next_tok();
                break;
            }
            TypeSpec pt = parse_type_spec();
            int is_ptr = 0;
            while (g_cur.kind == TOK_STAR) { is_ptr = 1; next_tok(); }
            /* ANSI (void): a lone bare `void` closing the list declares
             * zero parameters -- `void (*fp)(void)`.  Only this exact
             * shape; `void` mixed with params still dies in
             * type_for_decl below. */
            if (pt.base == TW_VOID && !is_ptr && n_params == 0
                && g_cur.kind == TOK_RPAREN)
                break;
            /* Optional unnamed-param IDENT. */
            if (g_cur.kind == TOK_IDENT) next_tok();
            if (n_params >= MAX_LOCALS)
                die(g_cur.line, g_cur.col, "too many fn-ptr params");
            params[n_params] = type_for_decl(pt, is_ptr, 0);
            param_struct_ids[n_params] = pt.struct_id;
            n_params++;
            if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
            break;
        }
    }
    if (g_cur.kind != TOK_RPAREN)
        die(g_cur.line, g_cur.col, "expected ')' after fn-ptr param list");
    next_tok();                            /* past closing ')' */

    *out_name_ptr = id_ptr;
    *out_name_len = id_len;
    /* Return type: base + ret_stars PTR groups.  type_for_decl only for
     * the starred case — a bare `void (*fp)()` return stays TW_VOID (the
     * historical sig encoding; type_for_decl would reject bare void). */
    *out_sig_id   = fn_sig_intern(ret_stars ? type_for_decl(base_t, ret_stars, 0)
                                            : base_t.base,
                                   n_params, params,
                                   param_struct_ids, is_variadic,
                                   ret_stars ? 0 : base_t.is_unsigned);
    return 1;
}

/* One fn-ptr init-declarator: declare the local and take its optional
 * initializer.  Factored out at UFS 2.1 (apple/fgx#284) because a declaration
 * list may MIX shapes -- `int i, n, (*fp)(), nif;' -- so both the fn-ptr loop
 * and the ordinary declarator loop need this body.  g_fnptr_decl_arr is the
 * array count parse_fn_ptr_declarator leaves behind. */
static void
declare_fnptr_local(const char *name_ptr, int name_len, int fn_sig_id,
                    int *tmp, int *cnt)
{
    /* queue 5: `T (*arr[N])(...)` LOCAL fn-ptr array -- same ARY<PTR<FTN>>
     * shape as the global form (B-7). */
    if (g_fnptr_decl_arr > 0) {
        locals_declare(name_ptr, name_len, LK_LOCAL,
                       INCREF(LT_FN_PTR, DERIV_ARY),
                       g_fnptr_decl_arr, g_cur.line, g_cur.col);
    } else if (g_fnptr_decl_arr < 0) {
        die(g_cur.line, g_cur.col,
            "sizeless fn-ptr local array needs an explicit size");
    } else {
        locals_declare(name_ptr, name_len, LK_LOCAL,
                       LT_FN_PTR, 1, g_cur.line, g_cur.col);
    }
    g_locals[g_n_locals - 1].fn_sig_id = fn_sig_id;
    if (g_cur.kind == TOK_EQ) {
        next_tok();
        Local *lc = &g_locals[g_n_locals - 1];
        int rhs = ast_build_assign();
        int in = ast_new(N_STORE_VAR, g_cur.line, g_cur.col);
        g_ast[in].sym_lc = lc;
        g_ast[in].a = rhs;
        ast_copy_desc(in, rhs);
        ast_store_conv(in, g_ast[in].sym_lc, g_ast[in].sym_gv);
        if (*cnt >= 64) die(g_cur.line, g_cur.col, "too many declarators");
        tmp[(*cnt)++] = in;
    }
}

static int
build_decl(TypeSpec t)
{
    int dline = g_cur.line, dcol = g_cur.col;
    int tmp[64];
    int cnt = 0;
    /* type-spec already consumed by caller. */
    /* M18: function-pointer local decl: T (*name)(params); */
    {
        const char *fn_name_ptr;
        int         fn_name_len;
        int         fn_sig_id;
        /* A LIST MAY MIX SHAPES, so this consumes fn-ptr init-declarators
         * while they keep coming and hands anything else to the ordinary
         * declarator loop below (apple/fgx#284).  It used to demand that every
         * declarator after the first also be a fn-ptr -- "expected fn-ptr
         * declarator after ',' in fn-ptr decl" -- which made `int (*fp)(), a;'
         * an error.
         *
         * K&R A.8 gives the list as `init-declarator-list: init-declarator |
         * init-declarator-list , init-declarator', with `init-declarator:
         * declarator | declarator = initializer'.  Each element is a whole
         * declarator in its own right; only the declaration-specifiers are
         * shared, so nothing requires the elements to have the same shape.
         * parse_fn_ptr_declarator restores the lexer when it declines, so
         * trying it per element costs a peek and no state. */
        while (parse_fn_ptr_declarator(t, &fn_name_ptr, &fn_name_len,
                                       &fn_sig_id)) {
            declare_fnptr_local(fn_name_ptr, fn_name_len, fn_sig_id, tmp, &cnt);
            if (g_cur.kind != TOK_COMMA) {
                expect(TOK_SEMI, "';' after fn-ptr local decl");
                goto make_decl_node;
            }
            next_tok();     /* consume ',' and try the next init-declarator */
        }
    }
    /* M18: fn-pointer typedef-resolved local: cb_t fp;  queue 5: also
     * cb_t arr[N]; (local fn-ptr ARRAY — ARY<PTR<FTN>>, 4B/elem, same
     * shape as the global form). */
    if (t.base == LT_FN_PTR) {
        if (g_cur.kind != TOK_IDENT)
            die(g_cur.line, g_cur.col, "expected name after fn-ptr typedef");
        const char *name_ptr = g_cur.id_ptr;
        int         name_len = g_cur.id_len;
        int         line = g_cur.line, col = g_cur.col;
        int         fp_elems = 1;
        next_tok();
        if (g_cur.kind == TOK_LBRACKET) {
            next_tok();
            long asz = parse_const_bin(0);
            if (asz <= 0)
                die(g_cur.line, g_cur.col,
                    "array size must be a positive integer constant");
            fp_elems = (int)asz;
            expect(TOK_RBRACKET, "']'");
        }
        locals_declare(name_ptr, name_len, LK_LOCAL,
                       (fp_elems == 1) ? LT_FN_PTR
                                       : INCREF(LT_FN_PTR, DERIV_ARY),
                       fp_elems, line, col);
        g_locals[g_n_locals - 1].fn_sig_id = t.struct_id;
        if (g_cur.kind == TOK_EQ) {
            next_tok();
            Local *lc = &g_locals[g_n_locals - 1];
            int rhs = ast_build_assign();
            int in = ast_new(N_STORE_VAR, line, col);
            g_ast[in].sym_lc = lc;
            g_ast[in].a = rhs;
            ast_copy_desc(in, rhs);
            ast_store_conv(in, g_ast[in].sym_lc, g_ast[in].sym_gv);
            tmp[cnt++] = in;
        }
        expect(TOK_SEMI, "';' after fn-ptr local decl");
        goto make_decl_node;
    }
    for (;;) {
        /* declarator-refactor Increment 3: the local's `*name[dims...]`
         * declarator (pointer chain + name + multidim array) flows through the
         * ONE parse_declarator.  It returns the merged tword (== the old
         * type_for_decl(t, stars, is_array)), the dims, and two shape flags —
         *   is_func_proto: a `(` follows the name (G27 in-body prototype), with
         *     params LEFT unconsumed and d.type == the return type; handled here.
         *   sizeless: an implicit outer `[]`; locals need a concrete size, so we
         *     PRESCAN the initializer (as before) to fill dims[0].
         * Storage sizing / initializers below are unchanged (byte-identical). */
        /* A fn-ptr element arriving mid-list, the mirror of the loop above:
         * `int a, (*fp)();'.  Same K&R A.8 reasoning -- the elements of an
         * init-declarator-list are independent declarators -- and the same
         * costless probe, since parse_fn_ptr_declarator restores the lexer
         * when the element is not one. */
        {
            const char *fp_name_ptr;
            int         fp_name_len;
            int         fp_sig_id;
            if (parse_fn_ptr_declarator(t, &fp_name_ptr, &fp_name_len,
                                        &fp_sig_id)) {
                declare_fnptr_local(fp_name_ptr, fp_name_len, fp_sig_id,
                                    tmp, &cnt);
                if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
                expect(TOK_SEMI, "';' after local decl");
                goto make_decl_node;
            }
        }
        Declarator d = parse_declarator(t, /*allow_abstract=*/0);
        int line = d.name_line, col = d.name_col;
        const char *name_ptr = d.name;
        int         name_len = d.name_len;

        /* G27: function declarator `T *name(...)` inside a declaration.  g_cur
         * is AT the '('; d.type is the return type (stars==0 -> base.base, else
         * type_for_decl(t, stars, 0)) — byte-identical to the old `ret`. */
        if (d.is_func_proto) {
            LocalType ret = d.type;
            next_tok();                 /* consume '(' */
            int pdepth = 1;
            while (pdepth > 0 && g_cur.kind != TOK_EOF) {
                if (g_cur.kind == TOK_LPAREN)      pdepth++;
                else if (g_cur.kind == TOK_RPAREN) pdepth--;
                next_tok();
            }
            if (funcs_lookup(name_ptr, name_len) < 0) {
                int fi = funcs_declare(name_ptr, name_len, 0, line, col);
                g_funcs[fi].return_type = ret;
                g_funcs[fi].ret_unsigned = ISPTR(d.type) ? 0 : t.is_unsigned; /* A-1 */
                g_funcs[fi].is_variadic = 1;   /* K&R () = unspecified args */
                g_funcs[fi].is_variadic_expl = 1;
                g_funcs[fi].is_extern   = 1;   /* prototype only */
                /* G42 RETIRED (Increment 4): the current function is tracked
                 * by g_cur_fn_idx, so a mid-body prototype may append freely —
                 * no slot swap, Func identity is stable. */
            }
            if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
            expect(TOK_SEMI, "';'");
            goto make_decl_node;
        }

        /* Block-scope `extern T name;` / `extern T name[];` -- tcsh sh.lex's
         * `extern Char InputBuf[];` inside bgetc().  K&R A.8.1: an extern
         * declaration at block scope DECLARES a reference to the file-scope
         * object; it does not DEFINE a local.  So allocate no local slot and
         * resolve the name to the global -- which is also why a sizeless array
         * is legal here (nothing is being allocated, so nothing needs a size)
         * where a true local `T a[];` still rightly needs an initializer. */
        if (t.is_extern) {
            if (globals_lookup(name_ptr, name_len) == NULL)
                globals_declare(name_ptr, name_len, d.type,
                                (d.n_dims > 0 && d.dims[0] > 0) ? d.dims[0] : 1,
                                line, col, /*is_extern_decl=*/1);
            if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
            expect(TOK_SEMI, "';'");
            goto make_decl_node;
        }

        /* G38: a bare `void name` VARIABLE is invalid (only `void *p`).  The
         * `void *`/`void[]` forms already died inside type_for_decl. */
        if (d.type == LT_VOID)
            die(line, col, "void declarator must be 'void *p'");

        int is_array = (d.n_dims > 0);
        int n_elems  = 1;
        /* queue 6 (D-1): sizeless 1-D `[] = "str"` / `[] = {list}` — infer the
         * size by PRESCANNING the initializer through the token vector
         * (lex_peek is a pure cursor rewind).  parse_declarator left g_cur at
         * the token after `]` (the `=`). */
        if (d.sizeless) {
            if (d.n_dims > 1)
                die(line, col, "sizeless multi-dim local array not supported");
            LexPeek szpk;
            long inferred = 0;
            if (g_cur.kind != TOK_EQ)
                die(g_cur.line, g_cur.col,
                    "sizeless local array needs an initializer");
            lex_peek_save(&szpk);
            next_tok();                        /* past '=' */
            if (g_cur.kind == TOK_STR_LIT) {
                inferred = g_cur.str_len + 1;  /* chars + NUL */
            } else if (g_cur.kind == TOK_LBRACE) {
                int depth = 1, sawitem = 0;
                next_tok();
                while (depth > 0) {
                    if (g_cur.kind == TOK_EOF)
                        die(g_cur.line, g_cur.col,
                            "unterminated initializer list");
                    if (g_cur.kind == TOK_LBRACE) depth++;
                    else if (g_cur.kind == TOK_RBRACE) { depth--; }
                    else if (g_cur.kind == TOK_COMMA && depth == 1) {
                        if (sawitem) { inferred++; sawitem = 0; }
                    } else if (depth >= 1) sawitem = 1;
                    next_tok();
                }
                if (sawitem) inferred++;
            } else {
                die(g_cur.line, g_cur.col,
                    "sizeless local array needs a string or brace initializer");
            }
            lex_peek_restore(&szpk);           /* back to the '=' */
            if (inferred <= 0)
                die(g_cur.line, g_cur.col, "empty array initializer");
            d.dims[0] = (int)inferred;
        }
        if (is_array) {
            n_elems = 1;
            for (int di = 0; di < d.n_dims; di++) n_elems *= d.dims[di];
        }
        LocalType decl_type = d.type;

        int slot_count = 1;
        if (is_ptr_array(decl_type)) {
            slot_count = 2 * n_elems;         /* 4-byte far-ptr elements */
        } else if (decl_type == LT_CHAR_ARRAY) {
            slot_count = (n_elems + 1) / 2;   /* byte-packed */
        } else if (decl_type == LT_INT_ARRAY) {
            slot_count = n_elems;
        } else if (decl_type == LT_LONG_ARRAY) {
            slot_count = 2 * n_elems;
        } else if (decl_type == LT_FLOAT_ARRAY) {
            slot_count = 2 * n_elems;
        } else if (decl_type == LT_LLONG_ARRAY ||
                   decl_type == LT_DOUBLE_ARRAY) {
            slot_count = 4 * n_elems;
        } else if (decl_type == LT_STRUCT) {
            if (g_structs[t.struct_id].is_forward)
                die(line, col, "by-value struct decl requires complete type");
            int sz = (g_structs[t.struct_id].total_size + 1) & ~1;
            slot_count = sz / 2;
        } else if (decl_type == LT_STRUCT_ARRAY) {
            if (d.n_dims > 1)
                die(line, col, "multi-dim arrays of struct not supported (M19)");
            if (g_structs[t.struct_id].is_forward)
                die(line, col, "array of incomplete struct not allowed");
            int sz = (g_structs[t.struct_id].total_size + 1) & ~1;
            slot_count = (sz * n_elems) / 2;
        } else if (is_array) {
            die(line, col, "internal: no frame size for this array type");
        }

        locals_declare(name_ptr, name_len, LK_LOCAL, decl_type,
                       slot_count, line, col);
        Local *new_lc = &g_locals[g_n_locals - 1];
        /* G52 (locals): struct base of ANY derivation (struct, struct*,
         * struct**, struct[]) keeps its struct id — `*pp + n` on a
         * struct** local needs it for the pointer-arith stride (H1 ls). */
        new_lc->struct_id = (BTYPE(decl_type) == BT_STRUCT)
                            ? t.struct_id : -1;
        new_lc->is_unsigned = t.is_unsigned;   /* A-1 */
        new_lc->byte_size = slot_count * 2;
        if (is_array)
            new_lc->array_bytes = (decl_type == LT_STRUCT_ARRAY)
                ? ((g_structs[t.struct_id].total_size + 1) & ~1) * n_elems
                : arr_row_elem_size(decl_type) * n_elems;
        if (d.n_dims > 1) {
            new_lc->n_dims = d.n_dims;
            for (int di = 0; di < d.n_dims; di++) new_lc->dims[di] = d.dims[di];
            int es = arr_row_elem_size(decl_type);
            int inner = 1;
            for (int di = 1; di < d.n_dims; di++) inner *= d.dims[di];
            new_lc->row_stride = es * inner;
        }

        if (g_cur.kind == TOK_EQ) {
            next_tok();
            Local *lc = locals_lookup(name_ptr, name_len);
            if (is_array && g_cur.kind == TOK_LBRACE) {
                if (n_elems > 64)
                    die(line, col,
                        "local array initializer too large (max 64 elems); init at runtime");
                int es = (decl_type == LT_CHAR_ARRAY) ? 1 :
                         (decl_type == LT_LLONG_ARRAY ||
                          decl_type == LT_DOUBLE_ARRAY) ? 8 :
                         (decl_type == LT_LONG_ARRAY) ? 4 :
                         is_ptr_array(decl_type)      ? 4 : 2;
                next_tok();   /* '{' */
                int etmp[64];
                int ecnt = 0;
                while (g_cur.kind != TOK_RBRACE) {
                    if (ecnt >= n_elems)
                        die(g_cur.line, g_cur.col, "too many array initializers");
                    etmp[ecnt++] = ast_build_assign();
                    if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
                    break;
                }
                expect(TOK_RBRACE, "'}'");
                if (g_n_ast_kids + ecnt > MAX_AST_KIDS)
                    die(line, col, "array-init kid pool overflow");
                int kid0 = g_n_ast_kids;
                for (int i = 0; i < ecnt; i++) g_ast_kids[g_n_ast_kids++] = etmp[i];
                int in = ast_new(S_DECL_ARRINIT, line, col);
                g_ast[in].sym_lc = new_lc;
                g_ast[in].kid0 = kid0; g_ast[in].n_kids = ecnt;
                g_ast[in].val = (unsigned)es;
                g_ast[in].val_hi = (unsigned)n_elems;
                if (cnt >= 64) die(line, col, "too many declarators");
                tmp[cnt++] = in;
            } else if (decl_type == LT_CHAR_ARRAY &&
                       g_cur.kind == TOK_STR_LIT) {
                /* queue 6 (D-1): char s[N] = "str" — per-char stores +
                 * zero-fill via the element-init walker.  (Previously
                 * fell into the SCALAR store arm, silently storing the
                 * string's ADDRESS into the array.) */
                int sl = g_cur.str_len;
                const char *sp = g_cur.str_ptr;
                if (sl + 1 > n_elems)
                    die(line, col, "string initializer longer than array");
                if (n_elems > 64)
                    die(line, col,
                        "local array initializer too large (max 64 elems); init at runtime");
                int etmp[65];
                int ecnt = 0;
                for (int i = 0; i < sl; i++) {
                    int ln = ast_new(N_LIT_INT, line, col);
                    g_ast[ln].val = (unsigned)(unsigned char)sp[i];
                    etmp[ecnt++] = ln;
                }
                {   /* explicit NUL; the walker zero-fills the rest */
                    int ln = ast_new(N_LIT_INT, line, col);
                    g_ast[ln].val = 0;
                    etmp[ecnt++] = ln;
                }
                next_tok();   /* past the string literal */
                if (g_n_ast_kids + ecnt > MAX_AST_KIDS)
                    die(line, col, "array-init kid pool overflow");
                int kid0 = g_n_ast_kids;
                for (int i = 0; i < ecnt; i++)
                    g_ast_kids[g_n_ast_kids++] = etmp[i];
                int in = ast_new(S_DECL_ARRINIT, line, col);
                g_ast[in].sym_lc = new_lc;
                g_ast[in].kid0 = kid0; g_ast[in].n_kids = ecnt;
                g_ast[in].val = 1;                 /* es = 1 byte */
                g_ast[in].val_hi = (unsigned)n_elems;
                if (cnt >= 64) die(line, col, "too many declarators");
                tmp[cnt++] = in;
            } else if (decl_type == LT_STRUCT && g_cur.kind == TOK_LBRACE) {
                Struct *st = &g_structs[new_lc->struct_id];
                next_tok();   /* '{' */
                int etmp[64];
                int ecnt = 0;
                while (g_cur.kind != TOK_RBRACE) {
                    if (ecnt >= st->n_fields)
                        die(g_cur.line, g_cur.col, "too many struct initializers");
                    Field *f = &st->fields[ecnt];
                    if (f->type == LT_STRUCT || f->type == LT_CHAR_ARRAY ||
                        f->type == LT_INT_ARRAY || f->type == LT_LONG_ARRAY ||
                        f->type == LT_STRUCT_ARRAY)
                        die(g_cur.line, g_cur.col,
                            "nested aggregate in local struct initializer not supported");
                    if (ecnt >= 64)
                        die(g_cur.line, g_cur.col, "too many struct initializers");
                    etmp[ecnt++] = ast_build_assign();
                    if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
                    break;
                }
                expect(TOK_RBRACE, "'}'");
                if (g_n_ast_kids + ecnt > MAX_AST_KIDS)
                    die(line, col, "struct-init kid pool overflow");
                int kid0 = g_n_ast_kids;
                for (int i = 0; i < ecnt; i++) g_ast_kids[g_n_ast_kids++] = etmp[i];
                int in = ast_new(S_DECL_STRUCTINIT, line, col);
                g_ast[in].sym_lc = new_lc;
                g_ast[in].kid0 = kid0; g_ast[in].n_kids = ecnt;
                if (cnt >= 64) die(line, col, "too many declarators");
                tmp[cnt++] = in;
            } else {
                /* A pointer or arithmetic object's initializer is "a single
                 * expression, perhaps in braces" (K&R A8.7). */
                int braced = (g_cur.kind == TOK_LBRACE);
                if (braced)
                    next_tok();
                int rhs = ast_build_assign();
                if (braced) {
                    if (g_cur.kind == TOK_COMMA)
                        next_tok();
                    expect(TOK_RBRACE, "'}' closing a braced scalar initializer");
                }
                int in = ast_new(N_STORE_VAR, line, col);
                g_ast[in].sym_lc = lc;
                g_ast[in].a = rhs;
                ast_copy_desc(in, rhs);
            ast_store_conv(in, g_ast[in].sym_lc, g_ast[in].sym_gv);
                if (cnt >= 64) die(line, col, "too many declarators");
                tmp[cnt++] = in;
            }
        }
        if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
        break;
    }
    expect(TOK_SEMI, "';'");
make_decl_node:
    {
        if (g_n_ast_kids + cnt > MAX_AST_KIDS)
            die(dline, dcol, "decl kid pool overflow");
        int kid0 = g_n_ast_kids;
        for (int i = 0; i < cnt; i++) g_ast_kids[g_n_ast_kids++] = tmp[i];
        int n = ast_new(S_DECL, dline, dcol);
        g_ast[n].kid0 = kid0; g_ast[n].n_kids = cnt;
        return n;
    }
}

static int
build_for_init_or_step(void)
{
    /* G37: a non-assignment-form init/step is a general expression whose
     * value is discarded (void calls allowed — the void-in-expression check
     * runs at BUILD time inside the call builder, so set the permission
     * around the build). */
    {
        LexPeek saved_pk;
        lex_peek_save(&saved_pk);
        int    is_assign_form = 0;
        /* --libso: a block static goes to the expression layer's walker. */
        if (g_cur.kind == TOK_IDENT &&
            !block_static_named(g_cur.id_ptr, g_cur.id_len)) {
            next_tok();
            if (g_cur.kind == TOK_PLUSPLUS || g_cur.kind == TOK_MINUSMINUS ||
                is_compound_op(g_cur.kind) || g_cur.kind == TOK_EQ)
                is_assign_form = 1;
        }
        lex_peek_restore(&saved_pk);
        if (!is_assign_form) {
            int saved_void_ok = g_void_ctx_ok;
            g_void_ctx_ok = 1;
            int e = ast_build_assign();
            g_void_ctx_ok = saved_void_ok;
            int n = ast_new(S_EXPR, g_cur.line, g_cur.col);
            g_ast[n].a = e;
            return n;
        }
    }
    if (g_cur.kind != TOK_IDENT)
        die(g_cur.line, g_cur.col,
            "'for' init/step must be 'IDENT = expr' or 'IDENT ++/--'");
    const char *name_ptr = g_cur.id_ptr;
    int         name_len = g_cur.id_len;
    int         line = g_cur.line, col = g_cur.col;
    next_tok();
    Local  *lc = locals_lookup(name_ptr, name_len);
    Global *gv = (lc == NULL) ? globals_lookup(name_ptr, name_len) : NULL;
    if (lc == NULL && gv == NULL)
        die(line, col, "undeclared");
    require_assignable(lc ? lc->type : gv->type, g_cur.kind);
    if (g_cur.kind == TOK_PLUSPLUS || g_cur.kind == TOK_MINUSMINUS) {
        int is_inc = (g_cur.kind == TOK_PLUSPLUS);
        next_tok();
        if (gv != NULL && gv->type != LT_LONG && gv->type != LT_INT &&
            gv->type != LT_CHAR && gv->type != LT_FLOAT &&
            !IS_QUAD(gv->type) &&
            !(ISPTR(gv->type) && gv->type != LT_FN_PTR))
            die(line, col,
                "for-step ++/-- on global: only int/char/long/long long/"
                "double/float/pointer supported");
        int st = 1;
        if (lc != NULL && lc->type != LT_INT && lc->type != LT_CHAR) {
            st = elem_size_for(lc->type, lc->struct_id);
            if (st == 0) st = 1;
        } else if (gv != NULL && ISPTR(gv->type)) {   /* global ptr for-step: sizeof(*g) */
            st = elem_size_for(gv->type, gv->struct_id);
            if (st == 0) st = 1;
        }
        int n = ast_new(S_PREINC_STMT, line, col);
        g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
        g_ast[n].val = (unsigned)st;
        g_ast[n].flags = is_inc ? AF_IS_INC : 0;
        return n;
    }
    /* G26: compound-assign clause `IDENT op= expr`. */
    if (is_compound_op(g_cur.kind)) {
        TokKind op = g_cur.kind;
        next_tok();
        int rhs = ast_build_assign();
        int n = ast_new(N_COMPOUND_VAR, line, col);
        g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
        g_ast[n].op = op; g_ast[n].a = rhs;
        g_ast[n].type = lc ? lc->type : gv->type;
        g_ast[n].is_unsigned = lc ? lc->is_unsigned : gv->is_unsigned;
        return n;
    }
    if (g_cur.kind != TOK_EQ)
        die(line, col,
            "'for' init/step must be 'IDENT = expr', 'IDENT op= expr', or 'IDENT ++/--'");
    next_tok();
    int rhs = ast_build_assign();
    if ((lc ? lc->type : gv->type) == LT_STRUCT) {
        /* a clause is walked as a statement; the copy is an expression */
        int n = ast_new(S_EXPR, line, col);
        g_ast[n].a = build_struct_var_store(lc, gv, rhs, line, col);
        return n;
    }
    int n = ast_new(N_STORE_VAR, line, col);
    g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
    g_ast[n].a = rhs;
    ast_copy_desc(n, rhs);
            ast_store_conv(n, g_ast[n].sym_lc, g_ast[n].sym_gv);
    return n;
}


static int
build_for_stmt(void)
{
    int fline = g_cur.line, fcol = g_cur.col;
    expect(TOK_FOR_KW, "'for'");
    expect(TOK_LPAREN, "'('");
    int tmp_init[16];
    int n_init = 0;
    /* init (optional) */
    if (g_cur.kind == TOK_INT_KW || g_cur.kind == TOK_CHAR_KW ||
        g_cur.kind == TOK_LONG_KW) {
        /* C99 form: for (int i = 0; ...).  Register the local at build;
         * the assignment (if any) becomes an init node. */
        LocalType decl_type = (g_cur.kind == TOK_INT_KW)  ? LT_INT
                            : (g_cur.kind == TOK_CHAR_KW) ? LT_CHAR
                                                          : LT_LONG;
        next_tok();
        if (g_cur.kind != TOK_IDENT)
            die(g_cur.line, g_cur.col, "expected name after type in for-init");
        const char *name_ptr = g_cur.id_ptr;
        int         name_len = g_cur.id_len;
        int         line = g_cur.line, col = g_cur.col;
        next_tok();
        locals_declare(name_ptr, name_len, LK_LOCAL,
                       decl_type, 1, line, col);
        if (g_cur.kind == TOK_EQ) {
            next_tok();
            int rhs = ast_build_assign();
            Local *lc = locals_lookup(name_ptr, name_len);
            int in = ast_new(N_STORE_VAR, line, col);
            g_ast[in].sym_lc = lc;
            g_ast[in].a = rhs;
            ast_copy_desc(in, rhs);
            ast_store_conv(in, g_ast[in].sym_lc, g_ast[in].sym_gv);
            tmp_init[n_init++] = in;
        }
    } else if (g_cur.kind != TOK_SEMI) {
        tmp_init[n_init++] = build_for_init_or_step();
        while (g_cur.kind == TOK_COMMA) {   /* C-2: for(i=0, j=n; ...) */
            next_tok();
            if (n_init >= 16)
                die(g_cur.line, g_cur.col, "too many for-init clauses");
            tmp_init[n_init++] = build_for_init_or_step();
        }
    }
    expect(TOK_SEMI, "';'");
    /* cond (optional; empty == always true) */
    int cond = -1;
    if (g_cur.kind != TOK_SEMI)
        cond = ast_build_comma();
    expect(TOK_SEMI, "';'");
    /* step (optional) — built HERE, in source order; walked after the body.
     * The Increment-1 cursor replay dies with this. */
    int tmp_step[16];
    int n_step = 0;
    if (g_cur.kind != TOK_RPAREN) {
        tmp_step[n_step++] = build_for_init_or_step();
        while (g_cur.kind == TOK_COMMA) {   /* C-2: for(...; ...; i++, j--) */
            next_tok();
            if (n_step >= 16)
                die(g_cur.line, g_cur.col, "too many for-step clauses");
            tmp_step[n_step++] = build_for_init_or_step();
        }
    }
    if (g_cur.kind != TOK_RPAREN)
        die(g_cur.line, g_cur.col, "expected ')'");
    next_tok();   /* consume ')' */
    int body = build_stmt();
    if (g_n_ast_kids + n_init + n_step > MAX_AST_KIDS)
        die(fline, fcol, "for-clause kid pool overflow");
    int kid0 = g_n_ast_kids;
    for (int i = 0; i < n_init; i++) g_ast_kids[g_n_ast_kids++] = tmp_init[i];
    for (int i = 0; i < n_step; i++) g_ast_kids[g_n_ast_kids++] = tmp_step[i];
    int n = ast_new(S_FOR, fline, fcol);
    g_ast[n].a = cond; g_ast[n].b = body;
    g_ast[n].kid0 = kid0;
    g_ast[n].val = (unsigned)n_init;
    g_ast[n].val_hi = (unsigned)n_step;
    return n;
}

unsigned long
parse_case_const(void)
{
    if (g_cur.kind == TOK_IDENT) {
        int eidx = enum_consts_lookup(g_cur.id_ptr, g_cur.id_len);
        if (eidx >= 0) {
            unsigned v = g_enum_consts[eidx].value;
            next_tok();
            return (unsigned long)v;
        }
        die(g_cur.line, g_cur.col,
            "case label must be int/char literal or enum constant");
    }
    /* Full 32 bits out: a LONG selector's cases need both words (frotz
     * quetzal's 'CMem'/'UMem' four-char chunk IDs differ only in the HIGH
     * word).  build_switch_stmt truncates to 16 for an int selector --
     * the same conversion C applies to the case expression (A.9.4). */
    return (unsigned long)parse_const_bin(0);
}

static int
build_switch_stmt(void)
{
    int sline = g_cur.line, scol = g_cur.col;
    expect(TOK_SWITCH_KW, "'switch'");
    expect(TOK_LPAREN, "'('");
    int cond = ast_build_comma();
    expect(TOK_RPAREN, "')'");
    /* Collect the body in ONE pass — case values evaluate at build; the
     * historical collect_switch_cases pre-scan (and its lookahead rewind)
     * dies here.  Duplicate-value checking happens against the values
     * gathered so far; label allocation happens at walk in encounter
     * order, matching the pre-scan's numbering. */
    expect(TOK_LBRACE, "'{'");
    /* A LONG selector keeps the case values' full 32 bits (both words
     * compared at emit); an int selector truncates to 16, the conversion
     * C applies to the case expression (A.9.4). */
    int sel_is_long = (g_ast[cond].type == LT_LONG ||
                       g_ast[cond].type == LT_LLONG);
    int tmp[MAX_CASES_PER_SWITCH + 64];
    int cnt = 0;
    unsigned long seen_vals[MAX_CASES_PER_SWITCH];
    int n_seen = 0;
    int saw_default = 0;
    while (g_cur.kind != TOK_RBRACE) {
        if (g_cur.kind == TOK_EOF)
            die(g_cur.line, g_cur.col, "unterminated switch body");
        if (cnt >= MAX_CASES_PER_SWITCH + 64)
            die(g_cur.line, g_cur.col, "switch body too large");
        if (g_cur.kind == TOK_CASE_KW) {
            int cl = g_cur.line, cc = g_cur.col;
            next_tok();
            unsigned long v = parse_case_const();
            if (!sel_is_long)
                v &= 0xFFFFUL;
            expect(TOK_COLON, "':' after case label");
            if (n_seen >= MAX_CASES_PER_SWITCH)
                die(cl, cc, "too many cases in one switch");
            for (int i = 0; i < n_seen; i++)
                if (seen_vals[i] == v)
                    die(cl, cc, "duplicate case value");
            seen_vals[n_seen++] = v;
            int k = ast_new(S_CASE, cl, cc);
            g_ast[k].val    = (unsigned)(v & 0xFFFFUL);
            g_ast[k].val_hi = (unsigned)((v >> 16) & 0xFFFFUL);
            /* A.9.4: "the case constants are converted to the promoted
             * type" -- for a long long selector, all 64 bits of it.  v is
             * the parser's host value, so -1 fills every word and an
             * unsigned long 0xFFFFFFFF leaves w2/w3 zero. */
            g_ast[k].val2   = (unsigned)((v >> 32) & 0xFFFFUL);
            g_ast[k].val3   = (unsigned)((v >> 48) & 0xFFFFUL);
            tmp[cnt++] = k;
            continue;
        }
        if (g_cur.kind == TOK_DEFAULT_KW) {
            int dl = g_cur.line, dc = g_cur.col;
            next_tok();
            expect(TOK_COLON, "':' after default");
            if (saw_default)
                die(dl, dc, "duplicate default");
            saw_default = 1;
            tmp[cnt++] = ast_new(S_DEFAULT, dl, dc);
            continue;
        }
        tmp[cnt++] = build_stmt();
    }
    next_tok();   /* consume '}' */
    if (g_n_ast_kids + cnt > MAX_AST_KIDS)
        die(sline, scol, "switch kid pool overflow");
    int kid0 = g_n_ast_kids;
    for (int i = 0; i < cnt; i++) g_ast_kids[g_n_ast_kids++] = tmp[i];
    int n = ast_new(S_SWITCH, sline, scol);
    g_ast[n].a = cond;
    g_ast[n].kid0 = kid0; g_ast[n].n_kids = cnt;
    return n;
}

static int
build_while_stmt(void)
{
    int wline = g_cur.line, wcol = g_cur.col;
    expect(TOK_WHILE_KW, "'while'");
    expect(TOK_LPAREN, "'('");
    /* The controlling clause is a full `expression`, so the comma operator is
     * legal here (and in if/for/switch/do below): `while (c = getc(f), c==' ')`
     * -- joe's termidx.c/termcap.c char-scan idiom.  ast_build_comma returns
     * the bare assign-node when no comma follows, so comma-free conditions stay
     * byte-identical.  It was ast_build_assign, which stopped below the comma
     * and left the ',' to blow up as "expected ')'". */
    int cond = ast_build_comma();
    expect(TOK_RPAREN, "')'");
    int body = build_stmt();
    int n = ast_new(S_WHILE, wline, wcol);
    g_ast[n].a = cond; g_ast[n].b = body;
    return n;
}

static int
build_do_stmt(void)
{
    int dline = g_cur.line, dcol = g_cur.col;
    expect(TOK_DO_KW, "'do'");
    int body = build_stmt();
    expect(TOK_WHILE_KW, "'while' after do-body");
    expect(TOK_LPAREN, "'('");
    int cond = ast_build_comma();
    expect(TOK_RPAREN, "')'");
    expect(TOK_SEMI, "';' after do-while");
    int n = ast_new(S_DO, dline, dcol);
    g_ast[n].a = cond; g_ast[n].b = body;
    return n;
}

static int
build_if_stmt(void)
{
    int iline = g_cur.line, icol = g_cur.col;
    expect(TOK_IF_KW, "'if'");
    expect(TOK_LPAREN, "'('");
    int cond = ast_build_comma();
    expect(TOK_RPAREN, "')'");
    int then_n = build_stmt();
    int else_n = -1;
    if (g_cur.kind == TOK_ELSE_KW) {
        next_tok();
        else_n = build_stmt();
    }
    int n = ast_new(S_IF, iline, icol);
    g_ast[n].a = cond; g_ast[n].b = then_n; g_ast[n].c = else_n;
    return n;
}

static int
build_block_stmt(void)
{
    int bline = g_cur.line, bcol = g_cur.col;
    expect(TOK_LBRACE, "'{'");
    int scope_mark = g_n_locals;    /* K&R A.11.1: block scope boundary */
    int tag_mark   = g_n_structs;   /* ...and tags are scoped by the same rule */
    g_tag_scope_depth++;
    int tmp[1024];
    int cnt = 0;
    while (g_cur.kind != TOK_RBRACE) {
        if (g_cur.kind == TOK_EOF)
            die(g_cur.line, g_cur.col, "unterminated '{'");
        if (cnt >= 1024)
            die(g_cur.line, g_cur.col, "block too large (max 1024 statements)");
        tmp[cnt++] = build_stmt();
    }
    next_tok();  /* consume '}' */
    /* K&R A.11.1: a name declared in this block goes out of scope at '}', so
     * the outer same-name local resumes.  HIDE the block's locals from
     * locals_lookup (don't remove them: AST nodes hold Local* pointers and
     * g_total_slots is monotonic).  This fixes a block-scoped shadow leaking
     * out -- e.g. the Bourne /bin/sh's execute(): `case 14: { L_INT t[4]; }`
     * shadowed the function's `TREPTR t`, breaking `case 1`'s `t->comset`. */
    for (int i = scope_mark; i < g_n_locals; i++)
        g_locals[i].scope_hidden = 1;
    /* A TAG DECLARED IN THIS BLOCK GOES OUT OF SCOPE HERE TOO, by the same
     * sentence of A.11.1 -- "or to the end of the block (for declarations
     * within a function)".  fcc kept one flat table, so a second function
     * declaring the same tag name got "redefinition of struct".  2.11BSD's
     * ls(1) is the case: getname() and getgroup() each declare their own
     * `struct ncache', which is legal and could not be compiled.
     *
     * HIDDEN AND NOT REMOVED, for the reason the locals above are: emitted
     * code and AST nodes already carry the sid, and the struct's field offsets
     * were baked when its declarations were parsed.  A static object of that
     * type outlives the block, which is exactly ls's c_uid[] -- its storage is
     * already sized and it never looks the tag up again. */
    g_tag_scope_depth--;
    for (int i = tag_mark; i < g_n_structs; i++)
        g_structs[i].scope_hidden = 1;
    if (g_n_ast_kids + cnt > MAX_AST_KIDS)
        die(bline, bcol, "block kid pool overflow");
    int kid0 = g_n_ast_kids;
    for (int i = 0; i < cnt; i++) g_ast_kids[g_n_ast_kids++] = tmp[i];
    int n = ast_new(S_BLOCK, bline, bcol);
    g_ast[n].kid0 = kid0; g_ast[n].n_kids = cnt;
    return n;
}

/* Parse a struct-field pointer initializer that is the address of a global or a
 * global's struct member: `&glob`, `glob` (array decays to &glob[0]),
 * `&glob.a.b` (member address).  Records a loader-relocated &global
 * (init_values_hi=3), packing the global index (low 16) + member byte offset
 * (high 16) into init_values[idx].  Leaves g_cur AT the LAST value token so the
 * walker's trailing next_tok consumes it.  g_cur must be at '&' or the IDENT. */
static void
sfld_ptr_addr_init(Global *g, int idx)
{
    if (g_cur.kind == TOK_AMP) next_tok();
    if (g_cur.kind != TOK_IDENT)
        die(g_cur.line, g_cur.col,
            "pointer field init: need &global, a global name, or 0");
    Global *tg = globals_lookup(g_cur.id_ptr, g_cur.id_len);
    if (tg == NULL)
        die(g_cur.line, g_cur.col, "pointer field init: unknown global");
    int off = 0, cur_sid = tg->struct_id;
    LocalType cur_ty = tg->type;
    LexPeek pk;
    lex_peek_save(&pk);
    next_tok();                        /* tentatively consume the base IDENT */
    for (;;) {
        if (g_cur.kind == TOK_DOT) {
            next_tok();                /* consume '.' */
            if (g_cur.kind != TOK_IDENT)
                die(g_cur.line, g_cur.col, "pointer field init: field name after '.'");
            if (cur_sid < 0)
                die(g_cur.line, g_cur.col, "pointer field init: '.' on a non-struct");
            Field *mf = field_lookup_dot(cur_sid, g_cur.id_ptr, g_cur.id_len);
            if (mf == NULL)
                die(g_cur.line, g_cur.col, "pointer field init: no such field");
            off += mf->byte_offset;
            cur_ty = mf->type;
            cur_sid = mf->struct_id;
            lex_peek_save(&pk);        /* checkpoint at this field name */
            next_tok();                /* tentatively consume it */
            continue;
        }
        /* A constant subscript, as the scalar pointer initializer takes
         * one: K&R A.7.19, "the unary & operator may be applied to
         * external or static objects, and to external and static arrays
         * subscripted with a constant expression": `&g.s[2]',
         * `&g.c[2].v'. */
        if (g_cur.kind == TOK_LBRACKET) {
            int es = elem_size_for(cur_ty, cur_sid);
            if (es == 0)
                die(g_cur.line, g_cur.col, "pointer field init: subscripted "
                    "operand is not an array or pointer");
            next_tok();                /* consume '[' */
            off += (int)(parse_const_bin(0) * es);
            if (g_cur.kind != TOK_RBRACKET)
                die(g_cur.line, g_cur.col, "expected ']'");
            lex_peek_save(&pk);        /* checkpoint at the ']' */
            next_tok();                /* tentatively consume it */
            cur_ty = DECREF(cur_ty);
            continue;
        }
        break;
    }
    lex_peek_restore(&pk);             /* leave g_cur AT the last value token */
    g->init_values[idx]    = (unsigned)(tg - g_globals) | ((unsigned)off << 16);
    g->init_values_hi[idx] = 3;        /* &global */
    tg->is_reloc_target    = 1;
}

/* M22 struct / struct-array brace initializer.  Shared by file-scope
 * globals and static-locals (both backed by a Global*).  g_cur is at the
 * outer '{'; consumes through the matching '}'.  Returns the total field
 * count written to g->init_values[] and sets n_elems/dims/n_bytes when
 * size_from_init.  Only scalar fields (int, char, long, float, char*, fn-ptr). */
/* One float initializer item: a float literal, or an int/char literal
 * converted to float on the host, with an optional leading unary minus that
 * flips the IEEE-754 sign bit.  Consumes the item and returns its bits.
 * Shared by a float global and each element of a float array's brace list. */
static unsigned int
parse_float_init_bits(void)
{
    int neg = 0;
    unsigned int bits = 0;

    if (g_cur.kind == TOK_MINUS) { neg = 1; next_tok(); }
    if (g_cur.kind == TOK_FLOAT_LIT) {
        bits = (g_cur.value & 0xFFFFu) |
               ((unsigned)(g_cur.value_hi & 0xFFFFu) << 16);
    } else if (g_cur.kind == TOK_INT_LIT ||
               g_cur.kind == TOK_CHAR_LIT) {
        long iv = g_cur.is_long
            ? (long)(((unsigned long)(g_cur.value_hi & 0xFFFFu) << 16) |
                     (g_cur.value & 0xFFFFu))
            : (long)(short)g_cur.value;
        float f = (float)iv;
        memcpy(&bits, &f, 4);
    } else {
        die(g_cur.line, g_cur.col,
            "float initializer must be a numeric literal");
    }
    if (neg) bits ^= 0x80000000u;
    next_tok();
    return bits;
}

/* One long double initializer item, as parse_float_init_bits is for a
 * float: a double or long double constant's own 64-bit value, an F constant's
 * single widened exactly (the value a run-time assignment of it stores), or an
 * integer or character constant of its A.2.5.1 type converted on the host,
 * with an optional leading unary minus.  Consumes the item and returns the
 * IEEE double's bits. */
static unsigned long
parse_ldouble_init_bits(void)
{
    int neg = 0;
    double d;
    unsigned long bits;

    if (g_cur.kind == TOK_MINUS) { neg = 1; next_tok(); }
    if (g_cur.kind == TOK_FLOAT_LIT && g_cur.is_dbl) {
        d = g_cur.dval;
    } else if (g_cur.kind == TOK_FLOAT_LIT) {
        unsigned int fb = (g_cur.value & 0xFFFFu) |
                          ((unsigned)(g_cur.value_hi & 0xFFFFu) << 16);
        float f;
        memcpy(&f, &fb, 4);
        d = f;
    } else if (g_cur.kind == TOK_INT_LIT || g_cur.kind == TOK_CHAR_LIT) {
        unsigned long v = (g_cur.value & 0xFFFFu) |
                          ((unsigned long)(g_cur.value_hi & 0xFFFFu) << 16) |
                          ((unsigned long)(g_cur.value2 & 0xFFFFu) << 32) |
                          ((unsigned long)(g_cur.value3 & 0xFFFFu) << 48);
        if (g_cur.kind == TOK_INT_LIT && g_cur.is_llong)
            d = g_cur.is_unsigned ? (double)v : (double)(long)v;
        else if (g_cur.kind == TOK_INT_LIT && g_cur.is_long)
            d = g_cur.is_unsigned ? (double)(unsigned int)v
                                  : (double)(int)(unsigned int)v;
        else if (g_cur.kind == TOK_INT_LIT && g_cur.is_unsigned)
            d = (double)(unsigned short)v;
        else
            d = (double)(short)v;
    } else {
        die(g_cur.line, g_cur.col,
            "double initializer must be a numeric literal");
    }
    if (neg) d = -d;
    memcpy(&bits, &d, 8);
    next_tok();
    return bits;
}

static int
parse_struct_brace_init(Global *g, int size_from_init, int line, int col)
{
    int n = 0;
        /* M22: struct-array brace init.  A SCALAR struct
         * (LT_STRUCT, n_elems == 1) is the same thing with one
         * element: its `{ f1, f2, ... }` is the outer brace holding
         * one FLAT element, which the flat-mode parser below handles.
         * Outer brace contains N inner brace groups, one per
         * element.  Each inner brace has init values matching
         * the struct's field layout.  Only scalar fields
         * (int / char / char* / fn-ptr) supported. */
        /* Init SLOTS, not fields: a brace initializer supplies one value per
         * LEAF (K&R A.8.7).  struct_init_leaves flattens an embedded struct
         * VALUE member into its own leaves and a non-char ARRAY member into
         * one leaf per element; for an all-scalar struct the leaf list IS the
         * field list, so this is byte-identical for everything that already
         * worked.  This is what lets `{{0L,0L},{0L,0L},0,...}` (struct rusage,
         * tcsh sh.proc) and an array member taking a scalar 0 (struct varent's
         * v_link[3], tcsh sh.dol) be represented at all: the old model stored
         * exactly ONE slot per field and derived the element count by dividing
         * by n_fields, so neither shape could be expressed. */
        Field  leaves[MAX_STRUCT_INIT_LEAVES];
        int    leaf_owner[MAX_STRUCT_INIT_LEAVES];
        int    n_fields = struct_init_leaves(g->struct_id, leaves, leaf_owner,
                                             MAX_STRUCT_INIT_LEAVES);
        if (n_fields < 0)
            die(g_cur.line, g_cur.col,
                "struct initializer has too many leaf members");
        g->init_slots_per_elem = n_fields;
        int elem_idx = 0;
        next_tok();   /* consume outer '{' */
        /* G50: brace elision — a struct array may be initialized
         * by a FLAT comma list grouped n_fields at a time, with no
         * inner braces (stevie's charset table:
         * `struct charinfo chars[] = {0,0, 2,"^A", 2,"^B", ...}`).
         * Detect the mode from the first element token; when flat,
         * skip the per-element inner '{'/'}'. */
        int flat = (g_cur.kind != TOK_LBRACE);
        /* A SCALAR struct's outer brace already holds its ONE element, so an
         * inner '{' there is a MEMBER group (`struct rusage zru = {{0L,0L},
         * {0L,0L},0,...}`, tcsh sh.proc), never an element group.  Detecting
         * element-mode from that '{' made the first member group parse as
         * element 0.  Gated on LT_STRUCT specifically, so a one-element struct
         * ARRAY (`struct X a[1] = {{...}}`) keeps element mode. */
        if (g->type == LT_STRUCT) flat = 1;
        while (g_cur.kind != TOK_RBRACE) {
            if (!flat) {
                if (g_cur.kind == TOK_INT_LIT && g_cur.value == 0) {
                    /* bare `0` sentinel element in a braced struct-array
                     * (telnet cmdtab's trailing `0`): zero-fill every field, no
                     * inner braces, then advance to the next element / '}'. */
                    next_tok();   /* consume '0' */
                    for (int zf = 0; zf < n_fields; zf++) {
                        if (n >= MAX_INIT_VALUES)
                            die(g_cur.line, g_cur.col, "too many init values");
                        Field *zf_fld = &leaves[zf];
                        g->init_values[n]    = 0;
                        g->init_values_hi[n] =
                            (zf_fld->type == LT_CHAR_PTR ||
                             zf_fld->type == LT_FN_PTR ||
                             ISPTR(zf_fld->type)) ? 1 : 0;
                        n++;
                    }
                    elem_idx++;
                    if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
                    if (g_cur.kind != TOK_RBRACE)
                        die(g_cur.line, g_cur.col,
                            "expected ',' or '}' after struct-array sentinel");
                    continue;
                }
                if (g_cur.kind != TOK_LBRACE)
                    die(g_cur.line, g_cur.col,
                        "expected '{' for struct-array element");
                next_tok();   /* consume inner '{' */
            }
            int grp_end = -1;          /* last leaf of an open member group */
            /* Close an open member group: either this leaf was the group's
             * last, or a '}' arrived early -- a SHORT group, whose remaining
             * leaves zero-fill WITHIN the member rather than spilling into the
             * next one (`{{1},{2}}` for two timevals is 1,0,2,0, not 1,2,...).
             * A macro because the per-field tails are separate code paths (the
             * int/char/long/float arm and the pointer/string arm each have
             * their own comma handling) and both must close the group. */
#define CLOSE_MEMBER_GROUP()                                                   \
            do {                                                               \
                if (grp_end >= 0 &&                                            \
                    (f == grp_end || g_cur.kind == TOK_RBRACE)) {              \
                    while (f < grp_end) {                                      \
                        f++;                                                   \
                        if (n >= MAX_INIT_VALUES)                              \
                            die(g_cur.line, g_cur.col,                         \
                                "too many init values");                       \
                        g->init_values[n]    = 0;                              \
                        g->init_values_hi[n] =                                 \
                            (leaves[f].type == LT_CHAR_PTR ||                  \
                             leaves[f].type == LT_FN_PTR ||                    \
                             ISPTR(leaves[f].type)) ? 1 : 0;                   \
                        n++;                                                   \
                    }                                                          \
                    if (g_cur.kind != TOK_RBRACE)                              \
                        die(g_cur.line, g_cur.col,                             \
                            "expected '}' after struct member group");         \
                    next_tok();                                                \
                    grp_end = -1;                                              \
                }                                                              \
            } while (0)
            for (int f = 0; f < n_fields; f++) {
                if (n >= MAX_INIT_VALUES)
                    die(g_cur.line, g_cur.col,
                        "too many init values");
                /* Optional MEMBER-group braces (K&R A.8.7: an aggregate member
                 * takes a nested list, which may also be ELIDED -- eliding is
                 * the flat form the rest of this loop already handles).  A
                 * group covers exactly the leaves sharing this leaf's
                 * top-level owner, so a SHORT group (`{1}` for a 2-member
                 * timeval) zero-fills the rest of that member instead of
                 * spilling into the next one, which is what makes brace
                 * groups safe to accept rather than merely skip. */
                if (g_cur.kind == TOK_LBRACE && grp_end < 0) {
                    next_tok();                    /* consume member '{' */
                    grp_end = f;
                    while (grp_end + 1 < n_fields &&
                           leaf_owner[grp_end + 1] == leaf_owner[f])
                        grp_end++;
                } else if (g_cur.kind == TOK_LBRACE) {
                    die(g_cur.line, g_cur.col,
                        "nested member-group braces deeper than one level "
                        "not supported");
                }
                Field *fld = &leaves[f];
                /* A char ARRAY member initialized by a STRING LITERAL, which
                 * K&R A.8.7 grants separately from the brace list: "As a
                 * special case, a character array may be initialized by a
                 * string literal; successive characters of the string
                 * initialize successive members of the array."  Its size rule
                 * is the next sentence -- "if its size is fixed, the number of
                 * characters in the string, not counting the terminating null
                 * character, must not exceed the size of the array" -- so a
                 * string exactly filling the member is legal and loses only
                 * its NUL, which is why the check is `>' and not `>='.
                 *
                 * Handled HERE rather than left to the per-leaf arm below
                 * because one string fills the WHOLE member: the leaves are
                 * one char each since apple/fgx#283 expanded them, and without
                 * this the string would land in the first leaf and every
                 * following value would shift up by one member -- the silent
                 * mis-fill that expanding char arrays was previously avoided
                 * to prevent.  Identified by the leaf's owner group rather
                 * than by type, so a scalar `char c' member is untouched. */
                if (g_cur.kind == TOK_STR_LIT && fld->type == LT_CHAR) {
                    int ge = f;
                    while (ge + 1 < n_fields && leaf_owner[ge + 1] == leaf_owner[f])
                        ge++;
                    if (ge > f) {
                        int nchars = ge - f + 1;
                        if (g_cur.str_len > nchars)
                            die(g_cur.line, g_cur.col,
                                "string initializer is longer than the char "
                                "array member it initializes");
                        for (int e = 0; e < nchars; e++) {
                            if (n >= MAX_INIT_VALUES)
                                die(g_cur.line, g_cur.col,
                                    "too many init values");
                            g->init_values[n]    = (e < g_cur.str_len)
                                ? (unsigned)(unsigned char)g_cur.str_ptr[e]
                                : 0;              /* trailing members zero */
                            g->init_values_hi[n] = 0;
                            n++;
                        }
                        f = ge;                   /* the group is consumed */
                        next_tok();               /* consume the string */
                        CLOSE_MEMBER_GROUP();
                        if (f + 1 < n_fields) {
                            if (g_cur.kind == TOK_COMMA) {
                                next_tok();
                            } else if (g_cur.kind == TOK_RBRACE) {
                                for (int zf = f + 1; zf < n_fields; zf++) {
                                    if (n >= MAX_INIT_VALUES)
                                        die(g_cur.line, g_cur.col,
                                            "too many init values");
                                    Field *zf_fld = &leaves[zf];
                                    g->init_values[n]    = 0;
                                    g->init_values_hi[n] =
                                        (zf_fld->type == LT_CHAR_PTR ||
                                         zf_fld->type == LT_FN_PTR) ? 1 : 0;
                                    n++;
                                }
                                break;
                            } else {
                                die(g_cur.line, g_cur.col,
                                    "expected ',' between struct field inits");
                            }
                        }
                        continue;
                    }
                }
                if (fld->type == LT_CHAR_PTR) {
                    /* char* field: accept a string literal, int
                     * literal 0 (NULL), or a global NAME whose
                     * address initializes the pointer (an array
                     * decays to &arr[0] — elvis opts[]'s `value`
                     * field = o_autoindent).  init_values_hi[n]
                     * flag: 0 = pool label, 1 = NULL, 3 = &global
                     * (init_values[n] = global index). */
                    if (field_init_is_null()) {       /* 0 / (char*)0 / ((char*)0) */
                        g->init_values[n]    = 0;
                        g->init_values_hi[n] = 1;     /* NULL */
                    } else if ((skip_field_init_cast(), g_cur.kind == TOK_STR_LIT)) {
                        int lbl = strlit_intern(g_cur.str_ptr,
                                                g_cur.str_len);
                        g->init_values[n]    = (unsigned)lbl;
                        g->init_values_hi[n] = 0;
                    } else if (g_cur.kind == TOK_AMP ||
                               g_cur.kind == TOK_IDENT) {
                        /* &global / global-name (array decays) / &global.member
                         * — loader-relocated &global, multi-bank FGX2_LONG_PTR
                         * (elvis opts[].value = o_autoindent; telnet Setlist's
                         * `&echoc` / `&nttyb.sg_erase`). */
                        sfld_ptr_addr_init(g, n);
                    } else {
                        die(g_cur.line, g_cur.col,
                            "char* field init: need string, 0, &global, or "
                            "a global name");
                    }
                } else if (fld->type == LT_INT ||
                           fld->type == LT_CHAR ||
                           fld->type == LT_LONG ||
                           fld->type == LT_LLONG ||
                           fld->type == LT_DOUBLE ||
                           fld->type == LT_FLOAT) {
                    /* G48: int/char field init is a constant
                     * EXPRESSION, not just a bare literal —
                     * stevie's param table uses `#define TRUE (1)`
                     * (parenthesized) and `P_BOOL|P_NUM` (or'd
                     * flags).  parse_const_bin handles parens,
                     * hex, enum constants, and operators, and
                     * advances past the whole expr.  A long field
                     * keeps the FULL 32-bit constant (init_values
                     * is host-unsigned; emit writes DA lo + DA hi).
                     * A float field takes a [-]float/int literal,
                     * folded to IEEE-754 bits on the host (same
                     * DA-pair emission as long). */
                    long cv;
                    if (fld->type == LT_FLOAT) {
                        int fneg = 0;
                        unsigned int bits;
                        float fv;
                        if (g_cur.kind == TOK_MINUS) {
                            fneg = 1;
                            next_tok();
                        }
                        if (g_cur.kind == TOK_FLOAT_LIT) {
                            bits = ((unsigned)g_cur.value_hi << 16)
                                   | g_cur.value;
                            memcpy(&fv, &bits, 4);
                        } else if (g_cur.kind == TOK_INT_LIT) {
                            long iv = (long)(((unsigned long)
                                       g_cur.value_hi << 16)
                                       | g_cur.value);
                            fv = (float)iv;
                        } else {
                            die(g_cur.line, g_cur.col,
                                "float field init: need a numeric literal");
                        }
                        if (fneg) fv = -fv;
                        memcpy(&bits, &fv, 4);
                        cv = (long)bits;
                        next_tok();
                    } else if (fld->type == LT_DOUBLE) {
                        cv = (long)parse_ldouble_init_bits();
                    } else {
                        cv = parse_const_bin(0);
                    }
                    g->init_values[n] = (fld->type == LT_LONG ||
                                         fld->type == LT_LLONG ||
                                         fld->type == LT_DOUBLE ||
                                         fld->type == LT_FLOAT)
                                          ? (unsigned)cv
                                          : ((unsigned)cv & 0xFFFFu);
                    if (fld->type == LT_LLONG || fld->type == LT_DOUBLE)
                        init_put_q(g, n, cv);
                    n++;
                    CLOSE_MEMBER_GROUP();
                    if (f + 1 < n_fields) {
                        if (g_cur.kind == TOK_COMMA) {
                            next_tok();
                        } else if (g_cur.kind == TOK_RBRACE) {
                            for (int zf = f + 1; zf < n_fields; zf++) {
                                if (n >= MAX_INIT_VALUES)
                                    die(g_cur.line, g_cur.col,
                                        "too many init values");
                                Field *zf_fld = &leaves[zf];
                                g->init_values[n]    = 0;
                                g->init_values_hi[n] =
                                    (zf_fld->type == LT_CHAR_PTR ||
                                     zf_fld->type == LT_FN_PTR) ? 1 : 0;
                                n++;
                            }
                            break;
                        } else {
                            die(g_cur.line, g_cur.col,
                                "expected ',' between struct field inits");
                        }
                    }
                    continue;
                } else if (fld->type == LT_FN_PTR) {
                    /* Fn-ptr field: a function NAME (its address) or a
                     * null pointer constant -- the elvis cmdnames[]/vikeys[]
                     * command table idiom.  Same 4-byte in-struct pointer
                     * shape as char*; init_values_hi[n]: 1 = NULL,
                     * 2 = function index (emit -> DA/DFB^ label).  The null
                     * test is the pointer arm's, so `NULL' (((char *)0)),
                     * `(void *)0' and `(MARK (*)())0' all qualify, as A.6.6
                     * lets a null pointer convert "to a pointer of any type". */
                    if (field_init_is_null()) {
                        g->init_values[n]    = 0;
                        g->init_values_hi[n] = 1;     /* NULL */
                    } else if (skip_field_init_cast(),
                               g_cur.kind == TOK_IDENT) {
                        int fi = funcs_lookup(g_cur.id_ptr,
                                              g_cur.id_len);
                        if (fi < 0) {
                            /* forward reference: declare implicitly
                             * (K&R () = unspecified args). */
                            fi = funcs_declare(g_cur.id_ptr,
                                               g_cur.id_len, 0,
                                               g_cur.line, g_cur.col);
                            g_funcs[fi].is_variadic = 1;
                        }
                        g->init_values[n]    = (unsigned)fi;
                        g->init_values_hi[n] = 2;     /* function idx */
                    } else {
                        die(g_cur.line, g_cur.col,
                            "fn-ptr field init: need function name or 0");
                    }
                } else if (ISPTR(fld->type)) {
                    /* Non-char pointer field (int*, void*, struct*, ...):
                     * &global / a global name / 0.  Same 4-byte loader-relocated
                     * shape as a char* &global field (init_values_hi=3).  2.11BSD
                     * telnet's togglelist `int *variable` = &autoflush. */
                    if (field_init_is_null()) {       /* 0 / (T*)0 / ((T*)0) == NIL */
                        g->init_values[n]    = 0;
                        g->init_values_hi[n] = 1;     /* NULL */
                    } else {
                        skip_field_init_cast();
                        sfld_ptr_addr_init(g, n);     /* &global(.member) / global */
                    }
                } else {
                    die(g_cur.line, g_cur.col,
                        "struct-array init: field must be int/char/char*/T*/fn-ptr (M22)");
                }
                n++;
                next_tok();
                CLOSE_MEMBER_GROUP();
                if (f + 1 < n_fields) {
                    if (g_cur.kind == TOK_COMMA)
                        next_tok();
                    else if (g_cur.kind != TOK_RBRACE)
                        die(g_cur.line, g_cur.col,
                            "expected ',' between struct field inits");
                    /* A '}' ENDS THE ELEMENT WHETHER OR NOT A COMMA PRECEDED
                     * IT.  K&R 2nd ed A.8.7 gives both productions --
                     * `{ initializer-list }' and `{ initializer-list , }' --
                     * and says of the second: "A list may end with a comma, a
                     * nicety for neat formatting" (p.179).  The comma-then-'}'
                     * arm used to fall through to the next field and meet the
                     * brace where a value should be, reporting "expected
                     * integer constant in initializer" several lines away from
                     * the comma.  2.11BSD's mount(8) is the case:
                     * mntopts.h's MOPT_NOAUTO is `{ "na", }, { "auto", }'. */
                    if (g_cur.kind == TOK_RBRACE) {
                        /* Partial element initializer (ex.c's
                         * command-table sentinel `{(char *)0}`):
                         * zero-fill the remaining fields and end the
                         * element. */
                        for (int zf = f + 1; zf < n_fields; zf++) {
                            if (n >= MAX_INIT_VALUES)
                                die(g_cur.line, g_cur.col,
                                    "too many init values");
                            Field *zf_fld = &leaves[zf];
                            g->init_values[n]    = 0;
                            g->init_values_hi[n] =
                                (zf_fld->type == LT_CHAR_PTR ||
                                 zf_fld->type == LT_FN_PTR) ? 1 : 0;
                            n++;
                        }
                        break;
                    }
                }
            }
#undef CLOSE_MEMBER_GROUP
            if (!flat) {
                if (g_cur.kind != TOK_RBRACE)
                    die(g_cur.line, g_cur.col,
                        "expected '}' after struct-array element");
                next_tok();   /* consume inner '}' */
            }
            elem_idx++;
            if (g_cur.kind == TOK_COMMA) {
                next_tok();
                /* AND THE SAME AT THE OUTER LEVEL, for the same production:
                 * `{ {..}, {..}, }' is a list ending with a comma.  Without
                 * this the loop restarts and tries to read an element out of
                 * the closing brace. */
                if (g_cur.kind == TOK_RBRACE)
                    break;
                continue;
            }
            if (g_cur.kind != TOK_RBRACE)
                die(g_cur.line, g_cur.col,
                    "expected ',' or '}' in struct-array init");
        }
        next_tok();   /* consume outer '}' */
        /* Patch element count if size-from-init. */
        if (size_from_init) {
            int es = (g_structs[g->struct_id].total_size + 1) & ~1;
            g->n_elems = elem_idx;
            g->dims[0] = elem_idx;
            g->n_bytes = elem_idx * es;
        } else if (elem_idx > g->n_elems) {
            die(line, col, "struct-array init list too long");
        }
    return n;
}

/* Parse ONE char*[] initializer item at the current token into
 * g->init_values[n]/init_values_hi[n], using the char* element tags shared
 * with char* struct fields (emit.c): 0 = string-pool label, 1 = NULL,
 * 3 = &global / decayed-global-array index.  Accepts:
 *   "str"      string literal                         -> tag 0
 *   0          NULL                                   -> tag 1
 *   &global    address of a prior global             -> tag 3
 *   arrayname  a bare global ARRAY name decays to its address (tcsh's
 *              `Char *dumphist[] = {STRhsto, STRmh, 0, 0}`, where STRxxx are
 *              `Char STRxxx[]` const arrays) and `static Char *pv[] = {STRNULL,
 *              NULL}`                                 -> tag 3
 * Advances past the item.  Shared by the file-scope and static-local walkers. */
static void
parse_char_ptr_arr_item(Global *g, int n)
{
    if (g_cur.kind == TOK_AMP) {
        next_tok();
        if (g_cur.kind != TOK_IDENT)
            die(g_cur.line, g_cur.col, "expected global name after '&'");
        Global *tg = globals_lookup(g_cur.id_ptr, g_cur.id_len);
        if (tg == NULL)
            die(g_cur.line, g_cur.col,
                "unknown global in char*[] init (must be a prior global)");
        tg->is_reloc_target  = 1;
        g->init_values[n]    = (unsigned)(tg - g_globals);
        g->init_values_hi[n] = 3;
        next_tok();
    } else if ((g_cur.kind == TOK_INT_LIT && g_cur.value == 0) ||
               field_init_is_null()) {
        /* 0, AND ANY CAST OR PARENTHESISED FORM OF IT.  K&R A.6.6 (p.160):
         * "an integral constant 0, optionally cast" is a null pointer, and
         * field_init_is_null already implements exactly that for STRUCT
         * fields -- `0', `(char*)0' and `((char*)0)'.  A char*[] item is the
         * same question about the same value and had only the bare form.
         *
         * IT BECAME REACHABLE WHEN NULL GREW A CAST.  <stdio.h> defined NULL
         * as a bare 0 -- 2.11BSD's own spelling, and correct on a PDP-11
         * where a pointer and an int are both two bytes.  They are not here,
         * so a bare 0 passed to an unprototyped function pushed two bytes
         * where four were read (apple/fgx#327's family); NULL is
         * `((char *)0)' now, and mount(8)'s `static char *edirs[] = {
         * _PATH_SBIN, _PATH_USRSBIN, NULL }' is the first initializer to see
         * one.  field_init_is_null leaves the cursor on the item's last
         * token, which is what this branch's next_tok() then consumes. */
        g->init_values[n]    = 0;
        g->init_values_hi[n] = 1;   /* NULL */
        next_tok();
    } else if (g_cur.kind == TOK_IDENT) {
        Global *tg = globals_lookup(g_cur.id_ptr, g_cur.id_len);
        if (tg == NULL || !ISARY(tg->type))
            die(g_cur.line, g_cur.col,
                "char*[] init item must be a string literal, a global "
                "array name, '&global', or 0");
        tg->is_reloc_target  = 1;
        g->init_values[n]    = (unsigned)(tg - g_globals);
        g->init_values_hi[n] = 3;
        next_tok();
    } else {
        if (g_cur.kind != TOK_STR_LIT)
            die(g_cur.line, g_cur.col,
                "char*[] init item must be a string literal, a global "
                "array name, '&global', or 0");
        g->init_values[n]    = (unsigned)strlit_intern(g_cur.str_ptr,
                                                       g_cur.str_len);
        g->init_values_hi[n] = 0;
        next_tok();
    }
}

void
parse_static_local(void)
{
    TypeSpec t = parse_type_spec();             /* consumes `static <type>` */
    /* Multiple comma-separated declarators share the base type `t`
     * (`static int offset = 0, size = 0;`).  Loop per declarator; the
     * trailing ';' is consumed once, after the last declarator. */
    for (;;) {
    int stars = 0;                              /* B-3: pointer depth */
    while (g_cur.kind == TOK_STAR) { stars++; next_tok(); }
    if (g_cur.kind != TOK_IDENT)
        die(g_cur.line, g_cur.col, "expected name in static-local decl");
    const char *nm = g_cur.id_ptr;
    int nl = g_cur.id_len;
    int line = g_cur.line, col = g_cur.col;
    next_tok();
    int is_array = 0, n_elems = 1, size_from_init = 0;
    /* Every `[N]', as at file scope (parse_declarator): a static local is a
     * static object like any other, and asctime's `static const char
     * wday_name[DAYSPERWEEK][3]' (4.3BSD-Reno ctime.c) is two-dimensional.
     * Only the outermost may be `[]', sized from the initializer. */
    int sl_n_dims = 0, sl_dims[MAX_DIMS];
    while (g_cur.kind == TOK_LBRACKET) {
        if (sl_n_dims >= MAX_DIMS)
            die(g_cur.line, g_cur.col, "too many array dimensions");
        next_tok();
        if (g_cur.kind == TOK_RBRACKET && sl_n_dims == 0) {
            /* `[]` — size taken from the initializer (char buf[] = "..."). */
            size_from_init = 1;
            sl_dims[sl_n_dims++] = 0;
        } else {
            /* integer constant EXPRESSION, not just a bare literal (G33) */
            long asz = parse_const_bin(0);
            if (asz <= 0)
                die(g_cur.line, g_cur.col,
                    "array size must be a positive integer constant");
            sl_dims[sl_n_dims++] = (int)asz;
        }
        expect(TOK_RBRACKET, "']'");
        is_array = 1;
    }
    if (is_array) {
        n_elems = 1;
        for (int di = 0; di < sl_n_dims; di++) n_elems *= sl_dims[di];
    }
    LocalType ty = type_for_decl(t, stars, is_array);
    /* G11: `static <struct> name;` (no initializer) is backed by a hidden
     * file-scope struct global, like static scalars (struct_id + n_bytes
     * patched after globals_declare below).  Struct arrays / struct pointers
     * as static locals remain unsupported. */
    /* A static-local struct ARRAY is backed by the same hidden file-scope
     * global as the scalar case -- the emitter's struct/struct-array walk and
     * the M22 brace-init parser are both already shared with file scope, so
     * the only thing that was missing is sizing this global and routing its
     * initializer (tcsh ed.screen's anonymous `static struct { int key, fun; }
     * ar[] = {...}`). */
    if (g_n_static_aliases >= MAX_STATIC_ALIASES)
        die(line, col, "too many static locals in one function (max 32)");

    /* The mangled name is only the EMITTED global label -- use sites resolve
     * the source name through the static-alias table (symtab), never by
     * reconstructing this string -- so it just has to be unique in the TU and
     * fit a Merlin symbol (< MAX_IDENT).  Normal form `func_sl_var` keeps
     * existing labels byte-identical; when func+var overflow (tcsh tc.prompt
     * `print_prompt` + `print_prompt_did_ding`), fall back to a compact
     * `func(trunc)_slN` with a monotonic per-TU counter (still unique). */
    static int g_sl_seq = 0;
    char mangled[MAX_IDENT * 2];
    int mlen = snprintf(mangled, sizeof mangled, "%s_sl_%.*s",
                        g_func_name, nl, nm);
    if (mlen >= MAX_IDENT) {
        mlen = snprintf(mangled, sizeof mangled, "%.20s_sl%d",
                        g_func_name, g_sl_seq++);
        if (mlen >= MAX_IDENT)   /* pathological: truncate the prefix harder */
            mlen = snprintf(mangled, sizeof mangled, "_sl%d", g_sl_seq++);
    }
    Global *g = globals_declare(mangled, mlen, ty, n_elems, line, col, 0);
    g->is_local_static = 1;
    g->is_unsigned = t.is_unsigned;             /* A-1 */
    if (ty == LT_STRUCT || ty == LT_STRUCT_ARRAY) {  /* G11: size + struct id */
        if (g_structs[t.struct_id].is_forward)
            die(line, col, "static local of incomplete struct");
        g->struct_id = t.struct_id;
        int esz      = (g_structs[t.struct_id].total_size + 1) & ~1;
        /* n_elems is 0 for `ar[] = {...}`; parse_struct_brace_init patches
         * n_elems/dims/n_bytes once it has counted the elements. */
        g->n_bytes   = esz * (n_elems > 0 ? n_elems : 1);
        if (ty == LT_STRUCT_ARRAY) {
            g->n_dims  = 1;
            g->dims[0] = n_elems;
        }
    }
    /* `static struct X *p [= 0];` — a 4-byte struct pointer (tcsh tw.parse
     * `static DIR *dir_fd = 0`).  The struct may be incomplete (opaque DIR);
     * a pointer only needs the id for later deref typing. */
    else if (BTYPE(ty) == BT_STRUCT)
        g->struct_id = t.struct_id;        /* ptr / ptr-to-ptr / array-of-ptr */
    if (sl_n_dims > 1) {                   /* as the file-scope declaration */
        if (ty == LT_STRUCT_ARRAY)
            die(line, col, "multi-dim arrays of struct not supported (M19)");
        g->n_dims = sl_n_dims;
        for (int di = 0; di < sl_n_dims; di++) g->dims[di] = sl_dims[di];
        int inner = 1;
        for (int di = 1; di < sl_n_dims; di++) inner *= sl_dims[di];
        g->row_stride = arr_row_elem_size(ty) * inner;
    }

    if (g_cur.kind == TOK_EQ) {
        next_tok();
        if (sl_n_dims > 1) {
            /* A multi-dimensional static local's initializer: the file-scope
             * walker, braces nested or elided (K&R A.8.7). */
            int n = 0;
            int inner = 1;
            for (int di = 1; di < sl_n_dims; di++) inner *= sl_dims[di];
            parse_nested_brace_init(g, &n, 0, sl_n_dims, g->dims,
                                    MAX_INIT_VALUES, ty);
            if (size_from_init) {
                if (n == 0 || n % inner != 0)
                    die(line, col,
                        "init list size not a multiple of inner-dim product");
                g->dims[0]  = n / inner;
                g->n_elems  = n;
                g->n_bytes  = arr_row_elem_size(ty) * n;
            } else if (n > n_elems) {
                die(line, col, "static-local array initializer too long");
            }
            g->n_init_values  = n;
            g->is_initialised = 1;
            {
                StaticAlias *a = &g_static_aliases[g_n_static_aliases++];
                a->name = lex_intern_ident(nm, nl);
                a->global_idx = (int)(g - g_globals);
            }
            if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
            break;
        }
        if (ty == LT_STRUCT || ty == LT_STRUCT_ARRAY) {
            /* Static-local struct (scalar or array): the mangled global 'g'
             * emits like a file-scope struct global, so route its `{ ... }`
             * through the same M22 brace-init walker.  size_from_init is 0 for
             * the scalar (n_elems == 1) and carries the `[]` case for arrays. */
            if (g_cur.kind != TOK_LBRACE)
                die(g_cur.line, g_cur.col,
                    "struct initializer requires '{...}'");
            g->n_init_values  = parse_struct_brace_init(
                                    g, (ty == LT_STRUCT_ARRAY) ? size_from_init
                                                               : 0,
                                    line, col);
            g->is_initialised = 1;
            /* register alias + advance, skipping the scalar fall-through
             * below (same tail as the array branch). */
            {
                StaticAlias *a = &g_static_aliases[g_n_static_aliases++];
                a->name = lex_intern_ident(nm, nl);
                a->global_idx = (int)(g - g_globals);
            }
            if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
            break;
        } else if (is_array) {
            /* Static-local array initializer.  The mangled global 'g' emits
             * exactly like a file-scope global, so populate its init_values the
             * same way: char[] = "string", char*[] = { "a", "b", ... }, and
             * int/char[] = { const, ... } (elvis fnames / labels / buf). */
            int n = 0;
            if (ty == LT_CHAR_ARRAY && g_cur.kind == TOK_STR_LIT) {
                int slen = g_cur.str_len;
                if (slen + 1 > MAX_INIT_VALUES)
                    die(g_cur.line, g_cur.col,
                        "char[] string init exceeds MAX_INIT_VALUES");
                for (int k = 0; k < slen; k++)
                    g->init_values[k] = (unsigned char)g_cur.str_ptr[k];
                g->init_values[slen] = 0;
                n = slen + 1;
                next_tok();
            } else if (g_cur.kind == TOK_LBRACE) {
                next_tok();
                while (g_cur.kind != TOK_RBRACE) {
                    if (n >= MAX_INIT_VALUES)
                        die(g_cur.line, g_cur.col, "too many init values");
                    if (ty == LT_CHAR_PTR_ARRAY) {
                        parse_char_ptr_arr_item(g, n);
                        n++;
                    } else if (ty == LT_CHAR_ARRAY ||
                               ty == LT_INT_ARRAY) {
                        long cv = parse_const_bin(0);
                        g->init_values[n++] = (unsigned)(cv & 0xFFFFL);
                    } else if (ty == LT_LONG_ARRAY || ty == LT_FLOAT_ARRAY ||
                               ty == LT_LLONG_ARRAY ||
                               ty == LT_DOUBLE_ARRAY) {
                        /* the wider element types, as the file-scope list
                         * takes them (2.11BSD ntpd's `static double
                         * drifts[5] = { 0.0, ... }'): K&R A.8.7 gives a
                         * static object's initializer one form at any
                         * scope. */
                        put_array_init_item(g, n, ty);
                        n++;
                    } else {
                        die(line, col,
                            "static-local array init: only char[], int[], "
                            "long[], float[], long long[], double[], char*[]");
                    }
                    if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
                    if (g_cur.kind != TOK_RBRACE)
                        die(g_cur.line, g_cur.col,
                            "expected ',' or '}' in init list");
                }
                next_tok();   /* consume '}' */
            } else {
                die(line, col,
                    "static-local array init: expected a string or '{'");
            }
            if (!size_from_init && n > n_elems)
                die(line, col, "static-local array initializer too long");
            g->n_init_values  = n;
            g->is_initialised = 1;
            if (size_from_init) {
                if (n == 0)
                    die(line, col, "empty static-local array initializer");
                int es = (ty == LT_CHAR_ARRAY)     ? 1
                       : (ty == LT_CHAR_PTR_ARRAY) ? 4
                       : (ty == LT_INT_ARRAY)      ? 2
                       : arr_row_elem_size(ty);
                g->n_elems = n;
                g->n_bytes = es * n;
            }
            /* register the source name -> mangled global alias (same as the
             * common tail below, which this early return skips). */
            {
                StaticAlias *a = &g_static_aliases[g_n_static_aliases++];
                a->name = lex_intern_ident(nm, nl);
                a->global_idx = (int)(g - g_globals);
            }
            if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
            break;
        }
        /* "a single expression, perhaps in braces" (K&R A8.7), as at
         * file scope. */
        int braced = (g_cur.kind == TOK_LBRACE);
        if (braced)
            next_tok();
        int neg = 0;
        if (g_cur.kind == TOK_MINUS) { neg = 1; next_tok(); }
        if (ty == LT_DOUBLE) {
            unsigned long b = parse_ldouble_init_bits();
            if (neg) b ^= 1UL << 63;          /* the IEEE sign */
            g->is_initialised = 1;
            g->init_value    = (unsigned)(b & 0xFFFFu);
            g->init_value_hi = (unsigned)((b >> 16) & 0xFFFFu);
            g->init_value_q  = (unsigned)(b >> 32);
        } else if (ty == LT_LLONG) {
            /* Any integer constant expression, folded at 64 bits. */
            long v = parse_const_bin(0);
            if (neg) v = -v;
            g->is_initialised = 1;
            g->init_value    = (unsigned)(v & 0xFFFFL);
            g->init_value_hi = (unsigned)((v >> 16) & 0xFFFFL);
            g->init_value_q  = (unsigned)((unsigned long)v >> 32);
        } else if (g_cur.kind == TOK_INT_LIT) {
            unsigned lo = g_cur.value, hi = g_cur.value_hi;
            if (neg) {
                if (ty == LT_LONG) {
                    /* 32-bit two's complement of (hi:lo). */
                    unsigned long v = ((unsigned long)hi << 16) | lo;
                    v = (unsigned long)(-(long)v);
                    lo = (unsigned)(v & 0xFFFF);
                    hi = (unsigned)((v >> 16) & 0xFFFF);
                } else {
                    lo = (unsigned)((-(int)lo) & 0xFFFF);
                    hi = 0;
                }
            }
            g->is_initialised = 1;
            g->init_value = lo;
            if (ty == LT_LONG) g->init_value_hi = hi;
            next_tok();
        } else if (g_cur.kind == TOK_CHAR_LIT) {
            g->is_initialised = 1;
            g->init_value = g_cur.value;
            next_tok();
        } else if (g_cur.kind == TOK_STR_LIT && ty == LT_CHAR_PTR) {
            /* `static char *p = "literal";` — the mangled global emits exactly
             * like a file-scope `char *p = "literal"`, so record the pooled
             * string label the same way (tcsh sh.dir `static char *emsg =
             * "..."`, ed.screen `static char *fmts = "%s\n", *fmtd = "%d\n"`). */
            g->is_initialised = 1;
            g->init_str_label = strlit_intern(g_cur.str_ptr, g_cur.str_len);
            next_tok();
        } else if (ISPTR(ty) && field_init_is_null()) {
            /* `static char *p = NULL;` WHERE NULL CARRIES A CAST.  K&R A.6.6
             * (p.160) makes `0', `(char*)0' and `((char*)0)' one thing -- a
             * null pointer constant -- and field_init_is_null is already this
             * compiler's reading of that sentence, used for struct fields and
             * char*[] items.  A static local is the same question again.
             *
             * REACHABLE SINCE NULL GREW A CAST: it was a bare 0 (2.11BSD's
             * own spelling, and right on a PDP-11 where int and pointer are
             * both two bytes) and is `((char *)0)' here because they are not.
             * tcsh's sh.dir, sh.func and tw.parse all open a static with it. */
            g->is_initialised = 1;
            g->init_value     = 0;
            next_tok();
        } else {
            die(g_cur.line, g_cur.col,
                "static-local initializer must be a constant (int/char "
                "literal or, for char*, a string literal, or a null "
                "pointer constant)");
        }
        if (braced) {
            if (g_cur.kind == TOK_COMMA)
                next_tok();
            expect(TOK_RBRACE, "'}' closing a braced scalar initializer");
        }
    }

    StaticAlias *a = &g_static_aliases[g_n_static_aliases++];
    a->name = lex_intern_ident(nm, nl);
    a->global_idx = (int)(g - g_globals);
    if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
    break;
    }   /* for each comma-separated declarator */
    expect(TOK_SEMI, "';' after static-local decl");
}

/* Statement-context read-modify-write of the deref LVALUE `*ptr` for a bare
 * `++`/`--` (shared by G41's `(*ptr)++`/`(*ptr)--` and the prefix `++*ptr`/
 * `--*ptr` path — both bump `*ptr`, not ptr; at statement level pre/post are
 * equivalent since the result is discarded).  `lc`/`gv` name the pointer;
 * P3-2.7b: its VALUE rides an FPR, the pointee is RMW'd through [fpr] (a
 * pointer pointee is bumped by its offset WORD only — the bank byte at
 * [fpr]+2 stays intact).  A LONG pointee (`--*len` on an `off_t *`) needs the
 * full 32-bit ±1 with carry, so it hands off to emit_long_member_incdec at
 * offset 0 — the 16-bit RMW below would drop the carry into the high word.
 * Struct pointees are rejected. */
static void
emit_deref_lvalue_rmw(Local *lc, Global *gv, int is_inc, int ln, int cl)
{
    LocalType cptype = (lc != NULL) ? lc->type : gv->type;
    if (!ISPTR(cptype))
        die(ln, cl, "++/-- on '*ptr' requires a pointer");
    tword pt = DECREF(cptype);   /* type of *ptr */
    if (!ISPTR(pt) && BTYPE(pt) == BT_LONG) {
        /* statement level: the result is discarded, so prefix == postfix. */
        emit_long_member_incdec(lc, gv, /*off=*/0, is_inc, /*return_old=*/0);
        return;
    }
    if (!ISPTR(pt) && BTYPE(pt) == BT_STRUCT)
        die(ln, cl, "++/-- on '*ptr' of struct deref unsupported");
    int is_byte = !ISPTR(pt) &&
                  (BTYPE(pt) == BT_CHAR || BTYPE(pt) == BT_VOID);
    /* `(*p)++' where *p is itself a POINTER moves by what IT points at.
     * ptr_stride returns 0 for a struct pointer and the `s = 1' fallback
     * made that one byte (apple/fgx#154). */
    int s = ISPTR(pt) ? elem_size_for(pt, lc ? lc->struct_id : gv->struct_id)
                      : 1;

    int k = fpr_load_sym(lc, gv);            /* ptr value (offset+bank) */
    emit_fpr_deref_field(k, is_byte ? LT_CHAR : LT_INT, 0);  /* A = *ptr */
    if (is_inc) {
        ir_record_raw(IR_ADD_CONST, (unsigned)(s), 0, NULL);
    } else {
        ir_record_raw(IR_SUB_CONST, (unsigned)(s), 0, NULL);
    }
    if (is_byte) emit_fpr_deref_store_byte(k, 0);
    else         emit_fpr_deref_store_word(k, 0);
    fpr_drop(k);
}

/* CU-1: double-subscript LHS plumbing — `yy[a][b]` / `p->y[a][b]` store
 * forms where the FIRST subscript yields a pointer (char **yy, a char **
 * member, ...).  The callers build the address subtree exactly the way the
 * working desugared `*(yy[a] + b) = rhs` parses (N_ARR_READ /
 * N_ARROW_LOAD_CHAIN -> N_IPV_READ -> N_ADD_PPLUSI), so plain '=' reuses
 * S_DSTORE_GENERAL unchanged.  op= and postfix ++/-- reuse the
 * S_FIELD_COMPOUND_AT / S_FIELD_INCDEC_AT walkers via a synthetic
 * zero-offset char/int leaf field (those walkers read only type /
 * byte_offset / is_unsigned). */
static Field g_cu1_fields[4];
static LexPeek g_stmt_pk;
static int build_comma_expr_stmt(int line, int col);
static Field *
cu1_synth_field(int is_byte, int is_uns)
{
    Field *f = &g_cu1_fields[(is_byte ? 0 : 2) + (is_uns ? 1 : 0)];
    f->name = "(cu1)";
    f->type = is_byte ? LT_CHAR : LT_INT;
    f->struct_id = -1; f->fn_sig_id = -1;
    f->n_elems = 1; f->byte_offset = 0;
    f->byte_size = is_byte ? 1 : 2;
    f->is_unsigned = is_uns;
    return f;
}

/* CU-1 shared tail: `addr` is the element-address subtree, `ety` its
 * pointer type (char* stores bytes, int* words, ...), `pointee_uns` the
 * pointee signedness.  Consumes `= rhs;` / `op= rhs;` / `++;` / `--;`
 * and returns the statement node. */
static int
cu1_dsub_store_tail(int addr, LocalType ety, int pointee_uns,
                    int line, int col)
{
    tword pointee = DECREF((tword)ety);
    int is_byte = !ISPTR(pointee) &&
                  (BTYPE(pointee) == BT_CHAR || BTYPE(pointee) == BT_VOID);
    int is_word = !ISPTR(pointee) && BTYPE(pointee) == BT_INT;
    /* A wider element -- long, float, double, a pointer -- is as much an
     * lvalue as a char or an int (K&R A.7.4.3: `*E' "is an lvalue if the
     * operand is a pointer to an object of arithmetic, structure, union, or
     * pointer type"), so op= and ++/-- apply to it too.  The field walkers
     * below are char/int only; the expression walk handles every width, so
     * the statement is re-read as an expression statement, the rewind
     * stmt_wide_opassign uses. */
    if (!is_byte && !is_word &&
        (g_cur.kind == TOK_PLUSPLUS || g_cur.kind == TOK_MINUSMINUS ||
         is_compound_op(g_cur.kind))) {
        lex_peek_restore(&g_stmt_pk);
        return build_comma_expr_stmt(line, col);
    }
    if (g_cur.kind == TOK_PLUSPLUS || g_cur.kind == TOK_MINUSMINUS) {
        int is_inc = (g_cur.kind == TOK_PLUSPLUS);
        next_tok();
        expect(TOK_SEMI, "';'");
        int n = ast_new(S_FIELD_INCDEC_AT, line, col);
        g_ast[n].sym_f = cu1_synth_field(is_byte, pointee_uns);
        g_ast[n].a = addr;
        /* val is the AMOUNT ADDED (the walker's IR_ADD_CONST), not the
         * cell width: ++ on a char or int adds 1 (K&R A.7.4.1).  The
         * old `is_byte ? 1 : 2` bumped every word element by TWO --
         * frotz z_inc's `(*(fp - zargs[0]))++` turned 71 into 73, which
         * CZECH's indirect-opcode tests [312]/[320] caught on target
         * while the golden diffs, regenerated from the same compiler,
         * could not.  (Pointer elements never reach this arm -- the
         * is_byte/is_word gate above routes them off.) */
        g_ast[n].val = 1;
        g_ast[n].flags = is_inc ? AF_IS_INC : 0;
        return n;
    }
    if (is_compound_op(g_cur.kind)) {
        TokKind op = g_cur.kind;
        next_tok();
        int rhs = ast_build_assign();
        expect(TOK_SEMI, "';'");
        { int w = stmt_wide_opassign(op, rhs); if (w >= 0) return w; }
        int n = ast_new(S_FIELD_COMPOUND_AT, line, col);
        g_ast[n].sym_f = cu1_synth_field(is_byte, pointee_uns);
        g_ast[n].a = addr; g_ast[n].op = op; g_ast[n].b = rhs;
        return n;
    }
    /* No assignment at all -- `*p++;', a value discarded (K&R A.9.2: "Most
     * expression statements are assignments or function calls", not all). */
    if (g_cur.kind != TOK_EQ) {
        lex_peek_restore(&g_stmt_pk);
        return build_comma_expr_stmt(line, col);
    }
    next_tok();
    int rhs = ast_build_assign();
    expect(TOK_SEMI, "';'");
    int n = ast_new(S_DSTORE_GENERAL, line, col);
    g_ast[n].a = addr; g_ast[n].b = rhs;
    g_ast[n].val = (unsigned)ety;
    return n;
}

/* CU-3: comma-expression statement tail — `y = cy, x = cx;` (curses.h's
 * getyx macro used as a statement).  The FIRST operand's store node is
 * already built by the caller in expression flavor; chain the remaining
 * `, operand` list exactly as build_comma does (same N_COMMA nodes) and
 * discard the value as a G20-style S_EXPR statement — identical trees to
 * the already-working parenthesized `(y = cy, x = cx);` form. */
static int
cu3_comma_stmt_tail(int first)
{
    int seq = first;
    while (g_cur.kind == TOK_COMMA) {
        int op_line = g_cur.line, op_col = g_cur.col;
        next_tok();
        int b = ast_build_assign();
        int cn = ast_new(N_COMMA, op_line, op_col);
        g_ast[cn].a = seq; g_ast[cn].b = b;
        g_ast[cn].type        = g_ast[b].type;
        g_ast[cn].struct_id   = g_ast[b].struct_id;
        g_ast[cn].fn_sig      = g_ast[b].fn_sig;
        g_ast[cn].is_unsigned = g_ast[b].is_unsigned;
        seq = cn;
    }
    expect(TOK_SEMI, "';'");
    int n = ast_new(S_EXPR, g_cur.line, g_cur.col);
    g_ast[n].a = seq;
    return n;
}

/* Comma-operator expression statement (pcc cgram.y: an expr-statement is
 * `expression ';'` and ',' is the lowest-precedence binary op).  fcc's
 * statement builder has per-shape fast-path store/call arms that handle only a
 * single lvalue-store or call; a top-level ',' before the ';' means this is a
 * comma-expression whose value is discarded.  stmt_has_top_comma scans the
 * token vector from g_cur at paren/bracket depth 0; a fast-path arm that sees a
 * top-level comma calls build_comma_expr_stmt, which parses the WHOLE statement
 * as one comma-expression (build_comma) and discards it -- void operands
 * allowed (every operand's value is thrown away, like a for-init/step clause).
 * No top-level ',' -> the fast paths run unchanged, so ordinary statements stay
 * byte-identical.  Covers the tcsh idioms `blkfree(gargv), gargv = 0;`,
 * `*wp++ = c, --i;`, `hp->Hnext = np->Hnext, hfree(np);`. */
static int
stmt_has_top_comma(void)
{
    int cd = 0;
    for (int i = g_tok_idx - 1; i < g_n_toks; i++) {
        TokKind k = g_toks[i].kind;
        if (k == TOK_LPAREN || k == TOK_LBRACKET || k == TOK_LBRACE) cd++;
        else if (k == TOK_RPAREN || k == TOK_RBRACKET || k == TOK_RBRACE) cd--;
        else if (cd == 0 && k == TOK_COMMA) return 1;
        else if (cd == 0 && k == TOK_SEMI)  return 0;
        else if (k == TOK_EOF)              return 0;
    }
    return 0;
}

/* Whether the expression statement from the current token to its `;' names a
 * long long: a long long literal, a variable whose type is built on long long,
 * a member of that type in any struct, or the keywords `long long' -- and the
 * same for long double, the other 8-byte scalar.  Such a
 * statement takes the general expression path, whose lvalue walker stores all
 * eight bytes; the statement layer's store kinds are 16- and 32-bit. */
static int
stmt_names_llong(void)
{
    int cd = 0;
    for (int i = g_tok_idx - 1; i < g_n_toks; i++) {
        Tok *t = &g_toks[i];
        if (t->kind == TOK_LPAREN || t->kind == TOK_LBRACKET ||
            t->kind == TOK_LBRACE) cd++;
        else if (t->kind == TOK_RPAREN || t->kind == TOK_RBRACKET ||
                 t->kind == TOK_RBRACE) cd--;
        else if ((cd == 0 && t->kind == TOK_SEMI) || t->kind == TOK_EOF)
            return 0;
        else if (t->kind == TOK_INT_LIT && t->is_llong)
            return 1;
        else if (t->kind == TOK_LONG_KW && i + 1 < g_n_toks &&
                 (g_toks[i + 1].kind == TOK_LONG_KW ||
                  g_toks[i + 1].kind == TOK_FLOAT_KW))
            return 1;
        else if (t->kind == TOK_IDENT) {
            Local  *lc = locals_lookup(t->id_ptr, t->id_len);
            Global *gv = lc ? NULL : globals_lookup(t->id_ptr, t->id_len);
            if (lc && BT_IS_QUAD(BTYPE(lc->type))) return 1;
            if (gv && BT_IS_QUAD(BTYPE(gv->type))) return 1;
            if (i > 0 && (g_toks[i - 1].kind == TOK_DOT ||
                          g_toks[i - 1].kind == TOK_ARROW)) {
                for (int sid = 0; sid < g_n_structs; sid++)
                    for (int f = 0; f < g_structs[sid].n_fields; f++) {
                        Field *fd = &g_structs[sid].fields[f];
                        if (BT_IS_QUAD(BTYPE(fd->type)) &&
                            (int)strlen(fd->name) == t->id_len &&
                            memcmp(fd->name, t->id_ptr, t->id_len) == 0)
                            return 1;
                    }
            }
        }
    }
    return 0;
}

static int
build_comma_expr_stmt(int line, int col)
{
    int saved_void_ok = g_void_ctx_ok;
    g_void_ctx_ok = 1;
    int e = ast_build_comma();
    g_void_ctx_ok = saved_void_ok;
    expect(TOK_SEMI, "';'");
    int n = ast_new(S_EXPR, line, col);
    g_ast[n].a = e;
    return n;
}

/* Uniform lvalue-chain PARSER (K&R-canonical).  From the current token, parse a
 * postfix suffix run (`.field` / `->field` / `[expr]`) onto a base whose type is
 * `cur` (struct id `cur_sid`), building N_LV_STEP_* nodes linked via .a into
 * head->b.  Whether a field access derefs is keyed on cur's type (a POINTER cur
 * -> ARROW step / deref; a struct cur -> DOT step / offset only), independent of
 * the `.`/`->` token spelling -- so a computed pointer base (cur = its pointee)
 * and a named struct var (cur = struct) both walk uniformly.  Sets head's leaf
 * type/struct_id.  See docs plan 2026-07-23-fcc-uniform-lvalue-walker.md.
 * Non-static: the expression parser (parse_expr.c) reuses it. */
/* require_assignable -- may the operator `op' write an lvalue of type `t'?
 *
 * TWO RULES, BOTH K&R's, and every assignment-shaped arm in fcc asks this one
 * function rather than carrying its own copy of either.
 *
 * AN ARRAY TAKES NO OPERATOR AT ALL.  A.7.17 (p.169): the assignment operators
 * "all require an lvalue as left operand, and the lvalue must be modifiable: it
 * must not be an array".  A.7.3.4 and A.7.4.1 send `++' and `--' to A.7.17 for
 * their constraints.  A.7.1 (p.161) closes the gap a decay would open: the
 * array-to-pointer conversion "does not take place if the expression is in the
 * operand of the unary & operator, or of ++, --, sizeof, or as the left
 * operand of an assignment operator" -- so `a++' and `a = p' see the ARRAY,
 * not a pointer, and are refused.  A member of array type is not even an
 * lvalue: A.7.3.3 (p.164) says `s.m' and `p->m' are lvalues only "if the type
 * is not an array type".  AN ELEMENT IS: `s.m[i]' is `*((s.m)+(i))' by A.7.3.1
 * and takes every operator.  A PARAMETER declared as an array is a pointer by
 * A.10.1 (p.185) -- "the declaration is adjusted to read ``pointer to type''" --
 * so its symbol never carries an array type and this never sees one.
 *
 * A WHOLE STRUCT OR UNION TAKES ONLY `='.  A.7.17: "An expression of the form
 * E1 op= E2 is equivalent to E1 = E1 op (E2)", and A.7.7 (p.166) gives `+' no
 * meaning on a structure; `++'/`--' increment "by 1" and defer to the same
 * two sections.  `=' is the exception and it is upstream's: A.7.17 admits
 * "both operands are structures or unions of the same type".
 *
 * AND `op=' TAKES op's OWN OPERAND RULE, by the same equivalence: E1 is an
 * operand of op.  A.7.6 (p.166): "The operands of * and / must have
 * arithmetic type; the operands of % must have integral type."  A.7.8: "each
 * operand must be integral".  A.7.11-A.7.13: "The operator applies only to
 * integral operands."  So a float takes no `%=', shift or bitwise `op=', and a
 * pointer takes no `*=', `/=', `%=' or shift.  `&=', `^=' and `|=' on a
 * pointer stay accepted, as their binary forms are: masking an address is
 * ordinary BSD practice and require_integral_operand keeps the same line.
 *
 * IT TAKES THE OPERATOR AS WELL AS THE TYPE so that each arm can ask as soon
 * as its target is resolved, while g_cur is still the operator.  A token that
 * is not an assignment operator asks nothing, which is what lets an arm call
 * it before it has decided which of `=', `op=' or `++' it is holding.  Prefix
 * arms, whose operator is behind them, pass TOK_PLUSPLUS.
 *
 * The TYPE rather than a Field, because the lvalue-chain arms have none: the
 * walker leaves the chain's leaf type on its head node.  apple/fgx#393, #395. */
void
require_assignable(LocalType t, TokKind op)
{
    if (op != TOK_EQ && op != TOK_PLUSPLUS && op != TOK_MINUSMINUS &&
        !is_compound_op(op))
        return;
    if (ISARY(t))
        die(g_cur.line, g_cur.col, "an array is not a modifiable lvalue");
    if (t == LT_STRUCT && op != TOK_EQ)
        die(g_cur.line, g_cur.col,
            "only `=' is defined on a whole struct or union member");
    if ((op == TOK_STAREQ || op == TOK_SLASHEQ) && ISPTR(t))
        die(g_cur.line, g_cur.col,
            "`*=' and `/=' need an arithmetic operand, and a pointer is not "
            "one (K&R A.7.6)");
    if ((op == TOK_PERCENTEQ || op == TOK_LSHIFTEQ || op == TOK_RSHIFTEQ) &&
        (t == LT_FLOAT || t == LT_DOUBLE || ISPTR(t)))
        die(g_cur.line, g_cur.col,
            "`%=', `<<=' and `>>=' apply only to integral operands "
            "(K&R A.7.6, A.7.8)");
    if ((op == TOK_AMPEQ || op == TOK_PIPEEQ || op == TOK_CARETEQ) &&
        (t == LT_FLOAT || t == LT_DOUBLE))
        die(g_cur.line, g_cur.col,
            "`&=', `^=' and `|=' apply only to integral operands (K&R A.7.11)");
}

void
build_lvalue_suffixes(int head, LocalType cur, int cur_sid)
{
    int first = -1, last = -1;
    /* Unsignedness of the CURRENT leaf, carried across steps: a member step
     * sets it from the field, an index step INHERITS it (the element of an
     * `unsigned int[]` is unsigned).  See the head assignment below. */
    int unsig = 0;
    /* The signature of a function-pointer leaf, which is what makes the
     * chain's value callable: `pack.who->func(args)'. */
    int sig = -1;
    /* A NAMED MULTI-DIMENSIONAL ARRAY keeps its rank in the symbol (n_dims,
     * dims[] outermost first) beside a single ARY derivation, so DECREF alone
     * would type `m[i]' as the ELEMENT and scale i by the element's size.
     * K&R A.8.6.2 (p.177), on `int x3d[3][5][7]': "Any of the expressions x3d,
     * x3d[i], x3d[i][j], x3d[i][j][k] may reasonably appear in an expression.
     * The first three have type ``array,'' the last has type int", and
     * "arrays are stored by rows (last subscript varies fastest)".  So while
     * subscripts are still being applied to the base, each one steps a whole
     * row and leaves an ARRAY -- which no assignment operator may target. */
    Local  *blc = g_ast[head].sym_lc;
    Global *bgv = g_ast[head].sym_gv;
    int nd = (g_ast[head].c < 0 && (blc || bgv))
           ? (blc ? blc->n_dims : bgv->n_dims) : 0;
    const int *dv = blc ? blc->dims : (bgv ? bgv->dims : NULL);
    int dk = 0;                  /* subscripts applied to the base so far */
    /* M19b: the same rank tracking, re-seeded when a member step lands ON a
     * multi-dimensional FIELD.  A field keeps only its rank and row stride (no
     * dims[]), so the two dimensions are recovered from them here and `dv' is
     * pointed at this scratch -- the loop below is then unchanged, and a field
     * row steps exactly as a named base's row does. */
    int fdv[2];
    while (g_cur.kind == TOK_DOT || g_cur.kind == TOK_ARROW ||
           g_cur.kind == TOK_LBRACKET) {
        int line = g_cur.line, col = g_cur.col, stepn;
        if (g_cur.kind == TOK_LBRACKET) {
            int is_ptr = ISPTR(cur);
            if (!is_ptr && !ISARY(cur))
                die(line, col, "lvalue '[': operand is neither pointer nor array");
            int es = elem_size_for(cur, cur_sid);
            LocalType et = DECREF(cur);
            if (dk >= 0 && dk < nd - 1) {        /* a row of the named base */
                int k;
                for (k = dk + 1; k < nd; k++)
                    es *= dv[k];
                et = cur;
                dk++;
            } else {
                dk = -1;                         /* past the base's rank */
            }
            next_tok();                              /* consume '[' */
            int idx = ast_build_assign();
            expect(TOK_RBRACKET, "']'");
            stepn = ast_new(N_LV_STEP_INDEX, line, col);
            g_ast[stepn].b = idx;
            g_ast[stepn].val = (unsigned)es;
            g_ast[stepn].flags = is_ptr ? 1 : 0;
            g_ast[stepn].type = et;
            cur = et;
            cur_sid = (BTYPE(et) == BT_STRUCT) ? cur_sid : -1;
        } else {                                     /* '.' or '->' */
            TokKind mtok = g_cur.kind;               /* '.' vs '->' */
            int deref = ISPTR(cur);                  /* pointer cur -> deref */
            dk = -1;                                 /* off the named base */
            next_tok();                              /* consume '.' / '->' */
            if (g_cur.kind != TOK_IDENT)
                die(g_cur.line, g_cur.col, "expected field name");
            /* STRICT first (no global fallback): a member of the operand's own
             * struct keeps the type-driven deref.  Only when strict fails is it
             * the K&R 1st-ed global-member pun (A.7.3 p.164: the member need not
             * belong to the operand's type -- the rule was "not firmly
             * enforced"), and then the TOKEN drives deref: a '.' pun
             * reinterprets the operand's OWN storage (no deref -- 2.11BSD sh's
             * Lcheat(a) == ((a)._cheat), an int alias of a pointer), an '->' pun
             * derefs the operand value. */
            Field *f = field_lookup_strict_named(cur_sid, g_cur.id_ptr,
                                                 g_cur.id_len);
            if (f == NULL) {
                /* ...but NOT when the '.' operand is a struct VALUE whose exact
                 * type we have (apple/fgx#85).  A.7.3.3 puts the same "must
                 * name a member" requirement on both operators and equates
                 * `E1->MOS` with `(*E1).MOS`, so the tolerated violation the sh
                 * port needs is the one whose operand is a POINTER -- which is
                 * exactly Lcheat, a '.' spelling of the arrow shape, read as an
                 * int alias of an address.  That stays.  A '.' on a known
                 * struct has its type right there, so a name that misses it is
                 * a typo, and punning answered typos with a silent store at an
                 * unrelated member's offset.  This is the `++`/`--` arm of the
                 * class field_lookup_dot rejects on the other paths; the split
                 * is by OPERAND, not by token, and that is the same line drawn
                 * in both places. */
                if (mtok == TOK_DOT && !ISPTR(cur) && cur_sid >= 0)
                    die(g_cur.line, g_cur.col, "no such field");
                int csid = -1;
                f = field_lookup_global(g_cur.id_ptr, g_cur.id_len, &csid);
                if (f == NULL) die(g_cur.line, g_cur.col, "no such field");
                deref = (mtok == TOK_ARROW);
            }
            next_tok();
            stepn = ast_new(deref ? N_LV_STEP_ARROW : N_LV_STEP_DOT, line, col);
            g_ast[stepn].val = (unsigned)f->byte_offset;
            g_ast[stepn].type = f->type;
            g_ast[stepn].struct_id = f->struct_id;
            g_ast[stepn].is_unsigned = f->is_unsigned;
            unsig = f->is_unsigned;
            sig = (f->type == LT_FN_PTR) ? f->fn_sig_id : -1;
            cur = f->type;
            cur_sid = f->struct_id;
            /* M19b: `dk = -1' above ended the base's rank, which is right --
             * we have left it.  But if the field we just landed on is ITSELF
             * multi-dimensional, a following '[' must step a ROW of it, not an
             * element.  K&R A.8.6.2 (p.177): "the first subscript in the
             * declaration helps determine the amount of storage consumed by an
             * array, but plays no other part in subscript calculations" -- so
             * the stride is the inner dimension, which is what row_stride
             * holds, and the outer count follows from the total. */
            if (f->n_dims == 2 && f->row_stride > 0) {
                int fes = elem_size_for(f->type, f->struct_id);
                if (fes > 0 && (f->row_stride % fes) == 0) {
                    int inner = f->row_stride / fes;
                    if (inner > 0 && f->n_elems >= inner &&
                        (f->n_elems % inner) == 0) {
                        fdv[0] = f->n_elems / inner;
                        fdv[1] = inner;
                        dv = fdv;
                        nd = 2;
                        dk = 0;
                    }
                }
            }
        }
        g_ast[stepn].a = -1;
        if (first < 0) first = stepn; else g_ast[last].a = stepn;
        last = stepn;
    }
    g_ast[head].b = first;
    g_ast[head].type = cur;
    g_ast[head].struct_id = cur_sid;
    g_ast[head].fn_sig = (cur == LT_FN_PTR) ? sig : -1;
    /* Carry the LEAF's unsignedness out with the type.  Without this a read
     * routed through the walker silently lost it -- an `unsigned int` member
     * compared with `>` emitted the SIGNED helper (_fcc_gts16 instead of
     * _fcc_gtu16), so e.g. 50000 > 100 took the false branch.  A wrong branch
     * with no diagnostic is strictly worse than the parse error the walker
     * replaced, so it has to travel with the type. */
    g_ast[head].is_unsigned = unsig;
}

/* Peek (token-vector scan, no consume): is the current IDENT-led statement
 * `base <chain> [op]= rhs ;` / `base <chain> ++/-- ;` a multi-step lvalue chain
 * that the per-shape store handlers miss -- routed to the uniform K&R walker
 * (build_lvalue_suffixes/emit_lvalue_addr; K&R Appendix A.7.3 postfix grammar:
 * `.`/`->`/`[]` are one recursive left-to-right production, `E1[E2]` == `*(E1+E2)`).
 * Two miss-shapes match:
 *   (a) `.field` with a LATER `->field` (mixed dot-then-arrow: sh.sem
 *       `t->L.T_dcar->t_dflg |=`, sh.parse `alout.next->word =`);
 *   (b) a pure-arrow chain that ALSO crosses a subscript at depth >= 2 arrows --
 *       an index followed by a further `->` (sh.set `p->v_link[0]->v_bal =`) or
 *       a trailing index after two arrows (tc.who `p->w_next->w_tty[i] =`).
 * Shapes the special handlers DO cover -- pure `->` scalar chains (S_CHAIN_STORE),
 * `->arr[i]` single-arrow-then-index, `.field[i]`, arrow-then-dots (S_AV_STORE) --
 * stay byte-identical (their (n_arrow,index) signatures fall outside both tests).
 * Returns 0 / 1 (store) / 2 (incdec). */
/* Peek: is the IDENT-led chain `base[i]<.-> ...> [op]= rhs` / `++` -- i.e. the
 * FIRST suffix is a subscript and a member access (`.`/`->`) follows it?  The
 * caller gates this on the base being a struct-POINTER (tcsh tc.func
 * `tcache[i].user = strsave(...)`): `p[i]` derefs the pointer to a struct, then
 * `.field` -- a shape the per-shape statement handlers miss (the struct-ARRAY
 * twin `arr[i].field` has its own handler and a different base type, so it is
 * untouched).  Returns 0 / 1 (store) / 2 (incdec). */
static int
peek_structptr_index_field(void)
{
    int i = g_tok_idx - 1;                    /* the base IDENT (== g_cur) */
    if (g_toks[i].kind != TOK_IDENT) return 0;
    i++;
    if (g_toks[i].kind != TOK_LBRACKET) return 0;   /* first suffix must be '[' */
    int saw_member = 0;
    for (;;) {
        TokKind k = g_toks[i].kind;
        if (k == TOK_DOT || k == TOK_ARROW) { saw_member = 1; i += 2; continue; }
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
    if (!saw_member) return 0;               /* bare p[i]= is a subscript store */
    TokKind fin = g_toks[i].kind;
    if (fin == TOK_EQ || is_compound_op(fin))          return 1;
    if (fin == TOK_PLUSPLUS || fin == TOK_MINUSMINUS)  return 2;
    return 0;
}

/* A statement that is a CALL THROUGH A MEMBER of a struct: `p->disp(x);`,
 * `w->watom->disp(a, b);`, `p->q.fn(x);`.  The IDENT-statement dispatcher's
 * arms all parse a member chain expecting `=`/`op=`/`++`, so a member run that
 * ends in `(` died "expected '='" -- joe's whole `->' method-dispatch idiom.
 * Detected by a pure token scan (like stmt_has_top_comma): base IDENT, then a
 * run of `.`/`->`(IDENT) and `[...]` with AT LEAST ONE `.`/`->`, ending in
 * `(`.  Requiring a member suffix keeps a plain named call `foo(x);` and an
 * fn-ptr-array element call `arr[i](x);` on their existing paths.  Routed to
 * the expression layer (build_comma_expr_stmt), where the call now parses
 * (build_postfix_value_chain's fn-ptr-call arm). */
static int
stmt_is_member_call(void)
{
    int i = g_tok_idx - 1;                    /* the base IDENT (== g_cur) */
    if (g_toks[i].kind != TOK_IDENT) return 0;
    i++;
    int saw_member = 0;
    for (;;) {
        TokKind k = g_toks[i].kind;
        if (k == TOK_DOT || k == TOK_ARROW) {
            if (g_toks[i + 1].kind != TOK_IDENT) return 0;
            saw_member = 1; i += 2; continue;
        }
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
    return saw_member && g_toks[i].kind == TOK_LPAREN;
}

/* A statement that is a CALL THROUGH AN INDEXED FN-PTR ELEMENT, discarded:
 * `var_opcodes[opcode & 0x1f] ();` (frotz process.c's whole Z-machine
 * dispatch).  The expression layer already parses this shape (the B-7
 * direct-call arm after N_ARR_READ), but the IDENT-statement dispatcher's
 * store arms swallowed it and died "expected '='" on the '('.  Same
 * token-scan design as stmt_is_member_call, TYPE-GATED on the base IDENT
 * resolving to an fn-ptr ARRAY so plain array stores keep their paths. */
static int
stmt_is_fnptr_index_call(void)
{
    int i = g_tok_idx - 1;                    /* the base IDENT (== g_cur) */
    if (g_toks[i].kind != TOK_IDENT) return 0;
    Local  *lc = locals_lookup(g_cur.id_ptr, g_cur.id_len);
    Global *gv = (lc == NULL) ? globals_lookup(g_cur.id_ptr, g_cur.id_len)
                              : NULL;
    LocalType t = lc ? lc->type : (gv ? gv->type : LT_INT);
    if (!(ISARY(t) && DECREF(t) == LT_FN_PTR)) return 0;
    i++;
    int saw_index = 0;
    while (g_toks[i].kind == TOK_LBRACKET) {
        int d = 1; i++;
        while (d && g_toks[i].kind != TOK_EOF) {
            if (g_toks[i].kind == TOK_LBRACKET) d++;
            else if (g_toks[i].kind == TOK_RBRACKET) d--;
            i++;
        }
        saw_index = 1;
    }
    return saw_index && g_toks[i].kind == TOK_LPAREN;
}

static int
peek_mixed_lvalue_store(void)
{
    int i = g_tok_idx - 1;                    /* the base IDENT (== g_cur) */
    if (g_toks[i].kind != TOK_IDENT) return 0;
    int base_tok = i;
    i++;
    int seen_dot = 0, arrow_after_dot = 0, saw_suffix = 0;
    int dot_after_arrow = 0;
    int n_arrow = 0, has_index = 0, n_dot = 0, field_tok = -1;
    int n_index = 0;             /* M19b: subscripts, to spot `[..][..]` */
    for (;;) {
        TokKind k = g_toks[i].kind;
        if (k == TOK_DOT)   { seen_dot = 1; saw_suffix = 1;
                              if (n_arrow) dot_after_arrow = 1;
                              if (n_dot++ == 0) field_tok = i + 1;
                              i += 2; continue; }
        if (k == TOK_ARROW) { if (seen_dot) arrow_after_dot = 1;
                              n_arrow++; saw_suffix = 1; i += 2; continue; }
        if (k == TOK_LBRACKET) {
            saw_suffix = 1; n_index++;
            has_index = 1;
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
    /* (c) a DOT reaching a POINTER member that is then SUBSCRIPTED --
     * `B.pp[0][i] = x` (tcsh sh.lex, where the fbuf macro expands to B.Bfbuf,
     * a `Char **`).  build_dot_access consumes '[' only for ARRAY leaves, so a
     * POINTER leaf fell through with '[' unread: this is the STORE twin of the
     * read gap fixed in 52e32a4a.  Array-member stores (`B.arr[i] = x`) do not
     * reach here -- their per-shape handler runs first and this peek is only
     * consulted after those rewind. */
    int dot_then_index = 0;
    if (seen_dot && has_index && n_arrow == 0 && n_dot == 1 &&
        field_tok > 0 && g_toks[field_tok].kind == TOK_IDENT) {
        /* Type-gated, unlike the token-only cases above: `B.arr[i] = x` on an
         * ARRAY member has a working per-shape handler and routing it here
         * steals 11 goldens.  Only a POINTER member is genuinely unhandled. */
        Local  *blc = locals_lookup(g_toks[base_tok].id_ptr,
                                    g_toks[base_tok].id_len);
        Global *bgv = (blc == NULL) ? globals_lookup(g_toks[base_tok].id_ptr,
                                                     g_toks[base_tok].id_len)
                                    : NULL;
        LocalType bt   = blc ? blc->type      : (bgv ? bgv->type      : LT_INT);
        int       bsid = blc ? blc->struct_id : (bgv ? bgv->struct_id : -1);
        if (bt == LT_STRUCT && bsid >= 0) {
            Field *f = field_lookup_dot(bsid, g_toks[field_tok].id_ptr,
                                        g_toks[field_tok].id_len);
            if (f != NULL && ISPTR(f->type)) dot_then_index = 1;
        }
    }
    /* (c') the ARROW twin of (c): `p->ptrmember[i] ...= x` -- an '->'-member
     * that is itself a POINTER, then subscripted (deref+scale).  joe scrn.c's
     * `t->ary[aryx].next = ...`, where ary is `struct hentry *`.  The per-shape
     * arm indexes an ARRAY member; a POINTER member fell through and died
     * "expected '='".  Type-gated so the struct-array-member store keeps its
     * handler (and its goldens). */
    int arrow_then_index = 0;
    if (n_arrow >= 1 && has_index && n_dot >= 1 &&
        g_toks[base_tok + 1].kind == TOK_ARROW &&
        g_toks[base_tok + 2].kind == TOK_IDENT &&
        g_toks[base_tok + 3].kind == TOK_LBRACKET) {
        Local  *blc = locals_lookup(g_toks[base_tok].id_ptr,
                                    g_toks[base_tok].id_len);
        Global *bgv = (blc == NULL) ? globals_lookup(g_toks[base_tok].id_ptr,
                                                     g_toks[base_tok].id_len)
                                    : NULL;
        LocalType bt   = blc ? blc->type      : (bgv ? bgv->type      : LT_INT);
        int       bsid = blc ? blc->struct_id : (bgv ? bgv->struct_id : -1);
        if (bt == LT_STRUCT_PTR && bsid >= 0) {
            Field *f = field_lookup_dot(bsid, g_toks[base_tok + 2].id_ptr,
                                        g_toks[base_tok + 2].id_len);
            if (f != NULL && ISPTR(f->type) && !is_ptr_array(f->type))
                arrow_then_index = 1;
        }
    }
    /* (a) mixed dot-then-arrow, or (b) arrow chain crossing a subscript at depth. */
    /* Multi-arrow chain ending in a '.'-member store: `bw->b->o.readonly = x'
     * (joe rc.c).  The single-arrow-then-dot arm handles `p->o.f = x`, but a
     * store whose target crosses TWO OR MORE '->' before the '.' had no
     * per-shape arm and died "expected '='".  The walker resolves any depth;
     * the expression layer already handled the same lvalue as a value, so this
     * only routes a shape that currently fails. */
    int arrow_then_dot = (n_arrow >= 2 && n_dot >= 1 && !has_index);
    /* (e) M19b: a member chain landing on a RANK-2 ARRAY FIELD, then
     * subscripted -- `f->f_un.f_uname[i][j] = x' (syslogd's F_USERS name list).
     * Such a field had no per-shape store arm at all and died "expected '='";
     * the walker resolves it, because build_lvalue_suffixes re-seeds the rank
     * from the field.
     *
     * THE CHAIN IS RESOLVED HERE rather than the predicate keying on "a member
     * step and two subscripts", which is what this was first written as: that
     * shape is also `B.pp[0][i]' and `ip->i_din.di_addr[i][j]' -- pointer-array
     * and struct-array members that ALREADY have arms and goldens -- and
     * stealing them moved twelve of them.  The rule every predicate above
     * follows is to route only what currently fails, so this asks the field. */
    int member_dbl_index = 0;
    if (n_index >= 2 && (n_dot >= 1 || n_arrow >= 1)) {
        Local  *blc = locals_lookup(g_toks[base_tok].id_ptr,
                                    g_toks[base_tok].id_len);
        Global *bgv = (blc == NULL) ? globals_lookup(g_toks[base_tok].id_ptr,
                                                     g_toks[base_tok].id_len)
                                    : NULL;
        int sid = blc ? blc->struct_id : (bgv ? bgv->struct_id : -1);
        int t = base_tok + 1;
        Field *lastf = NULL;
        while (sid >= 0 &&
               (g_toks[t].kind == TOK_DOT || g_toks[t].kind == TOK_ARROW) &&
               g_toks[t + 1].kind == TOK_IDENT) {
            int via_dot = (g_toks[t].kind == TOK_DOT);
            lastf = via_dot
                  ? field_lookup_dot(sid, g_toks[t + 1].id_ptr,
                                     g_toks[t + 1].id_len)
                  : struct_field_lookup(sid, g_toks[t + 1].id_ptr,
                                        g_toks[t + 1].id_len);
            if (lastf == NULL) break;
            sid = lastf->struct_id;
            t += 2;
        }
        if (lastf != NULL && lastf->n_dims == 2 && g_toks[t].kind == TOK_LBRACKET)
            member_dbl_index = 1;
    }
    int routed = arrow_after_dot || (n_arrow >= 2 && has_index) || dot_then_index
                 || arrow_then_dot || arrow_then_index || member_dbl_index;
    /* (d) a PLAIN dot chain ending in ++/-- (`B.n++;`, `B.s++;` -- tcsh
     * sh.lex's fseekp macro over B.Bfseekp, an off_t).  The statement dot path
     * has '=' and 'op=' arms but NO incdec arm, while the arrow twin `p->f++`
     * has had one all along (S_MEMBER_INCDEC_STMT) -- that node derefs a
     * POINTER base, so it cannot serve a struct VARIABLE base.  The walker's
     * S_LV_INCDEC can, and handles the LONG leaf too.  Nothing else accepts
     * this shape today (it dies "expected '='"), so routing it steals nothing;
     * that is why it may be classified without the type gate above. */
    int dot_incdec = (seen_dot && n_arrow == 0 && !has_index);
    /* (e) ANY pure member chain of two hops or more ending in ++/--
     * (`a->b->c++;`, `a->b.c++;`, `a.b.c++;` -- Reno's vfs_bio
     * `bp->b_vp->v_numoutput++`).  The generalisation of (d) past one hop, and
     * unhandled for the same reason: the per-shape incdec arms are
     * S_MEMBER_INCDEC_STMT, which derefs ONE pointer, and (d)'s single dot.
     * Neither can reach a second hop, and two hops and beyond died
     * "expected '='", so routing steals nothing.  A SINGLE arrow (`p->f++`)
     * sums to one and keeps its own handler; a subscript anywhere is excluded
     * because the shapes that mix one in are classified by `routed` above. */
    int chain_incdec = ((n_arrow + n_dot) >= 2 && !has_index);
    TokKind fin = g_toks[i].kind;
    if ((fin == TOK_PLUSPLUS || fin == TOK_MINUSMINUS) &&
        (routed || dot_incdec || chain_incdec))
        return 2;
    /* (f) ARROW-THEN-DOT under a COMPOUND operator -- `p->a.b &= v`
     * (apple/fgx#280; 2.11BSD fsck pass2.c:66, `dp->di_mode &= ~IFMT', where
     * di_mode is upstream's own alias for di_ic1.ic_mode).  (a) above is the
     * MIRROR of this shape and has been routed all along; this one was simply
     * never added, so it fell past every arm and died "expected '='".
     *
     * K&R A.7.17: the grammar is `unary-expression assignment-operator
     * assignment-expression', and "All require an lvalue as left operand, and
     * the lvalue must be modifiable: it must not be an array, and must not
     * have an incomplete type, or be a function."  NOTHING there restricts the
     * SHAPE of the lvalue -- `p->a.b' is a modifiable lvalue by A.7.3.3 ("A
     * postfix expression followed by a dot followed by an identifier is a
     * postfix expression"), so the reject was artificial.  The same paragraph
     * settles the semantics too: "An expression of the form E1 op= E2 is
     * equivalent to E1 = E1 op (E2) except that E1 is evaluated only once" --
     * and fcc ALREADY compiles the hand-expanded `p->a.b = p->a.b & 7'.  It
     * accepted the equivalence and refused the abbreviation.
     *
     * COMPOUND ONLY, DELIBERATELY.  Plain `p->a.b = v' has a working per-shape
     * handler today; routing it here would steal its goldens, which is the
     * trap every arm above is annotated against.  Only the shapes that
     * currently DIE are taken, so this steals nothing.  A subscript anywhere
     * is excluded for the same reason -- those mixes are classified by
     * `routed'. */
    int arrowdot_compound = dot_after_arrow && !has_index;
    if (!routed) {
        if (arrowdot_compound && is_compound_op(fin)) return 1;
        return 0;
    }
    if (fin == TOK_EQ || is_compound_op(fin))          return 1;
    return 0;
}

/* Peek, for the PREFIX `++`/`--` statement arm once the operator has been
 * consumed: is what follows `IDENT <member hop> <member hop> ... ;` -- a pure
 * `.`/`->` chain, two hops or more, no subscript, ending the statement?
 *
 * Such a chain goes to the uniform walker (S_LV_INCDEC).  As a STATEMENT the
 * value is discarded, so `++a->b->c;' and `a->b->c++;' are the same operation,
 * and the walker already builds the postfix one.  One hop goes to the
 * S_COMPOUND_DOTFIELD / S_COMPOUND_MEMBER desugaring; a run with a subscript
 * goes to the expression layer's prefix arm. */
static int
peek_pure_member_chain_semi(void)
{
    int i = g_tok_idx - 1;                    /* the base IDENT (== g_cur) */
    int hops = 0;

    if (g_toks[i].kind != TOK_IDENT) return 0;
    i++;
    for (;;) {
        TokKind k = g_toks[i].kind;
        if (k != TOK_DOT && k != TOK_ARROW) break;
        if (g_toks[i + 1].kind != TOK_IDENT) return 0;
        hops++;
        i += 2;
    }
    if (hops < 2) return 0;
    return (g_toks[i].kind == TOK_SEMI);
}

/* Increment 3b phase 2: the statement BUILDER — consumes tokens, returns a
 * node; emission happens in walk_stmt.  parse_stmt below is the entry that
 * pairs them per top-level statement. */
/* parse_struct_src -- the RIGHT-hand side of a whole-struct assignment.
 *
 * Accepts `*ps', a whole struct variable, and `q->m' -- a struct-typed MEMBER
 * reached through a pointer.  Returns an AST node that evaluates to the
 * SOURCE ADDRESS, which is what S_DSTORE_STRUCT_COPY walks.
 *
 * THE MEMBER FORM IS THE HALF THAT WAS MISSING, and its absence was not a
 * quiet gap: `iq->i_din = ip->i_din' in ufs_inode.c's iget -- the whole
 * on-disk inode moving from a vnode being discarded to the one being kept --
 * compiled to ONE `LDA [src],Y / STA [dst],Y' pair and moved 2 of the
 * dinode's bytes.  Silently, since UFS 1.11a.  apple/fgx#207.
 *
 * A FUNCTION AND NOT THREE COPIES, because there are three sites that take a
 * struct RHS (`sv = ', `*pd = ' and `p->m = ') and apple/fgx#155's rule is
 * that fcc's twin arms drift apart when they are written twice.
 */
/* Peek: is the suffix run after the RHS base one of the three fixed shapes
 * parse_struct_src handles below?  Writing a run as its hop kinds (A = `->f',
 * D = `.f', I = one `[...]' run), those arms cover exactly
 *
 *      A          `p->m'          D          `v.m'          I D  `arr[i].m'
 *
 * and nothing else -- each consumes a fixed PREFIX and returns, so a deeper
 * run either dies or leaves its tail unread and the caller reports a syntax
 * error at the top of the file.  apple/fgx#214.
 *
 * NO SUFFIX AT ALL is not this scan's business: a bare `sv' is the whole-struct
 * case the bottom of the function handles, and routing it here would replace a
 * working path.
 */
static int
struct_src_needs_walker(void)
{
    int i = g_tok_idx;                    /* first token AFTER the base IDENT */
    int n_hop = 0, n_idx = 0, idx_first = 0;
    for (;;) {
        TokKind k = g_toks[i].kind;
        if (k == TOK_DOT || k == TOK_ARROW) {
            if (g_toks[i + 1].kind != TOK_IDENT) return 0;
            n_hop++; i += 2; continue;
        }
        if (k == TOK_LBRACKET) {
            if (n_hop == 0) idx_first = 1;
            n_idx++;
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
    if (n_hop == 0 && n_idx == 0)                    return 0;  /* bare `sv' */
    if (n_idx == 0 && n_hop == 1)                    return 0;  /* A or D    */
    if (n_idx == 1 && n_hop == 1 && idx_first)       return 0;  /* I D       */
    return 1;
}

/* Is the source `NAME' followed by `.m', `->m' and `[e]' steps up to the
 * statement's `;'?  Those are the shapes parse_struct_src's arms build. */
static int
struct_src_is_named_run(void)
{
    if (g_cur.kind != TOK_IDENT ||
        (locals_lookup(g_cur.id_ptr, g_cur.id_len) == NULL &&
         globals_lookup(g_cur.id_ptr, g_cur.id_len) == NULL))
        return 0;
    int i = g_tok_idx;                    /* first token AFTER the IDENT */
    for (;;) {
        TokKind k = g_toks[i].kind;
        if ((k == TOK_DOT || k == TOK_ARROW) && g_toks[i + 1].kind == TOK_IDENT) {
            i += 2;
            continue;
        }
        if (k == TOK_LBRACKET) {
            int d = 1; i++;
            while (d && g_toks[i].kind != TOK_EOF) {
                if (g_toks[i].kind == TOK_LBRACKET) d++;
                else if (g_toks[i].kind == TOK_RBRACKET) d--;
                i++;
            }
            continue;
        }
        return k == TOK_SEMI;
    }
}

static int
parse_struct_src(void)
{
    if (g_cur.kind == TOK_STAR) {
        next_tok();
        return ast_build_unary();
    }
    /* Any other struct-valued expression -- a call's member, a conditional,
     * an assignment -- is the expression parser's.  K&R A.7.17 (p.169) asks
     * only that "both operands are structures or unions of the same type",
     * and a struct value in this compiler is its address, which is what the
     * copy reads. */
    if (!struct_src_is_named_run()) {
        int ln = g_cur.line, cl = g_cur.col;
        int e = ast_build_assign();
        if (g_ast[e].type != LT_STRUCT || g_ast[e].struct_id < 0)
            die(ln, cl, "struct assignment RHS is not a struct");
        return e;
    }

    Local  *slc = locals_lookup(g_cur.id_ptr, g_cur.id_len);
    Global *sgv = slc ? NULL : globals_lookup(g_cur.id_ptr, g_cur.id_len);
    LocalType st  = slc ? slc->type      : sgv->type;
    int       ssid = slc ? slc->struct_id : sgv->struct_id;

    LexPeek pk;
    lex_peek_save(&pk);
    next_tok();                                  /* past the IDENT, to look */
    int is_arrow    = (g_cur.kind == TOK_ARROW);
    int is_dot      = (g_cur.kind == TOK_DOT);
    int is_lbracket = (g_cur.kind == TOK_LBRACKET);
    lex_peek_restore(&pk);

    /* Anything deeper than the three fixed shapes goes through the uniform
     * lvalue walker, which computes the address of an lvalue at any depth and
     * is what the ADDRESS-OF side was taught in apple/fgx#212.  This is the
     * same defect one production over: `tq = tp->t_rawq' in 2.11BSD's ttypend
     * is `tq = tp->t_nu.t_t.T_rawq' once tty.h's macro expands, and the arrow
     * arm below stops after one hop.
     *
     * K&R A.7.17 (p.169) permits it without qualification -- "both operands
     * are structures or unions of the same type" is the whole condition on a
     * struct assignment, and it says nothing about how either was reached.
     * A.7.3.2 supplies the lvalue at depth: "The expression is an lvalue if
     * the first expression is an lvalue, and if the type of the second
     * expression is not an array type", applied as many times as the run is
     * long.
     *
     * THE LHS ALREADY WENT DEEPER THAN THIS, which is the discriminator that
     * says the reject is artificial rather than unimplemented: #207 took
     * `p->M.L = L' and `v.M.L = L' and left the right-hand side at one hop.
     */
    if (struct_src_needs_walker()) {
        int ln = g_cur.line, cl = g_cur.col;
        int head = ast_new(N_LV_CHAIN, ln, cl);
        g_ast[head].c = -1;
        g_ast[head].sym_lc = slc; g_ast[head].sym_gv = sgv;
        next_tok();                              /* consume the base IDENT */
        build_lvalue_suffixes(head, st, ssid);
        if (g_ast[head].type != LT_STRUCT || g_ast[head].struct_id < 0)
            die(ln, cl, "struct assignment RHS member is not a struct");
        int an = ast_new(N_ADDR_LV_E, ln, cl);
        g_ast[an].a = head;
        g_ast[an].type = LT_STRUCT_PTR;
        g_ast[an].struct_id = g_ast[head].struct_id;
        return an;
    }

    if (st == LT_STRUCT_PTR && is_arrow) {
        next_tok();                              /* consume the IDENT */
        next_tok();                              /* consume '->' */
        if (g_cur.kind != TOK_IDENT)
            die(g_cur.line, g_cur.col, "field name after '->'");
        Field *sf = struct_field_lookup(ssid, g_cur.id_ptr, g_cur.id_len);
        if (sf == NULL) die(g_cur.line, g_cur.col, "no such field");
        if (sf->type != LT_STRUCT || sf->struct_id < 0)
            die(g_cur.line, g_cur.col,
                "struct assignment RHS member is not a struct");
        int src = ast_new(N_ADDR_ARROW_BARE, g_cur.line, g_cur.col);
        g_ast[src].sym_lc = slc; g_ast[src].sym_gv = sgv;
        g_ast[src].sym_f = sf;
        g_ast[src].type = LT_STRUCT_PTR;
        g_ast[src].struct_id = sf->struct_id;
        next_tok();                              /* consume the field IDENT */
        return src;
    }

    /* `sv.m' / `lv.m' -- a struct-typed member of a struct VARIABLE.
     * N_ADDR_DOT_BARE is the address-of node the expression layer already
     * builds for `&sv.m'; val_hi carries any parent-chain offset and is zero
     * for the single hop this accepts. */
    if (st == LT_STRUCT && is_dot) {
        next_tok();                              /* consume the IDENT */
        next_tok();                              /* consume '.' */
        if (g_cur.kind != TOK_IDENT)
            die(g_cur.line, g_cur.col, "field name after '.'");
        Field *sf = field_lookup_dot(ssid, g_cur.id_ptr, g_cur.id_len);
        if (sf == NULL) die(g_cur.line, g_cur.col, "no such field");
        if (sf->type != LT_STRUCT || sf->struct_id < 0)
            die(g_cur.line, g_cur.col,
                "struct assignment RHS member is not a struct");
        int src = ast_new(N_ADDR_DOT_BARE, g_cur.line, g_cur.col);
        g_ast[src].sym_lc = slc; g_ast[src].sym_gv = sgv;
        g_ast[src].sym_f = sf;
        g_ast[src].val_hi = 0;
        g_ast[src].type = LT_STRUCT_PTR;
        g_ast[src].struct_id = sf->struct_id;
        next_tok();                              /* consume the field IDENT */
        return src;
    }

    /* `arr[i].m' -- a struct-typed member of a struct-ARRAY element.
     * N_ELEM_ADDR adds its `val' as a constant and then the scaled index, so
     * val = the member's byte offset makes the node the member's address. */
    if (st == LT_STRUCT_ARRAY && is_lbracket) {
        int es = elem_size_for(st, ssid);
        next_tok();                              /* consume the IDENT */
        next_tok();                              /* consume '[' */
        int ridx = ast_build_assign();
        expect(TOK_RBRACKET, "']'");
        if (g_cur.kind != TOK_DOT)
            die(g_cur.line, g_cur.col,
                "struct assignment RHS: `arr[i]' needs `.field'");
        next_tok();
        if (g_cur.kind != TOK_IDENT)
            die(g_cur.line, g_cur.col, "field name after '.'");
        Field *sf = field_lookup_dot(ssid, g_cur.id_ptr, g_cur.id_len);
        if (sf == NULL) die(g_cur.line, g_cur.col, "no such field");
        if (sf->type != LT_STRUCT || sf->struct_id < 0)
            die(g_cur.line, g_cur.col,
                "struct assignment RHS member is not a struct");
        int src = ast_new(N_ELEM_ADDR, g_cur.line, g_cur.col);
        g_ast[src].sym_lc = slc; g_ast[src].sym_gv = sgv;
        g_ast[src].a = ridx;
        g_ast[src].val = (unsigned)sf->byte_offset;
        g_ast[src].val_hi = (unsigned)es;
        g_ast[src].type = LT_STRUCT_PTR;
        g_ast[src].struct_id = sf->struct_id;
        next_tok();                              /* consume the field IDENT */
        return src;
    }

    if (st != LT_STRUCT)
        die(g_cur.line, g_cur.col,
            "struct assignment RHS must be a struct lvalue");
    int src = ast_new(N_VAR_LOAD, g_cur.line, g_cur.col);
    g_ast[src].sym_lc = slc; g_ast[src].sym_gv = sgv;
    g_ast[src].type = LT_STRUCT;
    g_ast[src].struct_id = ssid;
    next_tok();
    return src;
}


/* Where the statement being built began, for stmt_wide_opassign.  A copy
 * rather than a pointer: a nested statement overwrites it, and only the
 * innermost statement, a simple assignment, ever rewinds to it. */


/* `E1 op= E2;' with E2 a long long or a double.  K&R A.7.17: "An expression
 * of the form E1 op= E2 is equivalent to E1 = E1 op (E2) except that E1 is
 * evaluated only once", and A.6.5 brings E1 op E2 to E2's type.  The
 * per-shape statement handlers compute at E1's width, so the statement is
 * parsed again as an expression statement, whose walker brings both sides to
 * the common type and converts the result back (llong_opassign).  Returns
 * that S_EXPR node, or -1 to keep the handler's.  A shift is kept: its count
 * does not balance (A.7.8). */
static int
stmt_wide_opassign(TokKind op, int rhs)
{
    if (op == TOK_EQ || op == TOK_EOF ||         /* TOK_EOF: plain `=' */
        op == TOK_LSHIFTEQ || op == TOK_RSHIFTEQ ||
        !IS_QUAD(g_ast[rhs].type))
        return -1;
    lex_peek_restore(&g_stmt_pk);
    return build_comma_expr_stmt(g_ast[rhs].line, g_ast[rhs].col);
}

static int
build_stmt(void)
{
    lex_peek_save(&g_stmt_pk);        /* stmt_wide_opassign's rewind */
    /* G21: one-shot flag (set by the parenthesized-lvalue LPAREN arm)
     * suppresses the label probe below — a synthetic inner lvalue is never
     * a label, and its single-token forms would make the probe's save/
     * restore lookahead cross a (freed) macro-expansion buffer boundary. */
    int g21_skip_label = g_paren_lvalue_skip_label;
    g_paren_lvalue_skip_label = 0;

    /* Empty statement: a bare ';' — e.g. an empty loop body `for(...);` or
     * `while(...);`.  Valid C; previously died "expected statement". */
    if (g_cur.kind == TOK_SEMI) {
        int eline = g_cur.line, ecol = g_cur.col;
        next_tok();
        return ast_new(S_EMPTY, eline, ecol);
    }

    /* Labeled statement: `IDENT :` at stmt position.  Two-token lookahead
     * via lexer-state save/restore; non-label IDENTs (assignments, calls,
     * postinc, ...) fall through to the normal IDENT paths.  The label
     * emits a Merlin symbol of the form `<funcname>_uL_<name>` to stay
     * globally unique (Merlin labels are file-scope).  Per the C grammar a
     * labeled statement INCLUDES the statement that follows (`.a` child) —
     * a bare-label node made `if (x) ... else lab: stmt;` attach only the
     * LABEL as the else arm and spill `stmt` after the whole if/else, so
     * both branches executed it (curses cr_put.c plod emitted the moved-
     * over screen char AND the ND cursor-right: +1 column per motion).
     * In a block the child chain emits identically to the old sibling
     * shape.  A label directly before '}' keeps a = -1 (lenient, as
     * before; strict C would require a statement). */
    /* C-3: `static <type> ...;` static-local declaration. */
    if (g_cur.kind == TOK_STATIC_KW) {
        int sline = g_cur.line, scol = g_cur.col;
        parse_static_local();          /* registration + data init: no code */
        return ast_new(S_EMPTY, sline, scol);
    }

    /* --libso: a statement led by a block static is an expression statement
     * (K&R A.9.2) built by the expression layer, whose lvalue walker reaches
     * the static through its block; the IDENT arms below name a global's
     * storage by label.  A label spelled like a static is not supported. */
    if (g_cur.kind == TOK_IDENT && !g21_skip_label &&
        block_static_named(g_cur.id_ptr, g_cur.id_len))
        return cu3_comma_stmt_tail(ast_build_assign());
    /* ...and so is `++s.f;' / `--s[i];' / `(s) = e;' with s a block static. */
    if ((g_cur.kind == TOK_PLUSPLUS || g_cur.kind == TOK_MINUSMINUS ||
         g_cur.kind == TOK_LPAREN) &&
        g_toks[g_tok_idx].kind == TOK_IDENT &&
        block_static_named(g_toks[g_tok_idx].id_ptr, g_toks[g_tok_idx].id_len))
        return cu3_comma_stmt_tail(ast_build_assign());

    if (g_cur.kind == TOK_IDENT && !g21_skip_label) {
        /* Probe for `IDENT :` (a user label).  Cursor checkpoint over the
         * token vector; interned text keeps label_ptr valid across it. */
        LexPeek pk;
        lex_peek_save(&pk);
        const char *label_ptr = g_cur.id_ptr;
        int   label_len = g_cur.id_len;
        int   label_line = g_cur.line, label_col = g_cur.col;
        next_tok();
        if (g_cur.kind == TOK_COLON) {
            next_tok();  /* consume ':' */
            int n = ast_new(S_LABEL, label_line, label_col);
            g_ast[n].name = label_ptr; g_ast[n].name_len = label_len;
            if (g_cur.kind != TOK_RBRACE &&
                g_cur.kind != TOK_CASE_KW && g_cur.kind != TOK_DEFAULT_KW) {
                /* case/default: the switch-body loop owns those labels
                 * (regexp.c's `defchar: default:` chain) — leave them as
                 * siblings, exactly the old bare-label behaviour. */
                int body = build_stmt();   /* label's statement (C grammar) */
                g_ast[n].a = body;
            }
            return n;
        }
        /* Not a label — restore lexer state (incl. pp-frame) and continue. */
        lex_peek_restore(&pk);
    }

    /* `goto LABEL;` — unconditional BRL to the labeled instruction.
     * Forward references resolve at link time (Merlin two-pass).  The
     * label name is interned so end-of-function can audit undefined
     * targets. */
    if (g_cur.kind == TOK_GOTO_KW) {
        int line = g_cur.line, col = g_cur.col;
        next_tok();
        if (g_cur.kind != TOK_IDENT)
            die(g_cur.line, g_cur.col, "expected label name after 'goto'");
        int gn = ast_new(S_GOTO, g_cur.line, g_cur.col);
        g_ast[gn].name = g_cur.id_ptr; g_ast[gn].name_len = g_cur.id_len;
        next_tok();
        expect(TOK_SEMI, "';'");
        /* Conservative: control may not fall through, but downstream
         * code (after a 'label:' that's the goto target) is still
         * reachable.  walk_stmt leaves "returned" clear. */
        (void)line; (void)col;
        return gn;
    }

    /* M21+: mid-block local decl.  Detect a type spec at stmt position
     * and dispatch to parse_decl.  Function-body's leading-decl loop
     * already covers the prologue case; this lets `int x = ...;` appear
     * AFTER statements within the same block. */
    if (g_cur.kind == TOK_INT_KW  || g_cur.kind == TOK_CHAR_KW  ||
        g_cur.kind == TOK_LONG_KW || g_cur.kind == TOK_FLOAT_KW ||
        g_cur.kind == TOK_VOID_KW ||   /* `void *p = ...;` in a nested block */
        g_cur.kind == TOK_STRUCT_KW ||
        g_cur.kind == TOK_UNION_KW ||
        g_cur.kind == TOK_ENUM_KW ||
        (g_cur.kind == TOK_IDENT &&
         (typedefs_lookup(g_cur.id_ptr, g_cur.id_len) >= 0 ||
          is_type_modifier_ident(g_cur.id_ptr, g_cur.id_len)))) {
        TypeSpec t = parse_type_spec();
        return build_decl(t);
    }
    if (g_cur.kind == TOK_LBRACE) {
        return build_block_stmt();
    }
    if (g_cur.kind == TOK_IF_KW) {
        return build_if_stmt();
    }
    if (g_cur.kind == TOK_WHILE_KW) {
        return build_while_stmt();     /* g_loop_depth wraps move to the walk */
    }
    if (g_cur.kind == TOK_DO_KW) {
        return build_do_stmt();
    }
    if (g_cur.kind == TOK_FOR_KW) {
        return build_for_stmt();
    }
    if (g_cur.kind == TOK_SWITCH_KW) {
        return build_switch_stmt();
    }
    if (g_cur.kind == TOK_BREAK_KW) {
        int line = g_cur.line, col = g_cur.col;
        next_tok();
        expect(TOK_SEMI, "';'");
        int n = ast_new(S_BREAK, line, col);
        return n;
    }
    if (g_cur.kind == TOK_CONTINUE_KW) {
        int line = g_cur.line, col = g_cur.col;
        next_tok();
        expect(TOK_SEMI, "';'");
        int n = ast_new(S_CONTINUE, line, col);
        return n;
    }
    if ((g_cur.kind == TOK_IDENT || g_cur.kind == TOK_STAR ||
         g_cur.kind == TOK_LPAREN || g_cur.kind == TOK_PLUSPLUS ||
         g_cur.kind == TOK_MINUSMINUS) && stmt_names_llong())
        return build_comma_expr_stmt(g_cur.line, g_cur.col);
    if (g_cur.kind == TOK_PLUSPLUS || g_cur.kind == TOK_MINUSMINUS) {
        /* Comma-operator statement led by a prefix ++/--: `--wp, ++i;`
         * (tcsh sh.dol).  Route the whole statement through build_comma. */
        if (stmt_has_top_comma())
            return build_comma_expr_stmt(g_cur.line, g_cur.col);
        /* Prefix '++p;' / '--p;' as standalone statement. */
        int is_inc = (g_cur.kind == TOK_PLUSPLUS);
        int pfx_line = g_cur.line, pfx_col = g_cur.col;
        LexPeek pfx_pk;                    /* rewind for the expression fallback */
        lex_peek_save(&pfx_pk);
        next_tok();
        /* `++(base)->m;` / `--(base)[i];` -- a PARENTHESIZED base with a
         * member/index chain after the ')'.  The bare-IDENT and paren-strip
         * arms below all key on a simple lvalue, so this fell through and died
         * "expected ';'".  Route the whole statement to the expression layer,
         * where build_unary's paren-base-chain prefix arm builds the bump.
         * joe screen.h's `outatr' uses `++(t)->x;'.  Only when a chain operator
         * actually follows the balanced parens, so `++(x);` and `++(*vp);`
         * keep their existing arms below. */
        if (g_cur.kind == TOK_LPAREN) {
            int i = g_tok_idx - 1;               /* g_cur == g_toks[g_tok_idx-1] */
            int d = 0;
            for (; g_toks[i].kind != TOK_EOF; i++) {
                if (g_toks[i].kind == TOK_LPAREN) d++;
                else if (g_toks[i].kind == TOK_RPAREN && --d == 0) { i++; break; }
            }
            TokKind after = g_toks[i].kind;
            if (after == TOK_ARROW || after == TOK_DOT || after == TOK_LBRACKET) {
                lex_peek_restore(&pfx_pk);
                return build_comma_expr_stmt(pfx_line, pfx_col);
            }
        }
        /* '++a->b->c;' / '--a.b.c;' -- a nested member chain, routed to the
         * uniform lvalue walker.  See peek_pure_member_chain_semi. */
        if (g_cur.kind == TOK_IDENT && peek_pure_member_chain_semi()) {
            Local  *blc = locals_lookup(g_cur.id_ptr, g_cur.id_len);
            Global *bgv = (blc == NULL) ? globals_lookup(g_cur.id_ptr,
                                                         g_cur.id_len) : NULL;
            if (blc || bgv) {
                LocalType bt  = blc ? blc->type      : bgv->type;
                int       bsid = blc ? blc->struct_id : bgv->struct_id;
                next_tok();                    /* consume base IDENT */
                int head = ast_new(N_LV_CHAIN, pfx_line, pfx_col);
                g_ast[head].c = -1;
                g_ast[head].sym_lc = blc; g_ast[head].sym_gv = bgv;
                build_lvalue_suffixes(head, bt, bsid);
                require_assignable(g_ast[head].type, TOK_PLUSPLUS);
                expect(TOK_SEMI, "';'");
                int n = ast_new(S_LV_INCDEC, pfx_line, pfx_col);
                g_ast[n].a = head;
                g_ast[n].flags = is_inc ? AF_IS_INC : 0;
                return n;
            }
        }
        /* Prefix '++*ptr;' / '--*ptr;' — RMW the deref LVALUE (regexp.c's
         * `++*sptr`, sptr a char**).  This arm takes the simple `* IDENT ;`
         * form; any other operand of the `*' is an expression statement.
         * K&R A.7.4.1: the operand of prefix ++ "must be an lvalue", and
         * A.7.4.3: unary * "is an lvalue if the operand is a pointer to an
         * object of arithmetic, structure, union, or pointer type" -- so
         * 2.11BSD ecvt.c's `++*--p1;' is one, and build_unary builds it. */
        if (g_cur.kind == TOK_STAR &&
            !(g_toks[g_tok_idx].kind == TOK_IDENT &&
              g_toks[g_tok_idx + 1].kind == TOK_SEMI)) {
            lex_peek_restore(&pfx_pk);
            return build_comma_expr_stmt(pfx_line, pfx_col);
        }
        if (g_cur.kind == TOK_STAR) {
            next_tok();
            const char *pn = g_cur.id_ptr;
            int pnl = g_cur.id_len;
            int pln = g_cur.line, pcl = g_cur.col;
            Local  *plc = locals_lookup(pn, pnl);
            Global *pgv = (plc == NULL) ? globals_lookup(pn, pnl) : NULL;
            if (plc == NULL && pgv == NULL) {
                char buf[64];
                snprintf(buf, sizeof buf, "'%.*s' undeclared", pnl, pn);
                die(pln, pcl, buf);
            }
            next_tok();
            expect(TOK_SEMI, "';'");
            int n = ast_new(S_PREINC_DEREF, pln, pcl);
            g_ast[n].sym_lc = plc; g_ast[n].sym_gv = pgv;
            g_ast[n].flags = is_inc ? AF_IS_INC : 0;
            return n;
        }
        /* '++(x);' / '--(x);' — strip redundant parens. */
        int st_paren = 0;
        while (g_cur.kind == TOK_LPAREN) { st_paren++; next_tok(); }
        /* '++(*vp);' / '--(*vp);' — paren-wrapped deref RMW (tcsh sh.set
         * `--(*vp);`).  Same S_PREINC_DEREF node as the unparenthesized
         * `++*ptr;` above, plus the matching closing parens. */
        if (st_paren > 0 && g_cur.kind == TOK_STAR &&
            g_toks[g_tok_idx].kind != TOK_IDENT) {
            lex_peek_restore(&pfx_pk);     /* `++(*--p);': an expression */
            return build_comma_expr_stmt(pfx_line, pfx_col);
        }
        if (st_paren > 0 && g_cur.kind == TOK_STAR) {
            next_tok();                    /* consume '*' */
            const char *pn = g_cur.id_ptr;
            int pnl = g_cur.id_len;
            int pln = g_cur.line, pcl = g_cur.col;
            Local  *plc = locals_lookup(pn, pnl);
            Global *pgv = (plc == NULL) ? globals_lookup(pn, pnl) : NULL;
            if (plc == NULL && pgv == NULL) {
                char buf[64];
                snprintf(buf, sizeof buf, "'%.*s' undeclared", pnl, pn);
                die(pln, pcl, buf);
            }
            next_tok();                    /* consume IDENT */
            while (st_paren-- > 0) expect(TOK_RPAREN, "')'");
            expect(TOK_SEMI, "';'");
            int n = ast_new(S_PREINC_DEREF, pln, pcl);
            g_ast[n].sym_lc = plc; g_ast[n].sym_gv = pgv;
            g_ast[n].flags = is_inc ? AF_IS_INC : 0;
            return n;
        }
        if (g_cur.kind != TOK_IDENT)
            die(g_cur.line, g_cur.col,
                "expected identifier after '++' / '--'");
        const char *id_ptr = g_cur.id_ptr;
        int id_len = g_cur.id_len;
        int line = g_cur.line, col = g_cur.col;
        next_tok();
        /* `++x.f;` / `--x.f;` — desugar to `x.f += 1;` (S_COMPOUND_DOTFIELD;
         * 2.11BSD date's `++tv.tv_sec`).  Single hop; no paren form.  A run
         * that continues past the member -- `--x.a[i];', `++x.u.n;' -- is a
         * prefix ++/-- on a longer lvalue, not on `x.f', and goes to the
         * expression layer, whose prefix arm walks a run of any depth. */
        if (g_cur.kind == TOK_DOT && st_paren == 0) {
            Local  *slc = locals_lookup(id_ptr, id_len);
            Global *sgv = (slc == NULL) ? globals_lookup(id_ptr, id_len) : NULL;
            int sid = slc ? ((slc->type == LT_STRUCT) ? slc->struct_id : -1)
                          : (sgv && sgv->type == LT_STRUCT) ? sgv->struct_id : -1;
            if (sid < 0)
                die(line, col, "prefix ++/-- '.' requires a struct variable");
            next_tok();                    /* consume '.' */
            if (g_cur.kind != TOK_IDENT)
                die(g_cur.line, g_cur.col, "field name after '.'");
            Field *f = field_lookup_dot(sid, g_cur.id_ptr, g_cur.id_len);
            if (f == NULL)
                die(g_cur.line, g_cur.col, "no such field");
            next_tok();
            if (g_cur.kind != TOK_SEMI) {
                lex_peek_restore(&pfx_pk);
                return build_comma_expr_stmt(pfx_line, pfx_col);
            }
            require_assignable(f->type, TOK_PLUSPLUS);
            expect(TOK_SEMI, "';'");
            int one = ast_new(N_LIT_INT, line, col);
            g_ast[one].val = 1;
            g_ast[one].type = LT_INT;
            int n = ast_new(S_COMPOUND_DOTFIELD, line, col);
            g_ast[n].sym_lc = slc; g_ast[n].sym_gv = sgv;
            g_ast[n].sym_f = f;
            g_ast[n].val = (unsigned)f->byte_offset;
            g_ast[n].op = is_inc ? TOK_PLUSEQ : TOK_MINUSEQ;
            g_ast[n].a = one;
            return n;
        }
        /* `++p->f;` / `--p->f;` — desugar to `p->f += 1;` (S_COMPOUND_MEMBER,
         * the same node the `p->f op= rhs` arm builds; tcsh glob's
         * `++pglob->gl_matchc`).  Single hop; no paren form; a continuing run
         * goes to the expression layer, as for the dot twin above. */
        if (g_cur.kind == TOK_ARROW && st_paren == 0) {
            Local  *slc = locals_lookup(id_ptr, id_len);
            Global *sgv = (slc == NULL) ? globals_lookup(id_ptr, id_len) : NULL;
            if (slc == NULL && sgv == NULL)
                die(line, col, "prefix ++/-- '->' on undeclared identifier");
            LocalType pt = slc ? slc->type : sgv->type;
            int sid = slc ? slc->struct_id : sgv->struct_id;
            if (!(ISPTR(pt) && BTYPE(pt) == BT_STRUCT) || sid < 0)
                die(line, col, "prefix ++/-- '->' requires a struct pointer");
            next_tok();                    /* consume '->' */
            if (g_cur.kind != TOK_IDENT)
                die(g_cur.line, g_cur.col, "field name after '->'");
            Field *f = struct_field_lookup(sid, g_cur.id_ptr, g_cur.id_len);
            if (f == NULL)
                die(g_cur.line, g_cur.col, "no such field");
            next_tok();
            if (g_cur.kind != TOK_SEMI) {
                lex_peek_restore(&pfx_pk);
                return build_comma_expr_stmt(pfx_line, pfx_col);
            }
            require_assignable(f->type, TOK_PLUSPLUS);
            expect(TOK_SEMI, "';'");
            int one = ast_new(N_LIT_INT, line, col);
            g_ast[one].val = 1;
            g_ast[one].type = LT_INT;
            int n = ast_new(S_COMPOUND_MEMBER, line, col);
            g_ast[n].sym_lc = slc; g_ast[n].sym_gv = sgv;
            g_ast[n].sym_f = f;
            g_ast[n].op = is_inc ? TOK_PLUSEQ : TOK_MINUSEQ;
            g_ast[n].a = one;
            return n;
        }
        /* Anything the per-shape arms above do not name -- `++arr[i];',
         * `++f(x)->m;', an index anywhere in the run, AND the parenthesized
         * whole-member `++(p->f);' (st_paren>0 with a member/index chain still
         * open inside the parens) -- is still a prefix ++/-- on a modifiable
         * lvalue (K&R A.7.4.1), and the EXPRESSION layer builds all of them
         * (build_unary's own paren+member arm).  Rewind to the '++' and go
         * there rather than dying on the ')'/';' that is not next.  A plain
         * `++(x);' leaves g_cur at ')' and keeps the paren-strip path below;
         * only a chain still open inside the parens routes here.  Only
         * reachable where this arm used to fail, so nothing that compiles today
         * changes path.  joe b.c's `++(p->line);'. */
        if (g_cur.kind != TOK_SEMI && g_cur.kind != TOK_RPAREN) {
            lex_peek_restore(&pfx_pk);
            return build_comma_expr_stmt(pfx_line, pfx_col);
        }
        while (st_paren-- > 0) expect(TOK_RPAREN, "')'");
        expect(TOK_SEMI, "';'");
        Local  *lc = locals_lookup(id_ptr, id_len);
        Global *gv = (lc == NULL) ? globals_lookup(id_ptr, id_len) : NULL;
        if (lc == NULL && gv == NULL) {
            char buf[64];
            snprintf(buf, sizeof buf, "'%.*s' undeclared",
                     id_len, id_ptr);
            die(line, col, buf);
        }
        require_assignable(lc ? lc->type : gv->type, TOK_PLUSPLUS);
        if (gv != NULL && gv->type != LT_LONG && gv->type != LT_INT &&
            gv->type != LT_CHAR && gv->type != LT_FLOAT &&
            !IS_QUAD(gv->type) &&
            !(ISPTR(gv->type) && gv->type != LT_FN_PTR))
            die(line, col,
                "prefix ++/-- on global: only int/char/long/float/pointer "
                "supported");
        int st = 1;
        if (lc != NULL && lc->type != LT_INT && lc->type != LT_CHAR) {
            st = elem_size_for(lc->type, lc->struct_id);
            if (st == 0) st = 1;
        } else if (gv != NULL && ISPTR(gv->type)) {   /* global ptr: sizeof(*g) */
            st = elem_size_for(gv->type, gv->struct_id);
            if (st == 0) st = 1;
        }
        int n = ast_new(S_PREINC_STMT, line, col);
        g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
        g_ast[n].val = (unsigned)st;
        g_ast[n].flags = is_inc ? AF_IS_INC : 0;
        return n;
    }
    if (g_cur.kind == TOK_STAR) {
        /* Deref-store: '*' unary '=' expr ';' or '*p++' / '*p--' lvalue
         * (3b: build+walk). */
        int sline = g_cur.line, scol = g_cur.col;
        /* Comma-operator statement led by a deref: `*wp++ = c, --i;` (tcsh
         * sh.dol/sh.lex).  Route the whole thing through build_comma. */
        if (stmt_has_top_comma())
            return build_comma_expr_stmt(sline, scol);
        next_tok();
        /* Fast path: *IDENT [++|--]? [op]= expr; — ONLY for a scalar
         * POINTER local.  Any other local (ptr-array `*a[i] = rhs`,
         * struct `*v.p = rhs`, ...) must fall through to the general
         * path's unary build; the fast path used to commit past ANY
         * known IDENT and die "expected '='" on the '[' / '.' (2.6a
         * made local ptr-arrays first-class; this was the missed
         * store-through-element arm). */
        if (g_cur.kind == TOK_IDENT) {
            Local *lc = locals_lookup(g_cur.id_ptr, g_cur.id_len);
            /* queue 4b: *GLOBAL op= rhs — the global twin of the local
             * fast path below (compound only; plain '=' and the ++/--
             * forms keep their existing routes). */
            if (lc == NULL) {
                Global *gv = globals_lookup(g_cur.id_ptr, g_cur.id_len);
                if (gv != NULL && ISPTR(gv->type) &&
                    !is_ptr_array(gv->type) &&
                    is_compound_op(peek_tok().kind)) {
                    next_tok();                      /* past IDENT */
                    TokKind op = g_cur.kind;
                    next_tok();
                    int rhs = ast_build_assign();
                    expect(TOK_SEMI, "';'");
                    { int w = stmt_wide_opassign(op, rhs); if (w >= 0) return w; }
                    int n = ast_new(S_DSTORE_COMPOUND, sline, scol);
                    g_ast[n].sym_gv = gv; g_ast[n].op = op;
                    g_ast[n].val = 1;                /* post = 0 */
                    g_ast[n].a = rhs;
                    return n;
                }
            }
            /* The fast path claims `*IDENT' as the whole deref operand, so it
             * is valid ONLY when IDENT is followed directly by ++/--/op=/= .
             * If a postfix continuation follows (`*sp->cp = x', `*sp.m = x',
             * `*sp[i] = x'), IDENT is not the deref target -- fall through to
             * the general unary path (which builds `*(sp->cp)' etc.).  The
             * `[' arm mirrors the 2.6a ptr-array fix for scalar pointers.
             *
             * A STRUCT POINTER FALLS THROUGH TOO, and that arm was missing.
             * `*d = s' where d is `struct foo *' is a WHOLE-STRUCT copy: K&R
             * A.7.17 lists "both operands are structures or unions of the same
             * type" among the legal simple assignments and says "the value of
             * the expression replaces that of the object referred to by the
             * lvalue" -- the whole object, not its first word.  The general
             * path below already emits the copy loop (S_DSTORE_STRUCT_COPY);
             * this fast path emitted a single 16-bit store and lost every byte
             * after the first two, SILENTLY.  Measured on `*to = *from' in
             * 2.11BSD's catq(), where struct clist is 10 bytes on this ABI and
             * exactly 2 of them moved.
             *
             * The struct-pointer GLOBAL twin was never broken: a global falls
             * out of the lc == NULL arm above (which claims compound ops only)
             * and reaches the general path already. */
            TokKind pk = peek_tok().kind;
            if (lc != NULL && ISPTR(lc->type) && !is_ptr_array(lc->type) &&
                !(lc->type == LT_STRUCT_PTR && lc->struct_id >= 0) &&
                pk != TOK_ARROW && pk != TOK_DOT && pk != TOK_LBRACKET) {
                next_tok();
                int post = 0;
                if (g_cur.kind == TOK_PLUSPLUS)        { post = 1;  next_tok(); }
                else if (g_cur.kind == TOK_MINUSMINUS) { post = -1; next_tok(); }
                if (is_compound_op(g_cur.kind)) {
                    TokKind op = g_cur.kind;
                    next_tok();
                            int rhs = ast_build_assign();
                    expect(TOK_SEMI, "';'");
                    { int w = stmt_wide_opassign(op, rhs); if (w >= 0) return w; }
                    int n = ast_new(S_DSTORE_COMPOUND, sline, scol);
                    g_ast[n].sym_lc = lc; g_ast[n].op = op;
                    g_ast[n].val = (unsigned)(post + 1);
                    g_ast[n].a = rhs;
                    return n;
                }
                /* `*p++;' -- no assignment, the value discarded: an
                 * expression statement like any other (K&R A.9.2). */
                if (g_cur.kind != TOK_EQ) {
                    lex_peek_restore(&g_stmt_pk);
                    return build_comma_expr_stmt(sline, scol);
                }
                next_tok();
                int rhs = ast_build_assign();
                expect(TOK_SEMI, "';'");
                int n = ast_new(S_DSTORE_LOCAL, sline, scol);
                g_ast[n].sym_lc = lc;
                g_ast[n].val = (unsigned)(post + 1);
                g_ast[n].a = rhs;
                return n;
            }
        }
        /* General path: '*' <unary> = expr; (incl. whole-struct copy). */
        int lhs = ast_build_unary();     /* pointer subtree */
        LocalType ptr_type = g_ast[lhs].type;
        int dest_sid = g_ast[lhs].struct_id;
        if (ptr_type == LT_STRUCT_PTR && dest_sid >= 0) {
            int nbytes = g_structs[dest_sid].total_size;
            expect(TOK_EQ, "'='");
            int src = parse_struct_src();
            expect(TOK_SEMI, "';'");
            int n = ast_new(S_DSTORE_STRUCT_COPY, sline, scol);
            g_ast[n].a = lhs; g_ast[n].b = src;
            g_ast[n].val = (unsigned)nbytes;
            return n;
        }
        /* `*(computed) op= rhs;` -- frotz mem_diff's `*(b - 1) ^= c`.  The
         * CU-1 tail consumes `=` / `op=` / `++` / `--`; its plain-'=' arm
         * builds the SAME S_DSTORE_GENERAL node this arm always built, so
         * the existing shape is unchanged.  op= goes through the
         * S_FIELD_COMPOUND_AT walker via the synthetic zero-offset field
         * (address computed once, K&R A.7.17). */
        return cu1_dsub_store_tail(lhs, ptr_type, g_ast[lhs].is_unsigned,
                                   sline, scol);
    }
    if (g_cur.kind == TOK_RETURN_KW) {
        int rline = g_cur.line, rcol = g_cur.col;
        next_tok();
        LocalType ret_t = g_funcs[g_cur_fn_idx].return_type;
        if (g_cur.kind == TOK_SEMI) {
            /* K&R: a bare `return;` is permitted in a non-void function — the
             * returned value is indeterminate; callers ignore it. */
            next_tok();
            int n = ast_new(S_RETURN, rline, rcol);
            g_ast[n].a = -1;
            return n;
        }
        if (ret_t == LT_VOID)
            die(g_cur.line, g_cur.col,
                "void function must use 'return;' (no value)");
        /* K&R A.9.6: "return expression(opt);", and an expression is the
         * comma level (A.7.18): `return (*s)++, 127;'. */
        int rv = ast_build_comma();
        expect(TOK_SEMI, "';'");
        int n = ast_new(S_RETURN, rline, rcol);
        g_ast[n].a = rv;
        g_ast[n].val = (unsigned)ret_t;
        return n;
    }
    g_last_stmt_returned = 0;
    if (g_cur.kind == TOK_IDENT) {
        /* IDENT '=' expr ';'  OR  IDENT '(' arg-list ')' ';'  OR
         * IDENT '.field' '=' expr ';' OR IDENT '->field' '=' expr ';' (M8). */
        int line = g_cur.line, col = g_cur.col;
        /* Comma-operator expression statement (see stmt_has_top_comma). */
        if (stmt_has_top_comma())
            return build_comma_expr_stmt(line, col);
        /* `p->fn(args);` -- a call through a member fn-ptr, discarded.  Routed
         * to the expression layer before the store-detection arms below, which
         * would otherwise parse the chain and die "expected '='" on the '('. */
        if (stmt_is_member_call())
            return build_comma_expr_stmt(line, col);
        /* `fnptrarr[i](args);` -- call through an indexed fn-ptr element,
         * result discarded.  Routed to the expression layer (which has the
         * B-7 direct-call arm) before the store arms below die on the '('. */
        if (stmt_is_fnptr_index_call())
            return build_comma_expr_stmt(line, col);
        /* structptr[i].field [op]= / ++ (statement): a struct-POINTER indexed,
         * then a member store -- tcsh tc.func `tcache[i].user = ...`.  Gated on
         * LT_STRUCT_PTR so the struct-ARRAY twin keeps its handler.  Reuses the
         * walker (INDEX-on-ptr = deref+scale, then DOT). */
        {
            Local  *blc = locals_lookup(g_cur.id_ptr, g_cur.id_len);
            Global *bgv = (blc == NULL) ? globals_lookup(g_cur.id_ptr,
                                                         g_cur.id_len) : NULL;
            LocalType bt0 = blc ? blc->type : (bgv ? bgv->type : LT_INT);
            int lvk = ((blc || bgv) && bt0 == LT_STRUCT_PTR)
                    ? peek_structptr_index_field() : 0;
            if (lvk) {
                int bsid = blc ? blc->struct_id : bgv->struct_id;
                next_tok();                    /* consume base IDENT */
                int head = ast_new(N_LV_CHAIN, line, col);
                g_ast[head].c = -1;
                g_ast[head].sym_lc = blc; g_ast[head].sym_gv = bgv;
                build_lvalue_suffixes(head, bt0, bsid);
                require_assignable(g_ast[head].type, g_cur.kind);
                if (lvk == 2) {
                    int is_inc = (g_cur.kind == TOK_PLUSPLUS);
                    next_tok();
                    expect(TOK_SEMI, "';'");
                    int n = ast_new(S_LV_INCDEC, line, col);
                    g_ast[n].a = head;
                    g_ast[n].flags = is_inc ? AF_IS_INC : 0;
                    return n;
                }
                TokKind op = g_cur.kind;
                next_tok();
                int rhs = ast_build_assign();
                expect(TOK_SEMI, "';'");
                { int w = stmt_wide_opassign(op, rhs); if (w >= 0) return w; }
                int n = ast_new(S_LV_STORE, line, col);
                g_ast[n].a = head; g_ast[n].op = op; g_ast[n].c = rhs;
                return n;
            }
        }
        /* Uniform lvalue walker for a mixed dot-then-arrow chain store/incdec
         * (the shape the per-shape handlers miss). */
        {
            int lvk = peek_mixed_lvalue_store();
            if (lvk) {
                Local  *blc = locals_lookup(g_cur.id_ptr, g_cur.id_len);
                Global *bgv = (blc == NULL) ? globals_lookup(g_cur.id_ptr,
                                                             g_cur.id_len) : NULL;
                if (blc || bgv) {
                    LocalType bt = blc ? blc->type      : bgv->type;
                    int      bsid = blc ? blc->struct_id : bgv->struct_id;
                    next_tok();                    /* consume base IDENT */
                    int head = ast_new(N_LV_CHAIN, line, col);
                    g_ast[head].c = -1;
                    g_ast[head].sym_lc = blc; g_ast[head].sym_gv = bgv;
                    build_lvalue_suffixes(head, bt, bsid);
                    require_assignable(g_ast[head].type, g_cur.kind);
                    if (lvk == 2) {
                        int is_inc = (g_cur.kind == TOK_PLUSPLUS);
                        next_tok();
                        expect(TOK_SEMI, "';'");
                        int n = ast_new(S_LV_INCDEC, line, col);
                        g_ast[n].a = head;
                        g_ast[n].flags = is_inc ? AF_IS_INC : 0;
                        return n;
                    }
                    TokKind op = g_cur.kind;       /* TOK_EQ or op= */
                    next_tok();
                    int rhs = ast_build_assign();
                    expect(TOK_SEMI, "';'");
                    { int w = stmt_wide_opassign(op, rhs); if (w >= 0) return w; }
                    int n = ast_new(S_LV_STORE, line, col);
                    g_ast[n].a = head; g_ast[n].op = op; g_ast[n].c = rhs;
                    return n;
                }
            }
        }
        /* g_cur.id_ptr can point into a function-like macro's expansion
         * buffer, which is freed when the pp_stack frame pops at end of
         * expansion.  The statement-call path below uses the name only AFTER
         * parsing the argument list (many next_tok calls), by which point the
         * buffer is gone -> dangling read, emitting `JSR ` with an empty or
         * garbage target (e.g. `#define LOG() log_impl()` then `LOG();`).
         * Copy the spelling to a stable buffer first, mirroring the
         * parse_expr.c primary-expression guard. */
        /* Token text is interned (token vector) — stable for the node's
         * lifetime; the old macro-buffer copy is unnecessary. */
        const char *name_ptr = g_cur.id_ptr;
        int  name_len = g_cur.id_len;
        /* A checkpoint AT the identifier, so an arm below that meets a shape it
         * does not build can rewind and hand the whole statement to the
         * expression layer.  The ptr-array member store is the first user; the
         * prefix ++/-- arm makes the same move from its own checkpoint. */
        LexPeek m8_pk;
        int m8_line = g_cur.line, m8_col = g_cur.col;
        lex_peek_save(&m8_pk);
        next_tok();

        /* M8: '.field = expr;' (possibly chained 'a.in.x = ...') on
         * struct local/global (3b: build+walk). */
        if (g_cur.kind == TOK_DOT) {
            Local  *lc = locals_lookup(name_ptr, name_len);
            Global *gv = (lc == NULL) ? globals_lookup(name_ptr, name_len) : NULL;
            if (lc == NULL && gv == NULL) die(line, col, "undeclared");
            LocalType ct  = lc ? lc->type      : gv->type;
            int       sid = lc ? lc->struct_id : gv->struct_id;
            if (ct != LT_STRUCT)
                die(line, col, "'.' on non-struct");
            int    cum_off = 0;
            Field *leaf    = NULL;
            while (g_cur.kind == TOK_DOT) {
                next_tok();
                if (g_cur.kind != TOK_IDENT)
                    die(g_cur.line, g_cur.col, "field name");
                Field *f = field_lookup_dot(sid, g_cur.id_ptr, g_cur.id_len);
                if (f == NULL) die(g_cur.line, g_cur.col, "no such field");
                cum_off += f->byte_offset;
                sid  = f->struct_id;
                ct   = f->type;
                leaf = f;
                next_tok();
            }
            /* `structvar.structptrfield->...->field [op]= rhs` -- the dot
             * chain reached a struct-POINTER member, now an arrow chain (tcsh
             * sh.parse `alout.next->word = ...`).  Reuse S_CHAIN_STORE: its
             * emit does fpr_load_sym (a struct var's address) then derefs each
             * hop at hop->byte_offset, so the struct-ptr field is hop0 provided
             * cum_off == leaf->byte_offset (a SINGLE dot from the base -- the
             * only case where the accumulated offset equals the field's own). */
            if (leaf->type == LT_STRUCT_PTR && g_cur.kind == TOK_ARROW &&
                cum_off == leaf->byte_offset) {
                int hop0 = g_n_ast_fields, n_hops = 0;
                Field *f = leaf;
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
                }
                /* S_CHAIN_STORE stores a scalar, and its `op=' is one word
                 * wide.  An ELEMENT of an array leaf, a whole STRUCT leaf --
                 * which `=' copies -- and a long or float `op=' are the
                 * walker's; it builds all three, in any context. */
                if ((ISARY(f->type) && g_cur.kind == TOK_LBRACKET) ||
                    f->type == LT_STRUCT ||
                    ((f->type == LT_LONG || f->type == LT_FLOAT) &&
                     is_compound_op(g_cur.kind))) {
                    lex_peek_restore(&m8_pk);
                    return build_comma_expr_stmt(m8_line, m8_col);
                }
                require_assignable(f->type, g_cur.kind);
                if ((f->type == LT_CHAR_PTR || f->type == LT_INT_PTR ||
                     f->type == LT_VOID_PTR) && g_cur.kind == TOK_LBRACKET) {
                    next_tok();                    /* consume '[' */
                    int idx = ast_build_assign();
                    expect(TOK_RBRACKET, "']'");
                    expect(TOK_EQ, "'='");
                    int rhs = ast_build_assign();
                    expect(TOK_SEMI, "';'");
                    int n = ast_new(S_CHAIN_STORE, line, col);
                    g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                    g_ast[n].sym_f = f;
                    g_ast[n].kid0 = hop0; g_ast[n].n_kids = n_hops;
                    g_ast[n].flags = 1;   /* struct-VAR base -> addr */
                    g_ast[n].a = idx; g_ast[n].b = rhs;
                    return n;
                }
                if (is_compound_op(g_cur.kind)) {
                    TokKind op = g_cur.kind;
                    next_tok();
                    int rhs = ast_build_assign();
                    { int w = stmt_wide_opassign(op, rhs); if (w >= 0) return w; }
                    expect(TOK_SEMI, "';'");
                    int n = ast_new(S_CHAIN_STORE, line, col);
                    g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                    g_ast[n].sym_f = f;
                    g_ast[n].kid0 = hop0; g_ast[n].n_kids = n_hops;
                    g_ast[n].flags = 1;   /* struct-VAR base -> addr */
                    g_ast[n].op = op; g_ast[n].b = rhs;
                    return n;
                }
                expect(TOK_EQ, "'='");
                int rhs = ast_build_assign();
                expect(TOK_SEMI, "';'");
                int n = ast_new(S_CHAIN_STORE, line, col);
                g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                g_ast[n].sym_f = f;
                g_ast[n].kid0 = hop0; g_ast[n].n_kids = n_hops;
                    g_ast[n].flags = 1;   /* struct-VAR base -> addr */
                g_ast[n].b = rhs;
                return n;
            }
            /* `sv.m = <struct>' and `sv.o.m = <struct>' -- a struct-typed
             * leaf, which was refused outright.  apple/fgx#207's dot
             * spelling; N_ADDR_DOT_BARE is the same address-of node the
             * expression layer builds for `&sv.o.m', with val_hi carrying the
             * parent-chain offset the leaf's own byte_offset does not. */
            if (leaf->type == LT_STRUCT && leaf->struct_id >= 0 &&
                g_cur.kind == TOK_EQ) {
                int nbytes = g_structs[leaf->struct_id].total_size;
                int dst = ast_new(N_ADDR_DOT_BARE, line, col);
                g_ast[dst].sym_lc = lc; g_ast[dst].sym_gv = gv;
                g_ast[dst].sym_f = leaf;
                g_ast[dst].val_hi = (unsigned)(cum_off - leaf->byte_offset);
                g_ast[dst].type = LT_STRUCT_PTR;
                g_ast[dst].struct_id = leaf->struct_id;
                next_tok();                       /* consume '=' */
                int src = parse_struct_src();
                expect(TOK_SEMI, "';'");
                int n = ast_new(S_DSTORE_STRUCT_COPY, line, col);
                g_ast[n].a = dst; g_ast[n].b = src;
                g_ast[n].val = (unsigned)nbytes;
                return n;
            }
            if (leaf->type == LT_STRUCT)
                die(g_cur.line, g_cur.col,
                    "cannot assign to nested struct field (need scalar leaf)");

            /* `structvar.ptrfield[i] = rhs` -- store through a subscripted
             * POINTER member (tcsh ed.xmap `CurCmd.code[0] = ...`, code is
             * Char*).  Route through S_CHAIN_STORE's ->p[i] arm with a
             * struct-VAR address base (flags&1) and zero arrow hops: it
             * deref-loads the pointer field, scales the index, and stores.
             * Single-dot only (cum_off == leaf->byte_offset). */
            if ((leaf->type == LT_CHAR_PTR || leaf->type == LT_INT_PTR ||
                 leaf->type == LT_VOID_PTR) &&
                g_cur.kind == TOK_LBRACKET && cum_off == leaf->byte_offset) {
                next_tok();                    /* consume '[' */
                int idx = ast_build_assign();
                expect(TOK_RBRACKET, "']'");
                expect(TOK_EQ, "'='");
                int rhs = ast_build_assign();
                expect(TOK_SEMI, "';'");
                int n = ast_new(S_CHAIN_STORE, line, col);
                g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                g_ast[n].sym_f = leaf;
                g_ast[n].kid0 = g_n_ast_fields; g_ast[n].n_kids = 0;
                g_ast[n].flags = 1;            /* struct-VAR base -> address */
                g_ast[n].a = idx; g_ast[n].b = rhs;
                return n;
            }

            /* An ARRAY-OF-POINTERS member is an lvalue this arm does not
             * name and the EXPRESSION layer has built all along:
             * N_STORE_PTRARR_ELEM scales by four and finishes with
             * emit_fpr_deref_store_ptr.  `s.pa[i] = p;' as a STATEMENT died
             * "expected '='" -- an ARTIFICIAL reject of the apple/fgx#155
             * twin-arm kind, where the read side and the whole expression path
             * were already correct and only the statement spelling was missing.
             *
             * ROUTED, NOT DUPLICATED.  The M14 tail below stores through
             * emit_fpr_deref_store_word, which is TWO bytes -- a pointer
             * element would silently lose its bank, which is the far-pointer
             * bug class this tree has paid for more than once.  Rewinding to
             * the statement's first token and letting the expression layer
             * build it reuses the arm that already handles the four-byte
             * store, and is the same move the prefix ++/-- arm makes for the
             * shapes it does not name.
             *
             * Found writing ufs_inode.c's hash-chain init (UFS 1.11a):
             * `ihashtbl[i].ih_chain[0] = (struct inode *)&ihashtbl[i];'. */
            if (is_ptr_array(leaf->type) && g_cur.kind == TOK_LBRACKET) {
                lex_peek_restore(&m8_pk);
                return build_comma_expr_stmt(m8_line, m8_col);
            }

            /* M14-LHS: 'IDENT.arr_field[i] = expr' (+ '.subfield'). */
            if ((leaf->type == LT_CHAR_ARRAY  ||
                 leaf->type == LT_INT_ARRAY   ||
                 leaf->type == LT_LONG_ARRAY  ||
                 leaf->type == LT_FLOAT_ARRAY ||
                 leaf->type == LT_STRUCT_ARRAY) &&
                g_cur.kind == TOK_LBRACKET) {
                next_tok();   /* consume '[' */
                    int idx = ast_build_assign();
                expect(TOK_RBRACKET, "']'");
                Field *f2 = NULL;
                if (leaf->type == LT_STRUCT_ARRAY) {
                    if (g_cur.kind != TOK_DOT)
                        die(g_cur.line, g_cur.col,
                            "struct-array element LHS requires '.field'");
                    next_tok();
                    if (g_cur.kind != TOK_IDENT)
                        die(g_cur.line, g_cur.col, "field name");
                    f2 = field_lookup_dot(leaf->struct_id,
                                          g_cur.id_ptr, g_cur.id_len);
                    if (f2 == NULL)
                        die(g_cur.line, g_cur.col, "no such field");
                    next_tok();
                    /* A NON-SCALAR SUBFIELD IS ROUTED, NOT REFUSED.  This
                     * arm emits one store to a leaf it can address directly,
                     * so it names the leaf types it can emit -- but a subfield
                     * that is itself a struct is not an error, it is a run
                     * this arm has reached the end of.  K&R A.7.3.3: "A
                     * postfix expression followed by a dot followed by an
                     * identifier is a postfix expression ... The expression is
                     * an lvalue if the first expression is an lvalue, and if
                     * the type of the second expression is not an array type."
                     * The rule is RECURSIVE and carries no depth limit, so
                     * `gt.MA[i].L.v' is as good an lvalue as `gt.M.L.v', which
                     * this file already compiles.  apple/fgx#213.
                     *
                     * Routing rather than growing the arm is the same move the
                     * pointer-array and long/float-array cases above make, and
                     * for the same reason: the expression layer already walks a
                     * suffix run of any depth (the uniform lvalue-chain parser
                     * this file exports), which is why the READ of this exact
                     * lvalue has always compiled.  Growing a second walker here
                     * is what produced the fixed-shape arms apple/fgx#214 had
                     * to unpick -- three of them, each consuming a PREFIX of
                     * the run and returning.
                     *
                     * A STRUCT-VALUED LEAF IS ROUTED TOO, and that is only safe
                     * because the expression layer copies one rather than
                     * storing its first word.  It did not: `gt.MA[i].L = <s>'
                     * fell through the chain walker's word store and wrote two
                     * bytes of the source's ADDRESS into the member, silently,
                     * which routing here made reachable.  Fixed in the same
                     * branch (apple/fgx#259, the LT_STRUCT arms of
                     * N_LV_STORE_E and the chain read); the fixture is
                     * tests/M37/arrelemstructstore.c.  If those arms are ever
                     * removed this routing has to narrow with them. */
                    if (f2->type != LT_CHAR && f2->type != LT_INT &&
                        f2->type != LT_INT_PTR && f2->type != LT_CHAR_PTR &&
                        f2->type != LT_VOID_PTR) {
                        lex_peek_restore(&m8_pk);
                        return build_comma_expr_stmt(m8_line, m8_col);
                    }
                }
                /* correctness queue 2b: op= on array-field elements
                 * (s.la[i] += v — the field twin of f_acompound). */
                TokKind cop = TOK_EOF;
                int rhs;
                /* `s.a[i]++' DESUGARS TO `s.a[i] += 1', apple/fgx#394.
                 *
                 * K&R A.7.17 (p.169) supplies the equivalence -- "An
                 * expression of the form E1 op= E2 is equivalent to
                 * E1 = E1 op (E2) except that E1 is evaluated only once" --
                 * and A.7.3.4 says `++' increments "by 1".  In STATEMENT
                 * context the value of the postfix expression is discarded, so
                 * `E++;' and `++E;' and `E += 1;' have the same effect, which
                 * is what makes the rewrite exact rather than approximate.
                 *
                 * This is the file's own idiom, not a new one: the prefix
                 * arms above already desugar `++s.f' and `++p->f' into the
                 * node their `op=' arm builds.  Reusing the store node is also
                 * what keeps the element ADDRESS arithmetic in one place --
                 * base + field offset + index*stride is computed by the arm
                 * below and nothing here needs to know it. */
                /* A POINTER leaf's `++' and `op=' step by the pointee's size
                 * (A.7.7), which this node's word RMW does not do; the walker
                 * scales them, so they go there rather than being refused. */
                require_assignable(f2 ? f2->type : DECREF(leaf->type),
                                   g_cur.kind);
                if (f2 != NULL && f2->type != LT_CHAR && f2->type != LT_INT &&
                    g_cur.kind != TOK_EQ) {
                    lex_peek_restore(&m8_pk);
                    return build_comma_expr_stmt(m8_line, m8_col);
                }
                if (g_cur.kind == TOK_PLUSPLUS || g_cur.kind == TOK_MINUSMINUS) {
                    cop = (g_cur.kind == TOK_PLUSPLUS) ? TOK_PLUSEQ
                                                       : TOK_MINUSEQ;
                    next_tok();
                    expect(TOK_SEMI, "';'");
                    rhs = ast_new(N_LIT_INT, line, col);
                    g_ast[rhs].val = 1;
                    g_ast[rhs].type = LT_INT;
                } else {
                    if (is_compound_op(g_cur.kind)) {
                        cop = g_cur.kind;
                        next_tok();
                    } else {
                        expect(TOK_EQ, "'='");
                    }
                    rhs = ast_build_assign();
                    { int w = stmt_wide_opassign(cop, rhs); if (w >= 0) return w; }
                    expect(TOK_SEMI, "';'");
                }
                int n = ast_new(S_STORE_DOT_ARRFIELD, line, col);
                g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                g_ast[n].sym_f = leaf; g_ast[n].sym_f2 = f2;
                g_ast[n].op = cop;
                g_ast[n].val = (unsigned)cum_off;
                g_ast[n].val_hi = (unsigned)elem_size_for(leaf->type,
                                                          leaf->struct_id);
                g_ast[n].a = idx; g_ast[n].b = rhs;
                return n;
            }

            require_assignable(leaf->type, g_cur.kind);
            if (is_compound_op(g_cur.kind)) {
                TokKind op = g_cur.kind;
                next_tok();
                    int rhs = ast_build_assign();
                expect(TOK_SEMI, "';'");
                { int w = stmt_wide_opassign(op, rhs); if (w >= 0) return w; }
                int n = ast_new(S_COMPOUND_DOTFIELD, line, col);
                g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                g_ast[n].sym_f = leaf;
                g_ast[n].val = (unsigned)cum_off;
                g_ast[n].op = op;
                g_ast[n].a = rhs;
                return n;
            }
            expect(TOK_EQ, "'='");
            int rhs = ast_build_assign();
            expect(TOK_SEMI, "';'");
            int n = ast_new(N_STORE_DOTFIELD, line, col);
            g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
            g_ast[n].sym_f = leaf;
            g_ast[n].val = (unsigned)cum_off;
            g_ast[n].a = rhs;
            g_ast[n].type = leaf->type;
            return n;
        }

        /* M8: '->field = expr;' on struct pointer (3b: build+walk). */
        if (g_cur.kind == TOK_ARROW) {
            Local  *lc = locals_lookup(name_ptr, name_len);
            Global *gv = (lc == NULL) ? globals_lookup(name_ptr, name_len) : NULL;
            if (lc == NULL && gv == NULL) die(line, col, "undeclared");
            LocalType ct = lc ? lc->type      : gv->type;
            int       sid = lc ? lc->struct_id : gv->struct_id;
            next_tok();                        /* consume '->' */
            if (g_cur.kind != TOK_IDENT)
                die(g_cur.line, g_cur.col, "field name");
            Field *f;
            if (ct == LT_STRUCT_PTR) {
                f = struct_field_lookup(sid, g_cur.id_ptr, g_cur.id_len);
                if (f == NULL) die(g_cur.line, g_cur.col, "no such field");
            } else if (ISPTR(ct)) {
                /* K&R global-member pun (A.7.3, 1st ed): `->` on a NON-struct
                 * pointer -- the base value is a byte address and the member
                 * resolves in the global namespace.  2.11BSD /bin/sh:
                 * `np->doluse` (np a STRING* == char**, doluse a dolnod field),
                 * `args->argnxt` (args a STRING == char*, argnxt an argnod
                 * field).  Proceed as if the base were (member's-struct *). */
                int csid = -1;
                f = field_lookup_global(g_cur.id_ptr, g_cur.id_len, &csid);
                if (f == NULL) die(g_cur.line, g_cur.col, "no such field");
                sid = csid;
            } else {
                die(line, col, "'->' on non-pointer");
            }
            next_tok();

            /* '->structfield = <struct lvalue>' -- WHOLE-STRUCT assignment
             * to an inline struct member.  apple/fgx#207.
             *
             * SILENT BEFORE THIS, and that is the whole reason it is here.
             * With no arm for it the statement fell through to the scalar
             * store below: the RHS struct decayed to its ADDRESS and two bytes
             * of that address were written over the member's first word.  Not
             * a short copy -- the wrong data entirely.  Found by 2.11BSD
             * tty.c's ttychars(), `tp->t_chars = ttydefaults;', where the
             * fourteen special characters of every new tty line arrived as the
             * low half of a symbol address.
             *
             * K&R A.7.3.3 is what makes it a legal lvalue at all: of `E1->MOS'
             * it says "The value is the named member of the object to which
             * E1 points ... The value is an lvalue if E1 is an lvalue" -- and
             * the object, not its first word, is what A.7.17 then says the
             * assignment replaces ("the value of the expression replaces that
             * of the object referred to by the lvalue ... both operands are
             * structures or unions of the same type").  Nothing in either
             * clause conditions the copy on how the lvalue was spelled.
             *
             * NOTHING NEW IS EMITTED.  `*(&p->m) = g' already compiled to the
             * correct DEY/BPL copy loop, so the machinery was complete and
             * only this spelling did not reach it: N_ADDR_ARROW_BARE for the
             * destination and S_DSTORE_STRUCT_COPY for the copy, exactly as
             * the `*pd = ps' path builds them.
             *
             * THE RHS is parse_struct_src's, the set every struct-copy site
             * in this file accepts: `*ps', a struct variable, a member run
             * of any depth, or any other struct-valued expression. */
            if (f->type == LT_STRUCT && g_cur.kind == TOK_EQ &&
                f->struct_id >= 0) {
                int nbytes = g_structs[f->struct_id].total_size;
                int dst = ast_new(N_ADDR_ARROW_BARE, line, col);
                g_ast[dst].sym_lc = lc; g_ast[dst].sym_gv = gv;
                g_ast[dst].sym_f = f;
                g_ast[dst].type = LT_STRUCT_PTR;
                g_ast[dst].struct_id = f->struct_id;
                next_tok();                          /* consume '=' */
                int src = parse_struct_src();
                expect(TOK_SEMI, "';'");
                int n = ast_new(S_DSTORE_STRUCT_COPY, line, col);
                g_ast[n].a = dst; g_ast[n].b = src;
                g_ast[n].val = (unsigned)nbytes;
                return n;
            }

            /* '->structfield.sub([i])? = rhs' — inline struct/union VALUE. */
            if (f->type == LT_STRUCT && g_cur.kind == TOK_DOT) {
                int    cum  = f->byte_offset;
                int    sid2 = f->struct_id;
                Field *leaf = f;
                for (;;) {
                    next_tok();                    /* consume '.' */
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
                    /* INDEXED ARRAY LEAF: `p->structfield.arr[i] = rhs`.
                     *
                     * LONG AND FLOAT ELEMENTS WERE AN ARTIFICIAL REJECT, which
                     * is the same finding the 4-byte SCALAR arm below records
                     * about itself -- and the same pairs rule as apple/fgx#155.
                     * K&R A.7.3.3 makes `p->arr` a non-lvalue because it IS an
                     * array ("the result is an lvalue if the type is not an
                     * array type"), so the subscript decays it and the store
                     * goes through A.7.4.3's indirection: "is an lvalue if the
                     * operand is a pointer to an object of arithmetic,
                     * structure, union, or pointer type."  NOTHING in either
                     * paragraph conditions that on the ELEMENT type -- long is
                     * an arithmetic type exactly as int and char are -- so
                     * accepting two of the three had no basis in the text.
                     *
                     * Found writing UFS 1.12b's itrunc: `oip->i_addr[NDADDR +
                     * level] = 0`, where i_addr is 2.11BSD's on-disk daddr_t
                     * array and the shape is the format's, not a choice about
                     * how to write the port.
                     *
                     * STRUCT-typed elements are still refused.  A.7.4.3's list
                     * admits them, so that is a real remaining gap rather than
                     * a rule -- but it needs a copy, not a store, and there is
                     * no caller for it in this tree. */
                    if ((lt == LT_CHAR_ARRAY || lt == LT_INT_ARRAY ||
                     lt == LT_LONG_ARRAY || lt == LT_FLOAT_ARRAY) &&
                    g_cur.kind == TOK_LBRACKET) {
                    next_tok();                    /* consume '[' */
                    int idx = ast_build_assign();
                    expect(TOK_RBRACKET, "']'");
                    expect(TOK_EQ, "'='");
                    int rhs = ast_build_assign();
                    expect(TOK_SEMI, "';'");
                    int n = ast_new(S_AV_STORE, line, col);
                    g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                    g_ast[n].sym_f = leaf;
                    g_ast[n].val = (unsigned)cum;
                    g_ast[n].a = idx; g_ast[n].b = rhs;
                    return n;
                }
                if (lt == LT_INT || lt == LT_CHAR) {
                    expect(TOK_EQ, "'='");
                    int rhs = ast_build_assign();
                    expect(TOK_SEMI, "';'");
                    int n = ast_new(S_AV_STORE, line, col);
                    g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                    g_ast[n].sym_f = leaf;
                    g_ast[n].val = (unsigned)cum;
                    g_ast[n].b = rhs;
                    return n;
                }
                if (lt == LT_LONG || lt == LT_FLOAT) {
                    /* 4-BYTE SCALAR LEAF: `p->structfield.longfield = rhs`.
                     * Was an artificial reject -- the DOT-chain twin
                     * (S_STORE_DOT_ARRFIELD) has stored longs and floats all
                     * along, and only the arrow-then-dot spelling was missing.
                     * apple/fgx#155's pairs rule again.
                     *
                     * Found writing UFS 1.11a's on-disk inode decode:
                     * `dp->di_icom1.ic_size = ufs_dget32(b, 8);` -- ic_size is
                     * off_t, and the icommon1/icommon2 grouping it sits in is
                     * 4.3BSD-Reno's own inode layout, so the shape is not
                     * avoidable by writing the port differently. */
                    expect(TOK_EQ, "'='");
                    int rhs = ast_build_assign();
                    expect(TOK_SEMI, "';'");
                    int n = ast_new(S_AV_STORE, line, col);
                    g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                    g_ast[n].sym_f = leaf;
                    g_ast[n].val = (unsigned)cum;
                    g_ast[n].b = rhs;
                    g_ast[n].type = leaf->type;   /* mark the WIDTH for emit */
                    return n;
                }
                if (ISPTR(lt)) {
                    /* pointer leaf: `p->structfield.ptrfield = rhs` -- store a
                     * 4-byte pointer (offset + bank) at base + cum (tcsh sh.hist
                     * `np->Hlex.next = lp->next`).  S_AV_STORE's pointer arm
                     * mirrors N_STORE_PTRARR_ELEM's fpr deref-store-ptr. */
                    expect(TOK_EQ, "'='");
                    int rhs = ast_build_assign();
                    expect(TOK_SEMI, "';'");
                    int n = ast_new(S_AV_STORE, line, col);
                    g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                    g_ast[n].sym_f = leaf;
                    g_ast[n].val = (unsigned)cum;
                    g_ast[n].b = rhs;
                    g_ast[n].type = leaf->type;   /* mark ptr leaf for the emit */
                    return n;
                }
                /* `p->o.m = <struct>' -- the arrow-then-dot twin of the
                 * dot arm above, and of `p->m = <struct>' one hop in.
                 * apple/fgx#155's pairs rule: this file has three spellings
                 * of the same lvalue and they were fixed one at a time until
                 * the matrix showed the whole row. */
                if (lt == LT_STRUCT && leaf->struct_id >= 0 &&
                    g_cur.kind == TOK_EQ) {
                    int nbytes = g_structs[leaf->struct_id].total_size;
                    int dst = ast_new(N_ADDR_ARROW_BARE, line, col);
                    g_ast[dst].sym_lc = lc; g_ast[dst].sym_gv = gv;
                    g_ast[dst].sym_f = leaf;
                    g_ast[dst].val_hi = (unsigned)(cum - leaf->byte_offset);
                    g_ast[dst].type = LT_STRUCT_PTR;
                    g_ast[dst].struct_id = leaf->struct_id;
                    next_tok();                   /* consume '=' */
                    int src = parse_struct_src();
                    expect(TOK_SEMI, "';'");
                    int n = ast_new(S_DSTORE_STRUCT_COPY, line, col);
                    g_ast[n].a = dst; g_ast[n].b = src;
                    g_ast[n].val = (unsigned)nbytes;
                    return n;
                }
                die(g_cur.line, g_cur.col,
                    "'->struct-member.field' store: only int/char scalar, a "
                    "pointer, or an int/char array-element supported");
            }

            /* G22 store chain: `a->b->...->c [op]= rhs` (+ G32 `...->p[i] = rhs`). */
            if (f->type == LT_STRUCT_PTR && g_cur.kind == TOK_ARROW) {
                    int hop0 = g_n_ast_fields;
                int n_hops = 0;
                while (f->type == LT_STRUCT_PTR && g_cur.kind == TOK_ARROW) {
                    int next_sid = f->struct_id;
                    if (g_n_ast_fields >= MAX_AST_KIDS)
                        die(g_cur.line, g_cur.col, "arrow-chain hop pool overflow");
                    g_ast_fields[g_n_ast_fields++] = f; n_hops++;
                    next_tok();   /* consume '->' */
                    if (g_cur.kind != TOK_IDENT)
                        die(g_cur.line, g_cur.col,
                            "expected field name after '->'");
                    f = struct_field_lookup(next_sid, g_cur.id_ptr, g_cur.id_len);
                    if (f == NULL) die(g_cur.line, g_cur.col, "no such field");
                    next_tok();
                }
                /* S_CHAIN_STORE stores a scalar, and its `op=' is one word
                 * wide.  An ELEMENT of an array leaf, a whole STRUCT leaf --
                 * which `=' copies -- and a long or float `op=' are the
                 * walker's; it builds all three, in any context. */
                if ((ISARY(f->type) && g_cur.kind == TOK_LBRACKET) ||
                    f->type == LT_STRUCT ||
                    ((f->type == LT_LONG || f->type == LT_FLOAT) &&
                     is_compound_op(g_cur.kind))) {
                    lex_peek_restore(&m8_pk);
                    return build_comma_expr_stmt(m8_line, m8_col);
                }
                require_assignable(f->type, g_cur.kind);
                if ((f->type == LT_CHAR_PTR || f->type == LT_INT_PTR ||
                     f->type == LT_VOID_PTR) && g_cur.kind == TOK_LBRACKET) {
                    next_tok();                                /* consume '[' */
                    int idx = ast_build_assign();
                    expect(TOK_RBRACKET, "']'");
                    expect(TOK_EQ, "'='");
                    int rhs = ast_build_assign();
                    expect(TOK_SEMI, "';'");
                    int n = ast_new(S_CHAIN_STORE, line, col);
                    g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                    g_ast[n].sym_f = f;
                    g_ast[n].kid0 = hop0; g_ast[n].n_kids = n_hops;
                    g_ast[n].a = idx; g_ast[n].b = rhs;
                    return n;
                }
                if (is_compound_op(g_cur.kind)) {
                    TokKind op = g_cur.kind;
                    next_tok();
                    int rhs = ast_build_assign();
                    { int w = stmt_wide_opassign(op, rhs); if (w >= 0) return w; }
                    expect(TOK_SEMI, "';'");
                    int n = ast_new(S_CHAIN_STORE, line, col);
                    g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                    g_ast[n].sym_f = f;
                    g_ast[n].kid0 = hop0; g_ast[n].n_kids = n_hops;
                    g_ast[n].op = op;
                    g_ast[n].b = rhs;
                    return n;
                }
                expect(TOK_EQ, "'='");
                int rhs = ast_build_assign();
                expect(TOK_SEMI, "';'");
                int n = ast_new(S_CHAIN_STORE, line, col);
                g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                g_ast[n].sym_f = f;
                g_ast[n].kid0 = hop0; g_ast[n].n_kids = n_hops;
                g_ast[n].b = rhs;
                return n;
            }

            /* M14-LHS: 'ptr->arr_field[i](.sub)? = expr'. */
            if ((f->type == LT_CHAR_ARRAY  ||
                 f->type == LT_INT_ARRAY   ||
                 f->type == LT_LONG_ARRAY  ||
                 f->type == LT_FLOAT_ARRAY ||
                 f->type == LT_STRUCT_ARRAY ||
                 is_ptr_array(f->type)) &&
                g_cur.kind == TOK_LBRACKET) {
                next_tok();   /* consume '[' */
                    int idx = ast_build_assign();
                expect(TOK_RBRACKET, "']'");
                Field *f2 = NULL;
                if (f->type == LT_STRUCT_ARRAY) {
                    if (g_cur.kind != TOK_DOT)
                        die(g_cur.line, g_cur.col,
                            "struct-array element LHS requires '.field'");
                    next_tok();
                    if (g_cur.kind != TOK_IDENT)
                        die(g_cur.line, g_cur.col, "field name");
                    f2 = field_lookup_dot(f->struct_id,
                                          g_cur.id_ptr, g_cur.id_len);
                    if (f2 == NULL)
                        die(g_cur.line, g_cur.col, "no such field");
                    next_tok();
                    /* A NON-SCALAR SUBFIELD IS ROUTED, NOT REFUSED.  This
                     * arm emits one store to a leaf it can address directly,
                     * so it names the leaf types it can emit -- but a subfield
                     * that is itself a struct is not an error, it is a run
                     * this arm has reached the end of.  K&R A.7.3.3: "A
                     * postfix expression followed by a dot followed by an
                     * identifier is a postfix expression ... The expression is
                     * an lvalue if the first expression is an lvalue, and if
                     * the type of the second expression is not an array type."
                     * The rule is RECURSIVE and carries no depth limit, so
                     * `gt.MA[i].L.v' is as good an lvalue as `gt.M.L.v', which
                     * this file already compiles.  apple/fgx#213.
                     *
                     * Routing rather than growing the arm is the same move the
                     * pointer-array and long/float-array cases above make, and
                     * for the same reason: the expression layer already walks a
                     * suffix run of any depth (the uniform lvalue-chain parser
                     * this file exports), which is why the READ of this exact
                     * lvalue has always compiled.  Growing a second walker here
                     * is what produced the fixed-shape arms apple/fgx#214 had
                     * to unpick -- three of them, each consuming a PREFIX of
                     * the run and returning.
                     *
                     * A STRUCT-VALUED LEAF IS ROUTED TOO, and that is only safe
                     * because the expression layer copies one rather than
                     * storing its first word.  It did not: `gt.MA[i].L = <s>'
                     * fell through the chain walker's word store and wrote two
                     * bytes of the source's ADDRESS into the member, silently,
                     * which routing here made reachable.  Fixed in the same
                     * branch (apple/fgx#259, the LT_STRUCT arms of
                     * N_LV_STORE_E and the chain read); the fixture is
                     * tests/M37/arrelemstructstore.c.  If those arms are ever
                     * removed this routing has to narrow with them. */
                    if (f2->type != LT_CHAR && f2->type != LT_INT &&
                        f2->type != LT_INT_PTR && f2->type != LT_CHAR_PTR &&
                        f2->type != LT_VOID_PTR) {
                        lex_peek_restore(&m8_pk);
                        return build_comma_expr_stmt(m8_line, m8_col);
                    }
                }
                /* correctness queue 2b: op= on array-field elements
                 * (p->la[i] += v — arrow twin of the dot path above). */
                TokKind cop = TOK_EOF;
                int rhs;
                /* `p->a[i]++' DESUGARS TO `p->a[i] += 1' -- the dot arm's twin,
                 * carrying its reasoning (apple/fgx#394).  Written as a pair
                 * deliberately: an arm added to one spelling and not the other
                 * is the shape apple/fgx#155, #170, #314 and #393 each cost a
                 * session to find. */
                require_assignable(f2 ? f2->type : DECREF(f->type), g_cur.kind);
                if ((is_ptr_array(f->type) ||
                     (f2 != NULL && f2->type != LT_CHAR &&
                      f2->type != LT_INT)) &&
                    g_cur.kind != TOK_EQ) {
                    lex_peek_restore(&m8_pk);     /* pointer leaf: walker */
                    return build_comma_expr_stmt(m8_line, m8_col);
                }
                if (g_cur.kind == TOK_PLUSPLUS || g_cur.kind == TOK_MINUSMINUS) {
                    cop = (g_cur.kind == TOK_PLUSPLUS) ? TOK_PLUSEQ
                                                       : TOK_MINUSEQ;
                    next_tok();
                    expect(TOK_SEMI, "';'");
                    rhs = ast_new(N_LIT_INT, line, col);
                    g_ast[rhs].val = 1;
                    g_ast[rhs].type = LT_INT;
                } else {
                    if (is_compound_op(g_cur.kind)) {
                        cop = g_cur.kind;
                        next_tok();
                    } else {
                        expect(TOK_EQ, "'='");
                    }
                    rhs = ast_build_assign();
                    { int w = stmt_wide_opassign(cop, rhs); if (w >= 0) return w; }
                    expect(TOK_SEMI, "';'");
                }
                int n = ast_new(S_STORE_ARROW_ARRFIELD, line, col);
                g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                g_ast[n].sym_f = f; g_ast[n].sym_f2 = f2;
                g_ast[n].op = cop;
                g_ast[n].val_hi = (unsigned)elem_size_for(f->type, f->struct_id);
                g_ast[n].a = idx; g_ast[n].b = rhs;
                return n;
            }

            /* G25: `ptr->p[i] = rhs` (p a char/int/void ptr field). */
            if ((f->type == LT_CHAR_PTR || f->type == LT_INT_PTR ||
                 f->type == LT_VOID_PTR) &&
                g_cur.kind == TOK_LBRACKET) {
                next_tok();   /* consume '[' */
                    int idx = ast_build_assign();
                expect(TOK_RBRACKET, "']'");
                if (g_cur.kind != TOK_EQ) {      /* op= and ++/--: walker */
                    lex_peek_restore(&m8_pk);
                    return build_comma_expr_stmt(m8_line, m8_col);
                }
                expect(TOK_EQ, "'='");
                int rhs = ast_build_assign();
                expect(TOK_SEMI, "';'");
                int n = ast_new(S_STORE_PTRFIELD_IDX, line, col);
                g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                g_ast[n].sym_f = f;
                g_ast[n].a = idx; g_ast[n].b = rhs;
                return n;
            }

            /* CU-1: single- or double-subscript LHS through a
             * pointer-to-pointer member — `p->y[a] = <ptr rhs>;` /
             * `p->y[a][b] (op)= rhs;` / `p->y[a][b]++;` (y a char **
             * or int ** field).  Same nodes the desugared
             * `*(p->y + a) = rhs` / `*(p->y[a] + b) = rhs` build:
             * N_ARROW_LOAD_CHAIN (-> N_IPV_READ) -> N_ADD_PPLUSI into
             * the shared tail. */
            if (ISPTR(f->type) && ISPTR(DECREF(f->type)) &&
                g_cur.kind == TOK_LBRACKET) {
                next_tok();                     /* consume '[' */
                int idx = ast_build_assign();
                expect(TOK_RBRACKET, "']'");
                /* Single subscript: the element IS the far pointer, so
                 * this is a 4-byte store at p->y + a*4 (the subscript
                 * scales by the element's far-ptr stride; a 2-byte
                 * store would corrupt the bank byte) — the tail's
                 * S_DSTORE_GENERAL ISPTR-target arm.  deleteln.c /
                 * newwin.c `win->_y[y] = ...`. */
                if (g_cur.kind != TOK_LBRACKET) {
                    int ch1 = ast_new(N_ARROW_LOAD_CHAIN, line, col);
                    g_ast[ch1].sym_lc = lc; g_ast[ch1].sym_gv = gv;
                    g_ast[ch1].kid0 = g_n_ast_fields; g_ast[ch1].n_kids = 0;
                    g_ast[ch1].sym_f = f;
                    g_ast[ch1].type = f->type;
                    g_ast[ch1].struct_id = f->struct_id;
                    g_ast[ch1].is_unsigned = f->is_unsigned;
                    int addr1 = ast_new(N_ADD_PPLUSI, line, col);
                    g_ast[addr1].a = ch1; g_ast[addr1].b = idx;
                    g_ast[addr1].val =
                        (unsigned)elem_size_for(f->type, f->struct_id);
                    g_ast[addr1].type = f->type;
                    g_ast[addr1].struct_id = f->struct_id;
                    g_ast[addr1].is_unsigned = g_ast[idx].is_unsigned;
                    return cu1_dsub_store_tail(addr1, f->type,
                                               f->is_unsigned, line, col);
                }
                next_tok();                     /* consume 2nd '[' */
                int idx2 = ast_build_assign();
                expect(TOK_RBRACKET, "']'");
                LocalType ety = DECREF(f->type);    /* p->y[a]'s type */
                int ch = ast_new(N_ARROW_LOAD_CHAIN, line, col);
                g_ast[ch].sym_lc = lc; g_ast[ch].sym_gv = gv;
                g_ast[ch].kid0 = g_n_ast_fields; g_ast[ch].n_kids = 0;
                g_ast[ch].sym_f = f;
                g_ast[ch].type = f->type;
                g_ast[ch].struct_id = f->struct_id;
                g_ast[ch].is_unsigned = f->is_unsigned;
                int rd = ast_new(N_IPV_READ, line, col);
                g_ast[rd].a = ch; g_ast[rd].b = idx;
                g_ast[rd].val = (unsigned)ipv_elem_size(f->type);
                g_ast[rd].val_hi = (unsigned)f->type;
                g_ast[rd].type = ety;
                int addr = ast_new(N_ADD_PPLUSI, line, col);
                g_ast[addr].a = rd; g_ast[addr].b = idx2;
                g_ast[addr].val =
                    (unsigned)elem_size_for(ety, g_ast[rd].struct_id);
                g_ast[addr].type = ety;
                g_ast[addr].is_unsigned = g_ast[idx2].is_unsigned;
                return cu1_dsub_store_tail(addr, ety, f->is_unsigned,
                                           line, col);
            }

            require_assignable(f->type, g_cur.kind);
            /* G31: postfix '++'/'--' on a scalar/pointer field (stmt ctx). */
            if (g_cur.kind == TOK_PLUSPLUS || g_cur.kind == TOK_MINUSMINUS) {
                int is_inc = (g_cur.kind == TOK_PLUSPLUS);
                int st = elem_size_for(f->type, f->struct_id);
                if (st == 0) st = 1;
                next_tok();
                expect(TOK_SEMI, "';'");
                    int n = ast_new(S_MEMBER_INCDEC_STMT, line, col);
                g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                g_ast[n].sym_f = f;
                g_ast[n].val = (unsigned)st;
                g_ast[n].flags = is_inc ? AF_IS_INC : 0;
                return n;
            }
            if (is_compound_op(g_cur.kind)) {
                TokKind op = g_cur.kind;
                next_tok();
                    int rhs = ast_build_assign();
                expect(TOK_SEMI, "';'");
                { int w = stmt_wide_opassign(op, rhs); if (w >= 0) return w; }
                int n = ast_new(S_COMPOUND_MEMBER, line, col);
                g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                g_ast[n].sym_f = f;
                g_ast[n].op = op;
                g_ast[n].a = rhs;
                return n;
            }
            expect(TOK_EQ, "'='");
            int rhs = ast_build_assign();
            expect(TOK_SEMI, "';'");
            int n = ast_new(N_STORE_MEMBER, line, col);
            g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
            g_ast[n].sym_f = f;
            g_ast[n].a = rhs;
            g_ast[n].type = f->type;
            return n;
        }

        if (is_compound_op(g_cur.kind)) {
            TokKind op = g_cur.kind;
            next_tok();
            Local  *lc = locals_lookup(name_ptr, name_len);
            Global *gv = (lc == NULL) ? globals_lookup(name_ptr, name_len) : NULL;
            if (lc == NULL && gv == NULL) {
                char buf[64];
                snprintf(buf, sizeof buf, "'%.*s' undeclared",
                         name_len, name_ptr);
                die(line, col, buf);
            }
            require_assignable(lc ? lc->type : gv->type, op);
            int rhs = ast_build_assign();
            /* CU-3: `flags |= 1, x = 2;` — comma-expression statement;
             * the node built here is the same one the expression layer's
             * build_ident_assign_tail makes, so the chain walks as a
             * plain discarded expression. */
            if (g_cur.kind == TOK_COMMA) {
                int st = ast_new(N_COMPOUND_VAR, line, col);
                g_ast[st].sym_lc = lc; g_ast[st].sym_gv = gv;
                g_ast[st].op = op; g_ast[st].a = rhs;
                g_ast[st].type = lc ? lc->type : gv->type;
                g_ast[st].is_unsigned = lc ? lc->is_unsigned
                                           : gv->is_unsigned;
                return cu3_comma_stmt_tail(st);
            }
            expect(TOK_SEMI, "';'");
            int n = ast_new(N_COMPOUND_VAR, line, col);
            g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
            g_ast[n].op = op; g_ast[n].a = rhs;
            g_ast[n].type = lc ? lc->type : gv->type;
            g_ast[n].is_unsigned = lc ? lc->is_unsigned : gv->is_unsigned;
            return n;
        }

        if (g_cur.kind == TOK_EQ) {
            Local  *lc = locals_lookup(name_ptr, name_len);
            Global *gv = (lc == NULL) ? globals_lookup(name_ptr, name_len) : NULL;
            if (lc == NULL && gv == NULL) {
                char buf[64];
                snprintf(buf, sizeof buf, "'%.*s' undeclared",
                         name_len, name_ptr);
                die(line, col, buf);
            }
            LocalType lhs_t   = lc ? lc->type      : gv->type;
            int       lhs_sid = lc ? lc->struct_id : gv->struct_id;
            require_assignable(lhs_t, TOK_EQ);
            /* `sv = t, ...;' -- the struct copy below ends at its `;', so a
             * comma statement is the expression layer's, which copies too. */
            if (lhs_t == LT_STRUCT && stmt_has_top_comma()) {
                lex_peek_restore(&m8_pk);
                return build_comma_expr_stmt(m8_line, m8_col);
            }
            if (lhs_t == LT_STRUCT && lhs_sid >= 0) {
                /* whole-struct assignment: `sv = *ps;` / `sv = sv2;` */
                int nbytes = g_structs[lhs_sid].total_size;
                next_tok();                  /* consume '=' */
                    int dst = ast_new(N_VAR_LOAD, line, col);   /* walk = &sv */
                g_ast[dst].sym_lc = lc; g_ast[dst].sym_gv = gv;
                g_ast[dst].type = LT_STRUCT;
                g_ast[dst].struct_id = lhs_sid;
                int src = parse_struct_src();
                expect(TOK_SEMI, "';'");
                int n = ast_new(S_DSTORE_STRUCT_COPY, line, col);
                g_ast[n].a = dst; g_ast[n].b = src;
                g_ast[n].val = (unsigned)nbytes;
                return n;
            }
            next_tok();
            int rhs = ast_build_assign();
            /* CU-3: `y = cy, x = cx;` — comma-expression statement
             * (curses.h getyx).  Expression-flavor N_STORE_VAR (value =
             * RHS descriptor, as build_ident_assign_tail makes it) so
             * the tree is identical to the working parenthesized form;
             * the plain no-comma statement below is untouched. */
            if (g_cur.kind == TOK_COMMA) {
                int st = ast_new(N_STORE_VAR, line, col);
                g_ast[st].sym_lc = lc; g_ast[st].sym_gv = gv;
                g_ast[st].a = rhs;
                g_ast[st].type        = g_ast[rhs].type;
                g_ast[st].struct_id   = g_ast[rhs].struct_id;
                g_ast[st].is_unsigned = g_ast[rhs].is_unsigned;
                g_ast[st].fn_sig      = g_ast[rhs].fn_sig;
                return cu3_comma_stmt_tail(st);
            }
            expect(TOK_SEMI, "';'");
            int n = ast_new(N_STORE_VAR, line, col);
            g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
            g_ast[n].a = rhs;
            ast_copy_desc(n, rhs);
            ast_store_conv(n, g_ast[n].sym_lc, g_ast[n].sym_gv);
            return n;
        }

        if (g_cur.kind == TOK_LBRACKET) {
            next_tok();                 /* consume '[' */
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
            if (atype == LT_STRUCT_ARRAY) {
                /* pts[i](.field...)? — element address, then store forms. */
                int es = elem_size_for(atype, asid);
                    int idx = ast_build_assign();
                expect(TOK_RBRACKET, "']'");
                int base = ast_new(N_ELEM_ADDR, line, col);
                g_ast[base].sym_lc = lc; g_ast[base].sym_gv = gv;
                g_ast[base].a = idx; g_ast[base].val = 0;
                g_ast[base].val_hi = (unsigned)es;
                g_ast[base].type = LT_STRUCT_PTR;
                g_ast[base].struct_id = asid;
                /* Whole-struct element copy: `arr[i] = <struct lvalue>;` */
                if (g_cur.kind == TOK_EQ) {
                    if (asid < 0)
                        die(g_cur.line, g_cur.col, "struct copy on non-struct array");
                    int nbytes = g_structs[asid].total_size;   /* already even */
                    next_tok();                   /* consume '=' */
                    int src;
                    if (g_cur.kind == TOK_STAR) {
                        next_tok();
                        src = ast_build_unary();  /* `*ps` */
                    } else if (g_cur.kind == TOK_IDENT) {
                        const char *rn = g_cur.id_ptr;
                        int         rl = g_cur.id_len;
                        Local  *rlc = locals_lookup(rn, rl);
                        Global *rgv = rlc ? NULL : globals_lookup(rn, rl);
                        LocalType rt = rlc ? rlc->type : (rgv ? rgv->type : LT_INT);
                        int rsid = rlc ? rlc->struct_id : (rgv ? rgv->struct_id : -1);
                        next_tok();               /* consume RHS name */
                        if (g_cur.kind == TOK_LBRACKET && rt == LT_STRUCT_ARRAY) {
                            next_tok();           /* consume '[' */
                            int res = elem_size_for(rt, rsid);
                            int ridx = ast_build_assign();
                            expect(TOK_RBRACKET, "']'");
                            src = ast_new(N_ELEM_ADDR, g_cur.line, g_cur.col);
                            g_ast[src].sym_lc = rlc; g_ast[src].sym_gv = rgv;
                            g_ast[src].a = ridx; g_ast[src].val = 0;
                            g_ast[src].val_hi = (unsigned)res;
                            g_ast[src].type = LT_STRUCT_PTR;
                            g_ast[src].struct_id = rsid;
                        } else if (rt == LT_STRUCT) {
                            src = ast_new(N_VAR_LOAD, g_cur.line, g_cur.col);
                            g_ast[src].sym_lc = rlc; g_ast[src].sym_gv = rgv;
                            g_ast[src].type = LT_STRUCT;
                            g_ast[src].struct_id = rsid;
                        } else {
                            die(g_cur.line, g_cur.col,
                                "struct copy RHS must be a struct lvalue");
                        }
                    } else {
                        die(g_cur.line, g_cur.col,
                            "struct copy RHS must be a struct lvalue");
                    }
                    expect(TOK_SEMI, "';'");
                    int n = ast_new(S_DSTORE_STRUCT_COPY, line, col);
                    g_ast[n].a = base; g_ast[n].b = src;
                    g_ast[n].val = (unsigned)nbytes;
                    return n;
                }
                if (g_cur.kind != TOK_DOT)
                    die(g_cur.line, g_cur.col,
                        "struct-array indexed store requires '.field'");
                next_tok();
                if (g_cur.kind != TOK_IDENT)
                    die(g_cur.line, g_cur.col, "field name");
                Field *f = field_lookup_dot(asid, g_cur.id_ptr, g_cur.id_len);
                if (f == NULL) die(g_cur.line, g_cur.col, "no such field");
                next_tok();
                /* A RUN OF DOTS PAST THE ELEMENT -- `vs[0].u.num = 0',
                 * apple/fgx#314, and the STORE twin of the reader in
                 * build_struct_elem_access.
                 *
                 * K&R A.7.3.3 (p.163): "A postfix expression followed by a dot
                 * followed by an identifier IS a postfix expression", and it
                 * "is an lvalue if the first expression is an lvalue, and if
                 * the type of the second expression is not an array type".
                 * `vs[0]' is an lvalue and `u' is a union, so `vs[0].u' is an
                 * lvalue and may precede another dot -- and may therefore be
                 * assigned through.
                 *
                 * THE FOLD IS THE READER'S, so the two halves cannot drift: a
                 * chain collapses to one synthetic leaf at the accumulated
                 * offset, and every arm below -- the scalar store, the
                 * compound ops, the ++/--, the whole-struct copy -- reads that
                 * leaf's `byte_offset' and is already correct at any depth.
                 * The whole-struct arm keeps its `=' into `base.val' rather
                 * than a `+=' precisely because the leaf's offset is already
                 * cumulative. */
                if (f->type == LT_STRUCT && g_cur.kind == TOK_DOT) {
                    int cum = f->byte_offset, sid = f->struct_id;
                    Field *f2 = f;
                    for (;;) {
                        next_tok();                /* consume '.' */
                        if (g_cur.kind != TOK_IDENT)
                            die(g_cur.line, g_cur.col, "field name");
                        f2 = field_lookup_dot(sid, g_cur.id_ptr, g_cur.id_len);
                        if (f2 == NULL)
                            die(g_cur.line, g_cur.col, "no such field");
                        next_tok();
                        cum += f2->byte_offset;
                        sid = f2->struct_id;
                        if (f2->type == LT_STRUCT && g_cur.kind == TOK_DOT)
                            continue;
                        break;
                    }
                    f = elem_synth_leaf(f2->type, cum, f2->struct_id,
                                        f2->is_unsigned);
                }
                /* THE TWIN of the ptr-array routing above, and the fixture
                 * found it: fixing `s.pa[i] = p;' left `arr[k].pa[i] = p;'
                 * still dying "expected '='", which is the SAME shape one hop
                 * further out and the exact spelling ufs_inode.c's hash
                 * initialiser uses.  apple/fgx#155's lesson is that fcc has
                 * twin arms for most lvalue shapes and they have to be fixed in
                 * pairs; this pair was found by a test that asserted values
                 * rather than by reading. */
                /* apple/fgx#170's store twin.  EVERY ARRAY MEMBER but the two
                 * the arm below builds goes the same way as the pointer arrays
                 * above -- long, float, and an array of structs whose element
                 * the run then selects from (`arr[i].sa[j].n = v') -- and so
                 * does a POINTER member subscripted (`arr[i].p[j] = v').  The
                 * expression layer walks all of them and this arm does not,
                 * so routing is both smaller and the thing that keeps the
                 * spellings emitting the same code.  A type LIST here is what
                 * failed twice: each omission was an artificial reject,
                 * "expected '='", while the plain-base spelling compiled. */
                if (g_cur.kind == TOK_LBRACKET &&
                    ((ISARY(f->type) && f->type != LT_CHAR_ARRAY &&
                      f->type != LT_INT_ARRAY) || ISPTR(f->type))) {
                    lex_peek_restore(&m8_pk);
                    return build_comma_expr_stmt(m8_line, m8_col);
                }
                /* M21+: arr[i].field[j] = expr when field is char/int array. */
                if (g_cur.kind == TOK_LBRACKET &&
                    (f->type == LT_CHAR_ARRAY ||
                     f->type == LT_INT_ARRAY)) {
                    next_tok();   /* consume '[' */
                    int j = ast_build_assign();
                    expect(TOK_RBRACKET, "']'");
                    /* ANYTHING BUT `=' IS ROUTED, NOT REFUSED (apple/fgx#394).
                     * This node carries no operator, so `vs[0].w[1] += 1' and
                     * `vs[0].w[1]++' met its `expect(TOK_EQ)' and died
                     * "expected `='" -- while the same two spellings on a
                     * plain or arrow base compiled.  Routing is the move the
                     * long/float/pointer arm directly above already makes, and
                     * the file's reason for preferring it holds here: the
                     * expression layer walks a suffix run of any depth, so
                     * routing keeps one emitter rather than growing a second
                     * that has to agree with it. */
                    if (g_cur.kind != TOK_EQ) {
                        lex_peek_restore(&m8_pk);
                        return build_comma_expr_stmt(m8_line, m8_col);
                    }
                    expect(TOK_EQ, "'='");
                    int rhs = ast_build_assign();
                    expect(TOK_SEMI, "';'");
                    int n = ast_new(S_SARR_FIELD_IDX, line, col);
                    g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                    g_ast[n].sym_f = f;
                    g_ast[n].a = base; g_ast[n].b = j; g_ast[n].c = rhs;
                    return n;
                }
                require_assignable(f->type, g_cur.kind);
                /* A LONG or FLOAT member's `op=' and `++' are 32 bits wide,
                 * and the element-at nodes below read-modify-write one word;
                 * the walker's are full width, so they go there. */
                if ((f->type == LT_LONG || f->type == LT_FLOAT) &&
                    (is_compound_op(g_cur.kind) ||
                     g_cur.kind == TOK_PLUSPLUS || g_cur.kind == TOK_MINUSMINUS)) {
                    lex_peek_restore(&m8_pk);
                    return build_comma_expr_stmt(m8_line, m8_col);
                }
                /* G31 twin: postfix ++/-- on the element's field. */
                if (g_cur.kind == TOK_PLUSPLUS || g_cur.kind == TOK_MINUSMINUS) {
                    int is_inc = (g_cur.kind == TOK_PLUSPLUS);
                    int st = elem_size_for(f->type, f->struct_id);
                    if (st == 0) st = 1;
                    next_tok();
                    expect(TOK_SEMI, "';'");
                    int n = ast_new(S_FIELD_INCDEC_AT, line, col);
                    g_ast[n].sym_f = f;
                    g_ast[n].a = base;
                    g_ast[n].val = (unsigned)st;
                    g_ast[n].flags = is_inc ? AF_IS_INC : 0;
                    return n;
                }
                if (is_compound_op(g_cur.kind)) {
                    TokKind op = g_cur.kind;
                    next_tok();
                    int rhs = ast_build_assign();
                    expect(TOK_SEMI, "';'");
                    { int w = stmt_wide_opassign(op, rhs); if (w >= 0) return w; }
                    int n = ast_new(S_FIELD_COMPOUND_AT, line, col);
                    g_ast[n].sym_f = f;
                    g_ast[n].a = base; g_ast[n].op = op; g_ast[n].b = rhs;
                    return n;
                }
                /* `arr[i].m = <struct>' -- A STRUCT-TYPED FIELD, and without
                 * this arm it fell into the SCALAR store below and wrote two
                 * bytes of the source's address over the member.  Silently.
                 * apple/fgx#207 one hop further out than `p->m = <struct>':
                 * the twin the comment above this block predicts, found the
                 * same way and by the same matrix.
                 *
                 * N_ELEM_ADDR ALREADY CARRIES THE OFFSET.  Its emitter adds
                 * `val' as a constant and then the scaled index, so setting
                 * val to the member's byte offset makes the node the address
                 * of arr[i].m rather than of arr[i] -- no new node, and the
                 * two addends commute so the order does not matter. */
                if (f->type == LT_STRUCT && f->struct_id >= 0 &&
                    g_cur.kind == TOK_EQ) {
                    int nbytes = g_structs[f->struct_id].total_size;
                    g_ast[base].val = (unsigned)f->byte_offset;
                    g_ast[base].struct_id = f->struct_id;
                    next_tok();                   /* consume '=' */
                    int src = parse_struct_src();
                    expect(TOK_SEMI, "';'");
                    int n = ast_new(S_DSTORE_STRUCT_COPY, line, col);
                    g_ast[n].a = base; g_ast[n].b = src;
                    g_ast[n].val = (unsigned)nbytes;
                    return n;
                }
                /* A STRUCT-TYPED FIELD MUST NOT REACH THE SCALAR STORE BELOW.
                 * Everything past this point writes two bytes, so anything
                 * left that is a whole struct is refused rather than
                 * mis-stored -- the arm above takes `=', and a compound
                 * operator on a struct has no meaning to fall through to. */
                if (f->type == LT_STRUCT)
                    die(g_cur.line, g_cur.col,
                        "only `=' is defined on a whole struct field");
                expect(TOK_EQ, "'='");
                int rhs = ast_build_assign();
                expect(TOK_SEMI, "';'");
                int n = ast_new(S_FIELD_STORE_AT, line, col);
                g_ast[n].sym_f = f;
                g_ast[n].a = base; g_ast[n].b = rhs;
                return n;
            }
            /* M10/M19/M21: int/char/long/float N-D array or pointer target. */
            {
                int sa_n_dims = lc ? lc->n_dims : gv->n_dims;
                int is_ptr_target = (atype == LT_CHAR_PTR ||
                                     atype == LT_INT_PTR  ||
                                     atype == LT_VOID_PTR ||
                                     atype == LT_LONG_PTR ||
                                     atype == LT_FLOAT_PTR ||
                                     (ISPTR(atype) && ISPTR(DECREF(atype))));
                    int tmp[MAX_DIMS];
                int cnt = 0;
                tmp[cnt++] = ast_build_assign();
                expect(TOK_RBRACKET, "']'");
                while (g_cur.kind == TOK_LBRACKET && cnt < sa_n_dims) {
                    next_tok();
                    if (cnt >= MAX_DIMS)
                        die(g_cur.line, g_cur.col, "too many subscripts");
                    tmp[cnt++] = ast_build_assign();
                    expect(TOK_RBRACKET, "']'");
                }
                if (cnt < sa_n_dims) {
                    /* Fewer subscripts than dimensions leave a ROW, and a row
                     * is an array (K&R A.8.6.2), which no assignment operator
                     * may target. */
                    require_assignable(atype, g_cur.kind);
                    die(g_cur.line, g_cur.col,
                        "partial-decay store not supported (need full index chain)");
                }
                if (g_n_ast_kids + cnt > MAX_AST_KIDS)
                    die(line, col, "index kid pool overflow");
                int kid0 = g_n_ast_kids;
                for (int i2 = 0; i2 < cnt; i2++) g_ast_kids[g_n_ast_kids++] = tmp[i2];
                /* CU-1: double-subscript LHS through a pointer-typed
                 * element — `yy[a][b] (op)= rhs;` / `yy[a][b]++;` where
                 * yy[a] itself yields a pointer.  Build the rvalue read of
                 * yy[a] (the expression path's N_ARR_READ shape), pointer-add
                 * the second index (N_ADD_PPLUSI — the `yy[a] + b` node), and
                 * finish with the shared deref-store tail.
                 *
                 * Both spellings qualify, and for the same reason: `yy[a]` is
                 * a pointer whether yy is `T **yy` (PTR of PTR) or `T *yy[N]`
                 * (ARY of PTR).  The array form used to fall through to the
                 * plain '=' expectation and die "expected '='" -- an ARTIFICIAL
                 * reject, since the READ side (`c = p[i][0]`) already built
                 * exactly this chain and the store tail is type-driven.  Found
                 * writing bigfork's `p[i][0] = 'A'` (2026-08-02).  Function-
                 * pointer arrays are excluded: `fp[i][j]` is not a thing (same
                 * carve-out as the expression path's ptr-array arm). */
                if (g_cur.kind == TOK_LBRACKET && cnt == 1 &&
                    ((ISPTR(atype) && ISPTR(DECREF(atype))) ||
                     (is_ptr_array(atype) && DECREF(atype) != LT_FN_PTR))) {
                    LocalType ety = DECREF(atype);     /* yy[a]'s type */
                    next_tok();                        /* consume 2nd '[' */
                    int idx2 = ast_build_assign();
                    expect(TOK_RBRACKET, "']'");
                    int base = ast_new(N_ARR_READ, line, col);
                    g_ast[base].sym_lc = lc; g_ast[base].sym_gv = gv;
                    g_ast[base].kid0 = kid0; g_ast[base].n_kids = 1;
                    g_ast[base].type = ety;
                    g_ast[base].struct_id = lc
                        ? lc->struct_id
                        : ((BTYPE(DECREF(ety)) == BT_STRUCT) ? gv->struct_id
                                                             : -1);
                    g_ast[base].fn_sig = lc ? lc->fn_sig_id : gv->fn_sig_id;
                    int addr = ast_new(N_ADD_PPLUSI, line, col);
                    g_ast[addr].a = base; g_ast[addr].b = idx2;
                    g_ast[addr].val =
                        (unsigned)elem_size_for(ety, g_ast[base].struct_id);
                    g_ast[addr].type = ety;
                    g_ast[addr].struct_id = g_ast[base].struct_id;
                    g_ast[addr].is_unsigned = g_ast[idx2].is_unsigned;
                    return cu1_dsub_store_tail(addr, ety,
                                               lc ? lc->is_unsigned
                                                  : gv->is_unsigned,
                                               line, col);
                }
                /* T5-C C5: arr[i]++ / arr[i]-- as a STATEMENT — reuse the
                 * expression node (yield discarded), same single-subscript
                 * int/char-array scope as the expression arm.  Was an
                 * artificial reject ("expected '='"). */
                if ((g_cur.kind == TOK_PLUSPLUS ||
                     g_cur.kind == TOK_MINUSMINUS) &&
                    cnt == 1 && !is_ptr_target &&
                    (atype == LT_INT_ARRAY || atype == LT_CHAR_ARRAY)) {
                    int is_inc = (g_cur.kind == TOK_PLUSPLUS);
                    next_tok();
                    expect(TOK_SEMI, "';'");
                    int n = ast_new(N_ARR_POSTINC, line, col);
                    g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                    g_ast[n].a = g_ast_kids[kid0];
                    g_ast[n].flags = ((atype == LT_CHAR_ARRAY) ? AF_IS_BYTE : 0) |
                                     (is_inc ? AF_IS_INC : 0);
                    g_ast[n].type = (atype == LT_CHAR_ARRAY) ? LT_CHAR : LT_INT;
                    return n;
                }
                /* Every other `++'/`--' after a subscript run -- `m[i][j]++',
                 * a long or pointer element -- is the walker's, which types
                 * each subscript of a multi-dimensional base. */
                if (g_cur.kind == TOK_PLUSPLUS || g_cur.kind == TOK_MINUSMINUS) {
                    lex_peek_restore(&m8_pk);
                    return build_comma_expr_stmt(m8_line, m8_col);
                }
                TokKind op = TOK_EOF;
                if (is_compound_op(g_cur.kind)) {
                    op = g_cur.kind;
                    next_tok();
                } else {
                    expect(TOK_EQ, "'='");
                }
                int rhs = ast_build_assign();
                { int w = stmt_wide_opassign(op, rhs); if (w >= 0) return w; }
                expect(TOK_SEMI, "';'");
                int n = ast_new(S_ARR_STORE, line, col);
                g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                g_ast[n].kid0 = kid0; g_ast[n].n_kids = cnt;
                g_ast[n].op = op; g_ast[n].b = rhs;
                g_ast[n].flags = is_ptr_target ? AF_EL_PTR : 0;
                return n;
            }
        }

        if (g_cur.kind == TOK_PLUSPLUS || g_cur.kind == TOK_MINUSMINUS) {
            int is_inc = (g_cur.kind == TOK_PLUSPLUS);
            next_tok();                    /* consume '++'/'--' */
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
            if (g_cur.kind == TOK_COMMA) {
                /* IDENT++ , ... — comma-operator statement (telnet's
                 * `sbp++, scc--`).  Build IDENT++ as an EXPRESSION (value
                 * discarded) and chain the rest via cu3_comma_stmt_tail. */
                int est = elem_size_for(lc ? lc->type : gv->type,
                                        lc ? lc->struct_id : gv->struct_id);
                if (est == 0) est = 1;
                int first = ast_new(lc ? N_POSTINC_LOCAL : N_POSTINC_GLOBAL,
                                    line, col);
                g_ast[first].sym_lc = lc; g_ast[first].sym_gv = gv;
                g_ast[first].val = (unsigned)est;
                g_ast[first].flags = is_inc ? AF_IS_INC : 0;
                g_ast[first].type = lc ? lc->type : gv->type;
                g_ast[first].struct_id = lc ? lc->struct_id : gv->struct_id;
                g_ast[first].is_unsigned = lc ? lc->is_unsigned : gv->is_unsigned;
                g_ast[first].fn_sig = -1;
                return cu3_comma_stmt_tail(first);
            }
            expect(TOK_SEMI, "';'");
            int st = 1;
            if (lc != NULL && lc->type != LT_INT && lc->type != LT_CHAR) {
                st = elem_size_for(lc->type, lc->struct_id);
                if (st == 0) st = 1;
            } else if (gv != NULL && ISPTR(gv->type)) {
                st = ptr_stride(gv->type);
                if (st == 0)
                    st = (BTYPE(gv->type) == BT_STRUCT && gv->struct_id >= 0)
                        ? ((g_structs[gv->struct_id].total_size + 1) & ~1)
                        : 1;
            } else if (gv != NULL && gv->type != LT_LONG &&
                       gv->type != LT_INT && gv->type != LT_CHAR &&
                       gv->type != LT_FLOAT && !IS_QUAD(gv->type)) {
                die(line, col,
                    "global ++/-- at stmt: only int/char/long/float supported");
            }
            int n = ast_new(S_POSTINC_VAR_STMT, line, col);
            g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
            g_ast[n].val = (unsigned)st;
            g_ast[n].flags = is_inc ? AF_IS_INC : 0;
            return n;
        }

        if (g_cur.kind == TOK_LPAREN) {
            /* setjmp / longjmp builtins at statement level (3b: reuse the
             * expression nodes — emission identical, result discarded). */
            {
                int sj_set  = (name_len == 6 && memcmp(name_ptr, "setjmp",  6) == 0);
                int sj_long = (name_len == 7 && memcmp(name_ptr, "longjmp", 7) == 0);
                if (sj_set || sj_long) {
                    next_tok();                   /* consume '(' */
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
                            int env = ast_build_assign();
                    if (sj_set) {
                        expect(TOK_RPAREN, "')' after setjmp(env)");
                        expect(TOK_SEMI, "';'");
                        int n = ast_new(N_SETJMP, line, col);
                        g_ast[n].a = env;
                        g_ast[n].type = LT_INT;
                        return n;
                    }
                    expect(TOK_COMMA, "',' in longjmp(env, val)");
                    int val = ast_build_assign();
                    expect(TOK_RPAREN, "')' after longjmp(env, val)");
                    expect(TOK_SEMI, "';'");
                    int n = ast_new(N_LONGJMP, line, col);
                    g_ast[n].a = env; g_ast[n].b = val;
                    g_ast[n].type = LT_INT;
                    return n;              /* call-shaped: don't elide */
                }
            }
            if (name_len == 5 && memcmp(name_ptr, "__asm", 5) == 0) {
                /* T5-C C4b: __asm("line", ...) — the verbatim asm escape
                 * hatch (statement position ONLY).  Contract: enter/leave
                 * M=16/X=16; preserve S/D/DBR; A/X/Y are yours; @-local
                 * labels only (a leading '@' emits at column 1, everything
                 * else gets the op indent); reference non-static globals /
                 * lib cells by symbol — locals and static globals are the
                 * compiler's business (stage them in cells first).  The
                 * emitted ;__ASM..;__ASM_END markers make the peephole
                 * treat every line as an opaque barrier. */
                next_tok();                       /* consume '(' */
                int kid0 = g_n_ast_kids, cnt = 0;
                for (;;) {
                    if (g_cur.kind != TOK_STR_LIT)
                        die(g_cur.line, g_cur.col,
                            "__asm: expected a string-literal asm line");
                    if (g_n_ast_kids >= MAX_AST_KIDS)
                        die(line, col, "call-arg kid pool overflow");
                    int ln = ast_new(N_LIT_STR, g_cur.line, g_cur.col);
                    g_ast[ln].name     = g_cur.str_ptr;   /* interned */
                    g_ast[ln].name_len = g_cur.str_len;
                    g_ast_kids[g_n_ast_kids++] = ln; cnt++;
                    next_tok();
                    if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
                    break;
                }
                expect(TOK_RPAREN, "')'");
                expect(TOK_SEMI, "';'");
                int n = ast_new(S_ASM, line, col);
                g_ast[n].kid0 = kid0; g_ast[n].n_kids = cnt;
                g_ast[n].type = LT_VOID;
                return n;
            }
            {   /* T5-C C1: __syscall builtin family (stmt: result in A,
                 * discarded — pulls are inline, no cleanup needed). */
                int n = build_syscall_builtin(name_ptr, name_len, line, col);
                if (n >= 0) {
                    expect(TOK_SEMI, "';'");
                    return n;
                }
            }
            /* M18: indirect call via fn-ptr (stmt context, result discarded). */
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
                    next_tok();
                            int kid0, n_kids;
                    ast_build_call_args(&kid0, &n_kids);
                    expect(TOK_RPAREN, "')'");
                    expect(TOK_SEMI, "';'");
                    int n = ast_new(N_CALL_FPVAR, line, col);
                    g_ast[n].sym_lc = fp_lc; g_ast[n].sym_gv = fp_gv;
                    g_ast[n].val = (unsigned)fp_sig;
                    g_ast[n].kid0 = kid0; g_ast[n].n_kids = n_kids;
                    g_ast[n].type = g_fn_sigs[fp_sig].return_type;
                    g_ast[n].is_unsigned = g_fn_sigs[fp_sig].ret_unsigned;   /* A-1 */
                    g_ast[n].flags = AF_STMT_DISCARD;
                    return n;
                }
            }
            int fn_idx = funcs_lookup(name_ptr, name_len);
            if (fn_idx < 0) {
                /* K&R implicit declaration (statement context). */
                warn_implicit_decl(name_ptr, name_len, line, col);
                fn_idx = funcs_declare(name_ptr, name_len, 0, line, col);
                g_funcs[fn_idx].return_type = LT_INT;
                g_funcs[fn_idx].is_variadic = 1;
                g_funcs[fn_idx].is_extern   = 1;
            }
            int expected_argc = g_funcs[fn_idx].n_params;
            next_tok();  /* consume '(' */

            /* T5-C C5: the printf family is an ordinary variadic call — the
             * pile exports plain names and fcc emits the plain source name;
             * the linker resolves user-def-over-pile (Stage A archive model). */
            int kid0, n_kids;
            ast_build_call_args(&kid0, &n_kids);
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
                /* K&R under-supplied call (stmt context): pad missing params
                 * with 0 — telnet's printoption(dir,fmt,opt) vs 4-param def. */
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
            int n = ast_new(N_CALL_NAMED, line, col);
            g_ast[n].val = (unsigned)fn_idx;
            g_ast[n].name = name_ptr; g_ast[n].name_len = name_len;
            g_ast[n].kid0 = kid0; g_ast[n].n_kids = n_kids;
            g_ast[n].type = g_funcs[fn_idx].return_type;
            g_ast[n].struct_id = g_funcs[fn_idx].return_struct_id;
            g_ast[n].is_unsigned = g_funcs[fn_idx].ret_unsigned;
            /* A postfix chain on the call RESULT: `f(x)->m = v;' / `f(x)[i]++;'.
             * K&R A.7.1 makes `.'/`->'/`[]' one left-to-right postfix production
             * with a primary on the left, and a call IS a primary -- but this
             * arm went straight to the ';' and the statement died there, so the
             * whole shape was reachable only inside parentheses.  2.11BSD sh
             * compiles at all because its attrib() is spelled `(n->namflg |= f)'.
             * Hand the call node to the expression layer's chain builder, which
             * already serves the same run in value position. */
            if (g_cur.kind == TOK_ARROW || g_cur.kind == TOK_LBRACKET) {
                int e = build_postfix_value_chain(n);
                expect(TOK_SEMI, "';'");
                int s = ast_new(S_EXPR, line, col);
                g_ast[s].a = e;
                return s;
            }
            expect(TOK_SEMI, "';'");
            g_ast[n].flags = AF_STMT_DISCARD;
            return n;
        }

        die(line, col, "expected '=' or '(' after identifier");
    }

    /* G20: parenthesized expression statement, e.g. stevie's `CLEAROP;`
     * macro = `(operator = NOP);`.  The dispatcher above special-cases
     * IDENT-/STAR-/'++'-led statements; a statement that begins with '('
     * falls through to here.  Parse a full (comma-level) expression and
     * discard its value in A — side effects (the inner assignment) are
     * already emitted by the expression layer. */
    if (g_cur.kind == TOK_LPAREN) {
        /* G21: parenthesized-lvalue assignment, e.g. stevie's
         *   `P(P_SS) = expr;`  where  #define P(n) (params[n].value)
         * expands to `(params[P_SS].value) = expr;`.  A '('-led statement
         * is normally a parenthesized expression statement (G20, below),
         * but `( <lvalue> ) = rhs;` must STORE, not load.
         *
         * The classifier is a TOKEN walk over the whole-TU vector: g_cur is
         * the '(' and g_tok_idx is the first inner token; find the matching
         * ')' and classify by the token after it.  (Increment 1 replaced the
         * old char-scan + synthetic-frame re-feed — token rewinds could not
         * cross a macro frame before the token vector existed.) */
        int wi = g_tok_idx, wdepth = 1, jclose = -1;
        while (g_toks[wi].kind != TOK_EOF) {
            TokKind wk = g_toks[wi].kind;
            if (wk == TOK_LPAREN) wdepth++;
            else if (wk == TOK_RPAREN && --wdepth == 0) { jclose = wi; break; }
            wi++;
        }
        if (jclose >= 0) {
            int ai = jclose + 1;
            while (g_toks[ai].kind == TOK_SKIP) ai++;
            TokKind after = g_toks[ai].kind;
            /* G21: `( <lvalue> ) = rhs;` / `( <lvalue> ) op= rhs;` — splice
             * the wrapper ')' out of the stream (TOK_SKIP) and re-dispatch:
             * the store handlers then see `<lvalue> = rhs ;` exactly as the
             * un-parenthesized form (identical codegen). */
            if (after == TOK_EQ || is_compound_op(after)) {
                g_toks[jclose].kind = TOK_SKIP;
                next_tok();                     /* prime: first inner token */
                g_paren_lvalue_skip_label = 1;  /* inner is never a label */
                return build_stmt();            /* lvalue + '= rhs ;' */
            }
            /* Uniform lvalue walker: `(ptr-expr)->chain [op]= rhs;` /
             * `(ptr-expr)->chain ++/--;` -- a COMPUTED pointer base whose first
             * access is `->` (so the parenthesized thing must be a pointer),
             * then a store.  No per-shape handler covers this and it does not
             * collide with the parenthesized-lvalue cases (which start `.`/`[`
             * on an aggregate) -- tcsh alloc11 `(q + nw)->ptr = allocx`.  Peek
             * past the `.`/`->`/`[..]` run to the operator; a store or ++/--
             * routes through the uniform lvalue path. */
            if (after == TOK_ARROW) {
                int ci = ai;
                for (;;) {
                    TokKind ck = g_toks[ci].kind;
                    if (ck == TOK_SKIP) { ci++; continue; }   /* spliced ')' */
                    if (ck == TOK_ARROW || ck == TOK_DOT) { ci += 2; continue; }
                    if (ck == TOK_LBRACKET) {
                        int d = 1; ci++;
                        while (d && g_toks[ci].kind != TOK_EOF) {
                            if (g_toks[ci].kind == TOK_LBRACKET) d++;
                            else if (g_toks[ci].kind == TOK_RBRACKET) d--;
                            ci++;
                        }
                        continue;
                    }
                    break;
                }
                TokKind fin = g_toks[ci].kind;
                int is_st  = (fin == TOK_EQ || is_compound_op(fin));
                int is_id  = (fin == TOK_PLUSPLUS || fin == TOK_MINUSMINUS);
                if (is_st || is_id) {
                    int line = g_cur.line, col = g_cur.col;
                    next_tok();                 /* consume '(' */
                    int base = ast_build_assign();   /* the pointer expression */
                    expect(TOK_RPAREN, "')'");
                    LocalType bt = g_ast[base].type;
                    if (!ISPTR(bt))
                        die(line, col, "computed lvalue base must be a pointer");
                    int head = ast_new(N_LV_CHAIN, line, col);
                    g_ast[head].c = base;        /* computed base */
                    build_lvalue_suffixes(head, DECREF(bt), g_ast[base].struct_id);
                    if (is_id) {
                        int is_inc = (g_cur.kind == TOK_PLUSPLUS);
                        next_tok();
                        expect(TOK_SEMI, "';'");
                        int n = ast_new(S_LV_INCDEC, line, col);
                        g_ast[n].a = head;
                        g_ast[n].flags = is_inc ? AF_IS_INC : 0;
                        return n;
                    }
                    /* raw token: TOK_EQ (plain) or a compound op= that
                     * emit_binop_for_compound maps directly. */
                    TokKind op = g_cur.kind;
                    next_tok();                  /* consume '=' / 'op=' */
                    int rhs = ast_build_assign();
                    expect(TOK_SEMI, "';'");
                    { int w = stmt_wide_opassign(op, rhs); if (w >= 0) return w; }
                    int n = ast_new(S_LV_STORE, line, col);
                    g_ast[n].a = head;
                    g_ast[n].op = op;
                    g_ast[n].c = rhs;
                    return n;
                }
            }
            /* `(base).chain [op]= rhs;` -- a '.' member on a parenthesized base.
             * When base is a non-struct pointer, '.' is the K&R 1st-ed global
             * pun (A.7.3 p.164) aliasing the base's OWN storage (no deref): the
             * 2.11BSD Bourne Lcheat macro, Lcheat(a) == ((a)._cheat), so
             * `Lcheat(gchain) |= ARGMK` splices its wrapper ')' (G21 above) and
             * re-dispatches to `(gchain)._cheat |= 01`.  A '.' needs the base's
             * ADDRESS, so only a simple `( IDENT )` base is handled (address =
             * &IDENT via the NAMED walker base); build_lvalue_suffixes resolves
             * the member globally and, for '.', does not deref.  K&R A.7.17. */
            if (after == TOK_DOT &&
                g_toks[g_tok_idx].kind == TOK_IDENT &&
                g_toks[g_tok_idx + 1].kind == TOK_RPAREN) {
                int ci = ai;
                for (;;) {
                    TokKind ck = g_toks[ci].kind;
                    if (ck == TOK_SKIP) { ci++; continue; }
                    if (ck == TOK_ARROW || ck == TOK_DOT) { ci += 2; continue; }
                    if (ck == TOK_LBRACKET) {
                        int d = 1; ci++;
                        while (d && g_toks[ci].kind != TOK_EOF) {
                            if (g_toks[ci].kind == TOK_LBRACKET) d++;
                            else if (g_toks[ci].kind == TOK_RBRACKET) d--;
                            ci++;
                        }
                        continue;
                    }
                    break;
                }
                TokKind fin = g_toks[ci].kind;
                if (fin == TOK_EQ || is_compound_op(fin)) {
                    int line = g_cur.line, col = g_cur.col;
                    next_tok();                     /* consume '(' -> g_cur=IDENT */
                    const char *bn = g_cur.id_ptr;
                    int         bl = g_cur.id_len;
                    Local  *blc = locals_lookup(bn, bl);
                    Global *bgv = (blc == NULL) ? globals_lookup(bn, bl) : NULL;
                    if (blc || bgv) {
                        LocalType bt   = blc ? blc->type      : bgv->type;
                        int       bsid = blc ? blc->struct_id : bgv->struct_id;
                        next_tok();                 /* consume base IDENT */
                        expect(TOK_RPAREN, "')'");  /* close the base paren */
                        int head = ast_new(N_LV_CHAIN, line, col);
                        g_ast[head].c = -1;         /* named base -> &IDENT */
                        g_ast[head].sym_lc = blc; g_ast[head].sym_gv = bgv;
                        build_lvalue_suffixes(head, bt, bsid);
                        TokKind op = g_cur.kind;    /* TOK_EQ or op= */
                        next_tok();
                        int rhs = ast_build_assign();
                        expect(TOK_SEMI, "';'");
                        { int w = stmt_wide_opassign(op, rhs); if (w >= 0) return w; }
                        int n = ast_new(S_LV_STORE, line, col);
                        g_ast[n].a = head; g_ast[n].op = op; g_ast[n].c = rhs;
                        return n;
                    }
                }
            }
            /* `((computed-lvalue).chain) [op]= rhs;` -- the '.' member on a
             * COMPUTED (non-IDENT) parenthesized base, e.g. the Bourne shell's
             * Lcheat((--p)->word) == (((--p)->word)._cheat).  The grouping paren
             * around the computed lvalue is redundant ('.' binds to the tail
             * postfix), so splice its ')' out (as G21 does) and re-dispatch:
             * `((--p)->word)._cheat &= x` becomes `(--p)->word._cheat &= x`,
             * which the '('-led ARROW computed-base path handles (with the '.'
             * pun resolved by build_lvalue_suffixes).  K&R A.7.2/A.7.3/A.7.17. */
            else if (after == TOK_DOT) {
                int ci = ai;
                for (;;) {
                    TokKind ck = g_toks[ci].kind;
                    if (ck == TOK_SKIP) { ci++; continue; }
                    if (ck == TOK_ARROW || ck == TOK_DOT) { ci += 2; continue; }
                    if (ck == TOK_LBRACKET) {
                        int d = 1; ci++;
                        while (d && g_toks[ci].kind != TOK_EOF) {
                            if (g_toks[ci].kind == TOK_LBRACKET) d++;
                            else if (g_toks[ci].kind == TOK_RBRACKET) d--;
                            ci++;
                        }
                        continue;
                    }
                    break;
                }
                TokKind fin = g_toks[ci].kind;
                if (fin == TOK_EQ || is_compound_op(fin)) {
                    g_toks[jclose].kind = TOK_SKIP;   /* strip the grouping ')' */
                    next_tok();                       /* prime: first inner token */
                    g_paren_lvalue_skip_label = 1;
                    return build_stmt();
                }
            }
            /* G41: postfix `( *ptr )++` / `( *ptr )--` — increment/decrement
             * the deref LVALUE, e.g. stevie's get_range:  `(*cp)++;`  where
             * cp is char**.  NOTE `(*cp)++` is NOT `*cp++`: the former bumps
             * `*cp` (the char* that cp points to), the latter bumps cp — so
             * the parens cannot be stripped to reach the *p++ path.  Parse
             * the inner as exactly `* IDENT` to obtain &(*ptr) == ptr's
             * value, then emit a deref-RMW: load [ptr], ±stride, store
             * [ptr].  The trailing `++`/`--` must NOT reach the expression
             * parser, which would greedily bind it to the inner IDENT as
             * `ptr++`. */
            if (after == TOK_PLUSPLUS || after == TOK_MINUSMINUS) {
                /* `( p->f )++` / `( x )++` / `( a[i] )++` — postfix '++'/'--'
                 * binds looser than '->'/'[]'/a primary, so the wrapper parens
                 * are strippable (UNLIKE `(*p)++`, which is NOT `*p++`).  When
                 * the inner lvalue is IDENT-led, splice the wrapper ')' out
                 * (TOK_SKIP) and re-dispatch: the store/incdec handlers then see
                 * `p->f++ ;` exactly as the un-parenthesized form (tcsh sh.exec
                 * `(sp->word)++;`).  A '*'-led inner keeps the deref-RMW path. */
                if (g_toks[g_tok_idx].kind == TOK_IDENT) {
                    g_toks[jclose].kind = TOK_SKIP;
                    next_tok();                 /* prime: first inner token */
                    g_paren_lvalue_skip_label = 1;
                    return build_stmt();
                }
                next_tok();                  /* first inner token */
                if (g_cur.kind != TOK_STAR)
                    die(g_cur.line, g_cur.col,
                        "(lvalue)++/-- requires a '*ptr' lvalue");
                next_tok();
                if (g_cur.kind != TOK_IDENT) {
                    /* `(*(computed))++` / `--` -- the deref target is a
                     * full pointer EXPRESSION, not a named pointer (frotz
                     * variable.c `(*(fp - zargs[0]))--`).  Build the
                     * pointer subtree, close the wrapper ')', and let the
                     * CU-1 tail emit the RMW through the computed address
                     * (S_FIELD_INCDEC_AT walker: address computed once). */
                    int pline = g_cur.line, pcol = g_cur.col;
                    int addr = ast_build_unary();
                    if (!ISPTR(g_ast[addr].type))
                        die(pline, pcol,
                            "(lvalue)++/-- requires a '*ptr' lvalue");
                    expect(TOK_RPAREN, "')'");
                    return cu1_dsub_store_tail(addr, g_ast[addr].type,
                                               g_ast[addr].is_unsigned,
                                               pline, pcol);
                }
                const char *nm = g_cur.id_ptr;
                int         nl = g_cur.id_len;
                int         ln = g_cur.line, cl = g_cur.col;
                Local  *lc = locals_lookup(nm, nl);
                Global *gv = (lc == NULL) ? globals_lookup(nm, nl) : NULL;
                if (lc == NULL && gv == NULL) {
                    char buf[64];
                    snprintf(buf, sizeof buf, "'%.*s' undeclared", nl, nm);
                    die(ln, cl, buf);
                }
                next_tok();                  /* the wrapper ')' */
                if (g_cur.kind != TOK_RPAREN)
                    die(g_cur.line, g_cur.col,
                        "(lvalue)++/-- requires a '*ptr' lvalue");
                next_tok();                  /* '++' / '--' */
                if (g_cur.kind != TOK_PLUSPLUS && g_cur.kind != TOK_MINUSMINUS)
                    die(g_cur.line, g_cur.col,
                        "(lvalue)++/-- requires a '*ptr' lvalue");
                int is_inc = (g_cur.kind == TOK_PLUSPLUS);
                next_tok();                  /* consume '++'/'--' */
                expect(TOK_SEMI, "';'");
                int n = ast_new(S_PREINC_DEREF, ln, cl);
                g_ast[n].sym_lc = lc; g_ast[n].sym_gv = gv;
                g_ast[n].flags = is_inc ? AF_IS_INC : 0;
                return n;
            }
            /* Redundant OUTER parens whose inner itself begins with '(' —
             * recycle's CLR expands the if-body to `((bitmap[i]) &= ~m)`.  Strip
             * one layer (splice the outer ')' out) and re-dispatch, so the inner
             * `(lvalue) op=` / `(lvalue) =` reaches the G21 handlers above.  A
             * non-lvalue inner just re-parses as a parenthesized expression —
             * identical result; deeper nesting peels one layer per pass.
             *
             * BUT the outer parens are load-bearing when a POSTFIX operator
             * follows the outer ')': `((cast)ptr)[i] = rhs` (compress's
             * tab_suffixof byte-overlay), `(expr).field`, `(expr)->m`.  Here
             * stripping would rebind the inner cast/expr to `ptr[i]` and drop
             * the store.  Leave those to the plain-expression path (G20), whose
             * build_postfix_value_chain builds the indexed-value store. */
            if (peek_tok().kind == TOK_LPAREN &&
                after != TOK_LBRACKET && after != TOK_DOT &&
                after != TOK_ARROW) {
                g_toks[jclose].kind = TOK_SKIP;
                next_tok();                  /* prime: first inner token */
                return build_stmt();         /* inner statement; ';' from stream */
            }
        }
        /* Plain parenthesized expression statement (G20).  It is a whole
         * statement, so a void operand of its comma is allowed, as in
         * `(x), voidcall();' -- K&R A.7.18: the result has "the type and
         * value of the right operand". */
        return build_comma_expr_stmt(g_cur.line, g_cur.col);
    }

    /* Any other expression is a statement too: K&R A.9.2,
     * "expression-statement: expression(opt) ;".  A macro that expands to
     * a constant leaves `0;'. */
    if (g_cur.kind == TOK_INT_LIT || g_cur.kind == TOK_CHAR_LIT ||
        g_cur.kind == TOK_STR_LIT || g_cur.kind == TOK_FLOAT_LIT ||
        g_cur.kind == TOK_MINUS || g_cur.kind == TOK_PLUS ||
        g_cur.kind == TOK_TILDE || g_cur.kind == TOK_BANG ||
        g_cur.kind == TOK_SIZEOF_KW)
        return build_comma_expr_stmt(g_cur.line, g_cur.col);

    die(g_cur.line, g_cur.col, "expected statement");
}

/* parse_stmt / parse_decl RETIRED by Increment 3c: the function body builds
 * as ONE tree (parse_func_decl_with_spec) and nothing else consumes
 * per-statement entries. */

void
parse_func_decl_with_spec(TypeSpec ret_t)
{
    /* declarator-refactor Increment 4: the function's return-type declarator +
     * NAME flow through the ONE parse_declarator (dispatcher already consumed the
     * base return-type spec).  The `(` after the name makes it a function
     * declarator (is_func_proto), so parse_declarator returns with the params
     * UNCONSUMED and rd.type == the RETURN type, derived by the SAME
     * type_for_decl every context uses (depth-1 byte-identical to the old
     * LT_*_PTR mapping -- B-3 -- so existing single/double-pointer returns are
     * golden-stable; `char **` etc. already worked via the depth-aware tword).
     *
     * This DELETES the old return-type whitelist ("bad return type"): the
     * declarator's `()` says "function", the base says "of what", and ANY base
     * is legal -- typedef'd pointer returns (`typedef char *string; string
     * f();`), union/enum returns, and every K&R return shape that used to trip
     * the whitelist.  ret_type is consumed generically downstream (ISPTR /
     * BTYPE), so a derived return flows to callers.  The struct-return-BY-VALUE
     * reject stays -- it is a CODEGEN limit (no struct-return ABI), not a
     * grammar one. */
    Declarator rd = parse_declarator(ret_t, /*allow_abstract=*/0);
    if (!rd.is_func_proto)
        die(rd.name_line, rd.name_col, "expected '(' after function name");
    LocalType ret_type = rd.type;
    if (BTYPE(ret_type) == BT_STRUCT && !ISPTR(ret_type))
        die(rd.name_line, rd.name_col,
            "return-by-value struct not supported (M8); use a pointer parameter");
    const char *name_ptr = rd.name;
    int         name_len = rd.name_len;
    int         line     = rd.name_line, col = rd.name_col;

    expect(TOK_LPAREN, "'('");

    /* G27 (top-level): an EMPTY parameter list `f()` is K&R "unspecified
     * arguments", NOT "zero arguments" — calls must not be arg-count checked
     * (e.g. ed's `char *malloc(); long lseek(); int *address();` then
     * `malloc(n)` / `lseek(fd,off,whence)`).  `(void)` is the ANSI zero-arg
     * form and stays strict (its first token is `void`, not `)`).  This
     * mirrors the in-body extern-proto path (the `is_variadic = 1` at the
     * `K&R () = unspecified args` site). */
    int empty_parens = (g_cur.kind == TOK_RPAREN);

    /* Stash param names; declare them after we register the function
     * so funcs_lookup's n_params is set correctly. */
    struct {
        const char *ptr; int len; int line; int col;
        LocalType type;
        int       struct_id;
        int       fn_sig_id;    /* M18: -1 unless type is LT_FN_PTR */
        int       row_stride;   /* M19: nonzero iff multi-dim array param */
        int       n_dims;       /* M19: effective dim count for indexing */
        int       dims[MAX_DIMS]; /* M19: dims[1..] for stride descent */
        int       is_unsigned;  /* A-1: unsigned scalar param */
    } params[MAX_LOCALS];
    int n_params      = 0;
    int saw_ellipsis  = 0;
    /* The type each parameter arrives as.  A float named in an old-style
     * declaration list arrives promoted (K&R A.7.3.2: "each float argument
     * is converted to double"), and A.10.1 keeps its declared type: "the
     * first edition specified that the declarations of float parameters
     * were adjusted to read double. The difference becomes noticable when a
     * pointer to a parameter is generated within a function."  So it is
     * received as LT_DBL and narrowed to a float in its own slot on entry. */
    LocalType pabi[MAX_LOCALS];
    int       kr_float[MAX_LOCALS] = { 0 };

    while (g_cur.kind != TOK_RPAREN) {
        if (n_params >= MAX_LOCALS)
            die(g_cur.line, g_cur.col, "too many parameters (max 16)");
        /* G8: K&R implicit-int prototype param — `bool_t onedown(n);`.
         * A bare identifier that is NOT a type/typedef/modifier and is
         * immediately followed by ',' or ')' is an old-style parameter
         * whose type defaults to int.  Bind it as a named LT_INT param so
         * the signature/offset passes stay correct. */
        if (g_cur.kind == TOK_IDENT &&
            typedefs_lookup(g_cur.id_ptr, g_cur.id_len) < 0 &&
            !is_type_modifier_ident(g_cur.id_ptr, g_cur.id_len)) {
            LexPeek     kr_pk;
            lex_peek_save(&kr_pk);
            int         kr_line = g_cur.line, kr_col = g_cur.col;
            const char *kr_ptr  = g_cur.id_ptr;
            int         kr_len  = g_cur.id_len;
            next_tok();
            if (g_cur.kind == TOK_COMMA || g_cur.kind == TOK_RPAREN) {
                params[n_params].ptr  = kr_ptr;
                params[n_params].len  = kr_len;
                params[n_params].line = kr_line;
                params[n_params].col  = kr_col;
                params[n_params].type = LT_INT;
                params[n_params].struct_id = -1;
                params[n_params].fn_sig_id = -1;
                params[n_params].row_stride = 0;
                params[n_params].is_unsigned = 0;
                n_params++;
                if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
                break;  /* TOK_RPAREN: loop test consumes it */
            }
            /* Not the K&R shape — restore and parse normally. */
            lex_peek_restore(&kr_pk);
        }
        TypeSpec pt = parse_type_spec();
        /* M18: function-pointer param: T (*name)(params). */
        {
            const char *fn_pname_ptr;
            int         fn_pname_len;
            int         fn_psig_id;
            if (parse_fn_ptr_declarator(pt, &fn_pname_ptr, &fn_pname_len, &fn_psig_id)) {
                /* An ARRAY of fn-ptrs as a PARAMETER (`int (*g[N])()`) is not
                 * supported — the array size is dropped and (*g)(..) would call
                 * the array's address.  Fail loud instead of miscompiling
                 * (Fable review 2026-07-19; same guard added to the K&R path). */
                if (g_fnptr_decl_arr != 0)
                    die(g_cur.line, g_cur.col,
                        "array-of-function-pointer parameter not supported");
                params[n_params].ptr  = fn_pname_ptr;
                params[n_params].len  = fn_pname_len;
                params[n_params].line = g_cur.line;
                params[n_params].col  = g_cur.col;
                params[n_params].type = LT_FN_PTR;
                params[n_params].struct_id = -1;
                params[n_params].fn_sig_id = fn_psig_id;
                params[n_params].row_stride = 0;
                params[n_params].is_unsigned = 0;   /* A-1 */
                params[n_params].n_dims = 0;
                n_params++;
                if (g_cur.kind == TOK_COMMA) { next_tok();
                    if (g_cur.kind == TOK_ELLIPSIS) {
                        next_tok();
                        if (g_cur.kind != TOK_RPAREN)
                            die(g_cur.line, g_cur.col,
                                "'...' must be last in param list");
                        saw_ellipsis = 1;
                        break;
                    }
                    continue; }
                if (g_cur.kind != TOK_RPAREN)
                    die(g_cur.line, g_cur.col, "expected ',' or ')'");
                continue;
            }
        }
        /* M18: typedef-resolved fn-ptr param: cb_t cb */
        if (pt.base == LT_FN_PTR) {
            if (g_cur.kind != TOK_IDENT)
                die(g_cur.line, g_cur.col, "expected parameter name");
            params[n_params].ptr  = g_cur.id_ptr;
            params[n_params].len  = g_cur.id_len;
            params[n_params].line = g_cur.line;
            params[n_params].col  = g_cur.col;
            params[n_params].type = LT_FN_PTR;
            params[n_params].struct_id = -1;
            params[n_params].fn_sig_id = pt.struct_id;   /* overloaded */
            params[n_params].row_stride = 0;
            params[n_params].is_unsigned = 0;   /* A-1 */
            n_params++;
            next_tok();
            if (g_cur.kind == TOK_COMMA) { next_tok();
                if (g_cur.kind == TOK_ELLIPSIS) {
                    next_tok();
                    if (g_cur.kind != TOK_RPAREN)
                        die(g_cur.line, g_cur.col,
                            "'...' must be last in param list");
                    saw_ellipsis = 1;
                    break;
                }
                continue; }
            if (g_cur.kind != TOK_RPAREN)
                die(g_cur.line, g_cur.col, "expected ',' or ')'");
            continue;
        }
        /* M19: multi-dim array param — int m[][C][D]...  Outermost
         * dim must be implicit; rest must be explicit literals.
         * Result: LT_*_PTR with row_stride = product(inner dims) *
         * elem_size.  Save lexer state for lookahead — only commit
         * if the IDENT '[' ']' shape is matched. */
        if (g_cur.kind == TOK_IDENT) {
            LexPeek m_pk;
            lex_peek_save(&m_pk);
            const char *m_name_ptr = g_cur.id_ptr;
            int         m_name_len = g_cur.id_len;
            int         m_line = g_cur.line, m_col = g_cur.col;
            next_tok();
            if (g_cur.kind == TOK_LBRACKET) {
                next_tok();
                if (g_cur.kind == TOK_RBRACKET) {
                    next_tok();   /* past ']' */
                    int param_dims[MAX_DIMS];
                    int param_n_dims = 1;
                    param_dims[0] = 0;
                    int ok = 1;
                    while (g_cur.kind == TOK_LBRACKET) {
                        if (param_n_dims >= MAX_DIMS) { ok = 0; break; }
                        next_tok();
                        if (g_cur.kind != TOK_INT_LIT) { ok = 0; break; }
                        param_dims[param_n_dims++] = (int)g_cur.value;
                        next_tok();
                        if (g_cur.kind != TOK_RBRACKET) { ok = 0; break; }
                        next_tok();
                    }
                    if (ok) {
                        LocalType ptype;
                        int es = 2;
                        if (pt.base == LT_INT)       ptype = LT_INT_PTR;
                        else if (pt.base == LT_CHAR) { ptype = LT_CHAR_PTR; es = 1; }
                        else die(m_line, m_col, "multi-dim param base must be int or char");
                        int inner = 1;
                        for (int d = 1; d < param_n_dims; d++) inner *= param_dims[d];
                        params[n_params].ptr  = m_name_ptr;
                        params[n_params].len  = m_name_len;
                        params[n_params].line = m_line;
                        params[n_params].col  = m_col;
                        params[n_params].type = ptype;
                        params[n_params].struct_id = -1;
                        params[n_params].fn_sig_id = -1;
                        params[n_params].row_stride = inner * es;
                        params[n_params].is_unsigned = 0;   /* A-1 */
                        params[n_params].n_dims = param_n_dims;
                        for (int d = 0; d < param_n_dims; d++)
                            params[n_params].dims[d] = param_dims[d];
                        n_params++;
                        if (g_cur.kind == TOK_COMMA) { next_tok();
                            if (g_cur.kind == TOK_ELLIPSIS) {
                                next_tok();
                                if (g_cur.kind != TOK_RPAREN)
                                    die(g_cur.line, g_cur.col,
                                        "'...' must be last in param list");
                                saw_ellipsis = 1;
                                break;
                            }
                            continue;
                        }
                        if (g_cur.kind != TOK_RPAREN)
                            die(g_cur.line, g_cur.col, "expected ',' or ')'");
                        continue;
                    }
                }
            }
            /* Not multi-dim shape — restore and fall through. */
            lex_peek_restore(&m_pk);
        }
        int stars = 0;                                  /* B-3: pointer depth */
        while (g_cur.kind == TOK_STAR) { stars++; next_tok(); }
        if (stars == 0 && pt.base == LT_VOID) {
            /* '(void)' alternate empty-param-list. */
            if (g_cur.kind == TOK_RPAREN && n_params == 0) break;
            die(g_cur.line, g_cur.col, "void param must be 'void *p'");
        }
        /* B-3: `char **argv` etc. parse to a real depth-2 pointer type.
         * main()'s argv is bound in the prologue to &args_argv[0] (a real
         * 4-byte char**), so argv[i] resolves via ordinary depth-2 indexing. */
        LocalType ptype = type_for_decl(pt, stars, 0);
        if (ptype == LT_STRUCT &&
            (pt.struct_id < 0 || g_structs[pt.struct_id].is_forward))
            die(g_cur.line, g_cur.col,
                "by-value struct param requires complete type");
        /* G7: the parameter NAME is optional (abstract declarator).  ANSI
         * prototypes like `char *strsave(char *);` and `void g(char, int);`
         * name only the type.  The type still counts toward the signature
         * and per-param offsets; an unnamed param just gets an empty name
         * (harmless — locals_lookup never matches "" and the main()/offset
         * passes iterate params[] by index, not by name). */
        if (g_cur.kind == TOK_IDENT) {
            params[n_params].ptr  = g_cur.id_ptr;
            params[n_params].len  = g_cur.id_len;
        } else {
            params[n_params].ptr  = "";
            params[n_params].len  = 0;
        }
        params[n_params].line = g_cur.line;
        params[n_params].col  = g_cur.col;
        params[n_params].type = param_adjust_type(ptype);
        params[n_params].struct_id =
            (BTYPE(ptype) == BT_STRUCT) ? pt.struct_id : -1;  /* G52: any depth */
        params[n_params].fn_sig_id = -1;
        params[n_params].row_stride = 0;
        params[n_params].is_unsigned = pt.is_unsigned;   /* A-1 */
        n_params++;
        if (g_cur.kind == TOK_IDENT) next_tok();
        /* C array-parameter decay: `T p[]` / `T p[N]` / `T *p[]` and the
         * abstract `T []` / `T *[]` (tcsh sh.decls.h `Char *[]` prototypes).
         * The outermost dim adjusts the type to a pointer -- one more pointer
         * level.  (Plain unstarred named `T m[]` / multidim `T m[][C]` are
         * handled by the named-array path above; this catches the starred /
         * abstract forms that reach the scalar path.) */
        if (g_cur.kind == TOK_LBRACKET) {
            next_tok();
            if (g_cur.kind != TOK_RBRACKET)
                (void)parse_const_bin(0);    /* `[N]`: size is irrelevant for a param */
            expect(TOK_RBRACKET, "']'");
            if (g_cur.kind == TOK_LBRACKET)
                die(g_cur.line, g_cur.col,
                    "multi-dim array parameter with '*' or abstract form not supported");
            params[n_params - 1].type = INCREF(ptype, DERIV_PTR);
        }
        if (g_cur.kind == TOK_COMMA) {
            next_tok();
            /* M11: '...' after a named param marks the function variadic. */
            if (g_cur.kind == TOK_ELLIPSIS) {
                next_tok();
                if (g_cur.kind != TOK_RPAREN)
                    die(g_cur.line, g_cur.col,
                        "'...' must be last in param list");
                saw_ellipsis = 1;
                break;
            }
            continue;
        }
        if (g_cur.kind != TOK_RPAREN)
            die(g_cur.line, g_cur.col, "expected ',' or ')'");
    }
    next_tok();  /* consume ')' */

    /* G43: K&R old-style function DEFINITION — the parameter TYPES are
     * declared in a block between ')' and '{', binding the bare param names
     * parsed above (which defaulted to int via the G8 path).  stevie's only
     * old-style definition is cmdline.c's varargs smsg():
     *     smsg(s, a1, ..., a9)  char *s;  int a1, ..., a9;  { ... }
     * In valid C a type-introducer can only follow ')' in this old-style
     * form (ANSI has '{' for a definition or ';' for a prototype), so the
     * loop never fires for prototypes/ANSI definitions.  Override params[]
     * by name BEFORE offsets and param-locals are computed below, so pointer
     * params get their 4-byte slots; an unmentioned param keeps implicit int. */
    while (g_cur.kind == TOK_CHAR_KW || g_cur.kind == TOK_INT_KW ||
           g_cur.kind == TOK_LONG_KW || g_cur.kind == TOK_FLOAT_KW ||
           g_cur.kind == TOK_VOID_KW ||
           g_cur.kind == TOK_STRUCT_KW || g_cur.kind == TOK_UNION_KW ||
           g_cur.kind == TOK_ENUM_KW ||
           (g_cur.kind == TOK_IDENT &&
            (typedefs_lookup(g_cur.id_ptr, g_cur.id_len) >= 0 ||
             is_type_modifier_ident(g_cur.id_ptr, g_cur.id_len)))) {
        TypeSpec kt = parse_type_spec();
        for (;;) {
            /* K&R function-pointer parameter: `int (*routine)();` — the shape
             * 2.11BSD telnet's central call() dispatcher uses (telnet.c:2205).
             * The ANSI param path (~4321) already handles fn-ptr params via
             * parse_fn_ptr_declarator; the K&R param-DECLARATION path did not,
             * dying "expected parameter name".  parse_fn_ptr_declarator is a
             * safe try (restores the lexer + returns 0 for `int *p` / `char
             * buf[]` / plain idents), so fall through to the star/ident logic
             * below on 0.  On match, re-type the named parameter to LT_FN_PTR. */
            {
                const char *fkp; int fkl, fk_sig;
                int fkln = g_cur.line, fkcl = g_cur.col;
                if (parse_fn_ptr_declarator(kt, &fkp, &fkl, &fk_sig)) {
                    if (g_fnptr_decl_arr != 0)
                        die(fkln, fkcl,
                            "array-of-function-pointer parameter not supported");
                    if (fkl == 0)
                        die(fkln, fkcl,
                            "K&R function-pointer declaration must name a parameter");
                    int fmatched = 0;
                    for (int pi = 0; pi < n_params; pi++) {
                        if (params[pi].len == fkl &&
                            memcmp(params[pi].ptr, fkp, (size_t)fkl) == 0) {
                            params[pi].type       = LT_FN_PTR;
                            params[pi].fn_sig_id  = fk_sig;
                            params[pi].struct_id  = -1;
                            fmatched = 1;
                            break;
                        }
                    }
                    if (!fmatched)
                        die(fkln, fkcl, "K&R declaration names a non-parameter");
                    if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
                    expect(TOK_SEMI, "';' in K&R parameter declaration");
                    break;
                }
            }
            int kstars = 0;
            while (g_cur.kind == TOK_STAR) { kstars++; next_tok(); }
            if (g_cur.kind != TOK_IDENT)
                die(g_cur.line, g_cur.col,
                    "expected parameter name in K&R declaration");
            const char *kp  = g_cur.id_ptr;
            int         kl  = g_cur.id_len;
            int         kln = g_cur.line, kcl = g_cur.col;
            next_tok();
            /* K&R array param decays to a pointer: `char buf[]` / `int v[N]`. */
            int kdecay = 0;
            while (g_cur.kind == TOK_LBRACKET) {
                next_tok();
                if (g_cur.kind != TOK_RBRACKET) (void)parse_const_bin(0);
                expect(TOK_RBRACKET, "']'");
                kdecay = 1;
            }
            LocalType kdt = type_for_decl(kt, kstars + (kdecay ? 1 : 0), 0);
            int matched = 0;
            for (int pi = 0; pi < n_params; pi++) {
                if (params[pi].len == kl &&
                    memcmp(params[pi].ptr, kp, (size_t)kl) == 0) {
                    params[pi].type = param_adjust_type(kdt);
                    kr_float[pi] = (params[pi].type == LT_FLOAT);
                    params[pi].struct_id =
                        (BTYPE(kdt) == BT_STRUCT)      /* G52: any depth */
                        ? kt.struct_id : -1;
                    params[pi].is_unsigned = kt.is_unsigned;
                    matched = 1;
                    break;
                }
            }
            if (!matched)
                die(kln, kcl, "K&R declaration names a non-parameter");
            if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
            expect(TOK_SEMI, "';' in K&R parameter declaration");
            break;
        }
    }

    for (int i = 0; i < n_params; i++)
        pabi[i] = kr_float[i] ? LT_DBL : params[i].type;

    /* Register the function BEFORE the body so recursion works.  Increment 4:
     * identity is the RETURNED index (promotion is in place now, so the
     * defined function need not be the last slot). */
    g_declare_empty_parens = empty_parens;   /* K&R-compat: bare `f()` must
                                              * not clobber a real prototype
                                              * (funcs_declare consumes) */
    int fidx = funcs_declare(name_ptr, name_len, n_params, line, col);
    /* lint's VARARGSn, when it stood before this external declaration and the
     * declaration is a definition. */
    if (g_decl_lint_varargs >= 0 && g_cur.kind == TOK_LBRACE &&
        !g_fn_redecl_defined)
        g_funcs[fidx].n_fixed = g_decl_lint_varargs < n_params
                                    ? g_decl_lint_varargs : n_params;
    g_decl_lint_varargs = -1;
    /* Redecl-after-definition: the entry is the DEFINED function — leave it
     * untouched (an identical prototype must not scribble return/param/
     * variadic state onto emitted code).  Legal iff this declarator is a
     * prototype; a '{' below is a redefinition and dies there. */
    int redecl_defined = g_fn_redecl_defined;
    g_cur_fn_idx = fidx;
    if (!redecl_defined) {
    g_funcs[fidx].return_type = ret_type;
    g_funcs[fidx].ret_unsigned =
        (ret_type == LT_INT || ret_type == LT_CHAR || ret_type == LT_LONG)
            ? ret_t.is_unsigned : 0;   /* A-1: unsigned return carries */
    /* Carry the return struct id for a struct/union-pointer return so
     * `f()->field` chains on the result (elvis cut.c's `blkget(first)->c`). */
    g_funcs[fidx].return_struct_id =
        (BTYPE(ret_type) == BT_STRUCT) ? ret_t.struct_id : -1;  /* G52: any depth */
    g_funcs[fidx].is_variadic = saw_ellipsis || empty_parens;
    /* RTL-ABI: EXPLICIT-varargs is the carried prototype flag (funcs_declare)
     * OR this definition's own `...`/empty `()`.  A K&R definition with NAMED
     * params (elvis `msg(fmt,a1..a7)`) keeps the flag from its `void msg();`
     * header decl, so the callee's param offsets flip below. */
    g_funcs[fidx].is_variadic_expl |= (saw_ellipsis || empty_parens);
    g_funcs[fidx].is_static   = ret_t.is_static;
    g_funcs[fidx].is_extern   = ret_t.is_extern;
    }   /* !redecl_defined */
    else if (g_fn_kept_proto) {
        /* A bare `T f();' over a richer entry keeps the PARAMETERS and nothing
         * else.  K&R A.8.6.3: an old-style declarator gives "function of
         * unspecified arguments RETURNING T" and "no information about the
         * types of the parameters is supplied by the declaration" -- parameters,
         * and only parameters.  The return type is this declarator's own, and
         * for a struct-pointer return it carries the struct id that lets
         * `f(x)->m' resolve strictly (apple/fgx#153).
         *
         * A.10.2 lets the two declarations coexist only when they are OTHERWISE
         * IDENTICAL, so a differing return type is not a choice to make quietly
         * -- it is a program that does not agree with itself, and picking either
         * side silently is how a far-pointer return loses its bank. */
        if (g_funcs[fidx].return_type != ret_type)
            fprintf(stderr, "%s:%d:%d: warning: '%.*s' redeclared with return "
                    "type %u after %u (K&R A.10.2: the declarations must agree)\n",
                    g_input_path, line, col, name_len, name_ptr,
                    (unsigned)ret_type, (unsigned)g_funcs[fidx].return_type);
        g_funcs[fidx].return_type = ret_type;
        g_funcs[fidx].ret_unsigned =
            (ret_type == LT_INT || ret_type == LT_CHAR || ret_type == LT_LONG)
                ? ret_t.is_unsigned : 0;
        g_funcs[fidx].return_struct_id =
            (BTYPE(ret_type) == BT_STRUCT) ? ret_t.struct_id : -1;
    }

    /* Reset per-function state and enter parameters. */
    locals_reset(name_ptr, name_len);
    /* M8 / RTL-ABI: compute per-param byte offsets, cumulative from a fixed end.
     *   Fixed-arity (default): param[N-1] at offset 0, param0 DEEPEST — matches
     *     the left-to-right caller push (all corpus calls; libc shims).
     *   Explicit-varargs (is_variadic_expl): param0 at offset 0 (SHALLOWEST,
     *     adjacent to the return frame), param[N-1] deepest — so a K&R varargs
     *     callee reads param0 from a FIXED slot regardless of the caller's arg
     *     count.  Callers of such a function push args right-to-left to match. */
    {
        /* RTL-ABI (B2 universal): flip EVERY callee's param offsets (param0 at
         * offset 0, shallowest) to match the now-uniform right-to-left call-site
         * push (K&R/2.11BSD-native).  The earlier targeted flip was gated on
         * is_variadic_expl because a universal flip reversed calls into hand-asm
         * stubs (jsh_stubs.s) that read L-to-R; Stage B1 retired all such
         * multi-arg stubs, and every remaining hand-asm callee takes args via
         * registers/globals or ≤1 stack arg, so the flip is now safe everywhere.
         * Caller ordering (rtl active=1) and this callee layout flip together. */
        int flip = 1;
        int cur = 0;
        int i;
        for (i = flip ? 0 : n_params - 1;
             flip ? (i < n_params) : (i >= 0);
             i += flip ? 1 : -1) {
            g_param_byte_offsets[i] = cur;
            int sz = 2;
            if (params[i].type == LT_STRUCT) {
                sz = (g_structs[params[i].struct_id].total_size + 1) & ~1;
            } else if (is_ptr_type(pabi[i]) ||
                       pabi[i] == LT_LONG ||
                       pabi[i] == LT_FLOAT) {
                sz = 4;  /* long ptr / long / float scalar: 4-byte slot (B-6) */
            } else if (IS_QUAD(pabi[i])) {
                sz = 8;
            }
            cur += sz;
        }
    }
    /* Pre-ANSI varargs (varargs.h): `void f(va_alist) va_dcl { va_start(ap); }`
     * parses as a fixed one-int-param definition, but `va_alist` IS the head of
     * the argument list — the function is variadic and its arity is unknown.
     * `va_alist` is not a name a program picks by accident: varargs.h's own
     * `va_dcl`/`va_start` are written in terms of it, so the name IS the
     * interface.  Marking it here is what stops the K&R signature sidecar
     * (sigs_emit) from exporting `xprintf` as taking exactly one argument and
     * killing every real call site with an arity error. */
    for (int i = 0; i < n_params; i++)
        if (params[i].len == 8 && strncmp(params[i].ptr, "va_alist", 8) == 0) {
            g_funcs[fidx].is_variadic      = 1;
            g_funcs[fidx].is_variadic_expl = 1;
        }
    for (int i = 0; i < n_params; i++) {
        locals_declare(params[i].ptr, params[i].len, LK_PARAM,
                       pabi[i], 1, params[i].line, params[i].col);
        g_locals[g_n_locals - 1].struct_id = params[i].struct_id;
        g_locals[g_n_locals - 1].fn_sig_id = params[i].fn_sig_id;
        g_locals[g_n_locals - 1].is_unsigned = params[i].is_unsigned;   /* A-1 */
        if (params[i].row_stride > 0) {
            /* M19: multi-dim array param — row_stride drives chained indexing.
             * Storage stays 4 bytes (long-pointer shape from is_ptr_type).
             * n_dims + dims[] carry the chain depth for index parsing. */
            g_locals[g_n_locals - 1].row_stride = params[i].row_stride;
            g_locals[g_n_locals - 1].n_dims = params[i].n_dims;
            for (int d = 0; d < params[i].n_dims && d < MAX_DIMS; d++)
                g_locals[g_n_locals - 1].dims[d] = params[i].dims[d];
        }
        /* Patch byte_size for struct-typed params (others were already 2). */
        if (params[i].type == LT_STRUCT) {
            int sz = (g_structs[params[i].struct_id].total_size + 1) & ~1;
            g_locals[g_n_locals - 1].byte_size = sz;
        }
        /* Pointer-typed params: locals_declare already set byte_size=4. */
        if (!redecl_defined) {
            g_funcs[fidx].param_types[i]      = pabi[i];
            g_funcs[fidx].param_struct_ids[i] = params[i].struct_id;
        }
    }

    int pbase = g_n_locals - n_params;   /* params[i] is g_locals[pbase + i] */

    /* M18: intern this function's own signature so its name can be
     * taken as a fn-pointer value (fp = func_name). */
    if (!redecl_defined) {
        LocalType pts[MAX_LOCALS];
        int psids[MAX_LOCALS];
        for (int i = 0; i < n_params; i++) {
            pts[i]   = pabi[i];
            psids[i] = params[i].struct_id;
        }
        g_funcs[fidx].fn_sig_id =
            fn_sig_intern(ret_type, n_params, pts, psids, saw_ellipsis,
                          g_funcs[fidx].ret_unsigned);
    }

    /* main(int argc, char **argv) binding.  When the function being
     * compiled is named "main" and has at least one int param, bind:
     *   - first int param  -> args_argc  (init at prologue from the global)
     *   - second ptr param -> argv       (bound to &args_argv[0] at prologue)
     * Outside main, both stay NULL so the bindings are no-ops. */
    g_main_argc_local = NULL;
    g_main_argv_local = NULL;
    if (name_len == 4 && memcmp(name_ptr, "main", 4) == 0) {
        int param_base = g_n_locals - n_params;
        for (int i = 0; i < n_params; i++) {
            Local *p = &g_locals[param_base + i];
            if (g_main_argc_local == NULL && p->type == LT_INT) {
                g_main_argc_local = p;
                continue;
            }
            /* argv is a real depth-2 `char **`; recognize the second magic
             * param so emit_func_prologue can bind it to &args_argv[0]. */
            if (g_main_argv_local == NULL && ISPTR(p->type)) {
                g_main_argv_local = p;
            }
        }
    }

    /* M11: prototype-only ('int foo(...);' — no body).  Mark extern and
     * skip body parsing; no codegen emitted for this function.  A
     * redecl-after-definition keeps the DEFINED state (never re-extern). */
    if (g_cur.kind == TOK_SEMI) {
        if (!redecl_defined)
            g_funcs[fidx].is_extern = 1;
        next_tok();
        return;
    }

    /* Multi-declarator prototype list: `WINDOW *initscr(), *newwin(),
     * *subwin();` (4.3BSD curses.h).  This declarator is a prototype;
     * re-enter with the SAME base spec for the next one — each parses its
     * own stars/name/params, and the innermost hits the ';' branch above. */
    if (g_cur.kind == TOK_COMMA) {
        if (!redecl_defined)
            g_funcs[fidx].is_extern = 1;
        next_tok();
        /* The next init-declarator need not be a function: `int f(), x;'.
         * K&R A.8's init-declarator-list takes any declarator after the
         * comma, so an object goes to the file-scope declarator loop, peeked
         * as parse_program peeks. */
        {
            LexPeek pk;
            int     is_func = 0;
            lex_peek_save(&pk);
            while (g_cur.kind == TOK_STAR) next_tok();
            if (g_cur.kind == TOK_IDENT) {
                next_tok();
                is_func = (g_cur.kind == TOK_LPAREN);
            }
            lex_peek_restore(&pk);
            if (!is_func) {
                parse_global_decl(ret_t);
                return;
            }
        }
        parse_func_decl_with_spec(ret_t);
        return;
    }

    if (redecl_defined && g_funcs[fidx].is_from_sigs) {
        /* THE KEPT PROTOTYPE CAME FROM --sigs, NOT FROM THIS TU.  Nothing in
         * the source declares this name: the sidecar is fcc's out-of-band
         * knowledge of what libc happens to define, added so an UNDECLARED
         * call gets the right argument widths (apple/fgx#327).  A body here
         * is therefore not a redefinition -- it is this program's own
         * function that happens to share a name with one in libc.
         *
         * K&R 2nd ed A.11.1 decides it: "The lexical scope of an object or
         * function identifier in an external declaration begins at the end of
         * its declarator and persists to the end of the TRANSLATION UNIT IN
         * WHICH IT APPEARS."  The sidecar appears in no translation unit, so
         * it declares nothing and suspends nothing; this definition's own
         * declarator is the only one `abs' has here.  Whether libc's copy
         * ALSO reaches the program is the linker's question, and fgx_ld says
         * so itself if two definitions arrive.
         *
         * 2.11BSD's chmod(1) is exactly this and it is not an accident of
         * style: its `abs()' reads an OCTAL NUMBER out of the mode string.
         * Without this arm a verbatim port cannot compile, and the two ways
         * to make it compile without fixing fcc -- renaming upstream's
         * function, or dropping the sidecar for that TU -- are both edits to
         * the port to suit the compiler.
         *
         * The empty-paren arm in funcs_declare kept the SIGNATURE, so undo
         * that here: this declarator's parameters and return type are the
         * function's.  The `;' and `,' branches above return before reaching
         * this, so a genuine prototype still keeps libc's shape. */
        g_funcs[fidx].is_from_sigs     = 0;
        g_funcs[fidx].is_extern        = 0;
        g_funcs[fidx].is_static        = ret_t.is_static;
        g_funcs[fidx].return_type      = ret_type;
        g_funcs[fidx].ret_unsigned     =
            (ret_type == LT_INT || ret_type == LT_CHAR || ret_type == LT_LONG)
                ? ret_t.is_unsigned : 0;
        g_funcs[fidx].return_struct_id =
            (BTYPE(ret_type) == BT_STRUCT) ? ret_t.struct_id : -1;
        g_funcs[fidx].is_variadic      = saw_ellipsis || empty_parens;
        g_funcs[fidx].is_variadic_expl = (saw_ellipsis || empty_parens);
        g_funcs[fidx].n_params         = n_params;
        {
            LocalType pts[MAX_LOCALS];
            int psids[MAX_LOCALS];
            int i;
            for (i = 0; i < n_params; i++) {
                g_funcs[fidx].param_types[i]      = pabi[i];
                g_funcs[fidx].param_struct_ids[i] = params[i].struct_id;
                pts[i]   = pabi[i];
                psids[i] = params[i].struct_id;
            }
            g_funcs[fidx].fn_sig_id =
                fn_sig_intern(ret_type, n_params, pts, psids, saw_ellipsis,
                              g_funcs[fidx].ret_unsigned);
        }
        redecl_defined = 0;
    }
    if (redecl_defined) {
        char buf[64];
        snprintf(buf, sizeof buf,
                 "redefinition of function '%.*s'", name_len, name_ptr);
        die(line, col, buf);
    }
    expect(TOK_LBRACE, "'{'");

    /* Bank-0 stack campaign 1.3: is this function a recursion-cycle member?
     * Decided once, here, before a single byte is emitted -- every downstream
     * site (slot access, &local, prologue, epilogue, FRAMESIZE/SOFTSIZE) reads
     * the same flag, so a function cannot be half-exiled. */
    g_fn_is_soft = soft_scc_member(g_func_name);
    if (!g_fn_is_soft) {
        /* The list is generated FROM THE ASSEMBLY, so it holds emitted symbols
         * -- and a static function emits `<tu_prefix>_<name>` (fname(), emit.c),
         * not its C name.  Matching only g_func_name silently exiled 34 of
         * bsh's 52 cycle members and left the 18 statics on the hardware stack:
         * a HALF-exiled cycle, which is worse than none, because the depth win
         * disappears while the data bank fills anyway.  Nothing reported it --
         * the fixture uses global functions only.
         *
         * Checking both forms is correct regardless of linkage: a global `foo`
         * cannot appear in the list as `_tu_foo`, because the list contains
         * exactly the symbols the assembler saw. */
        char mangled[MAX_IDENT * 2];
        snprintf(mangled, sizeof mangled, "%s_%s", g_tu_prefix, g_func_name);
        g_fn_is_soft = soft_scc_member(mangled);
    }

    ir_begin_func();    /* Phase 0: record this function's emission; replay at end */
    emit_func_prologue(name_ptr, name_len);

    /* Always emit the SBC #FRAMESIZE prologue.  FRAMESIZE EQU is
     * patched at the end of the function so we don't need to know
     * the final value here; param offsets use the same symbolic
     * FRAMESIZE constant so they're correct regardless of when
     * locals get declared (K&R top vs C99 mid-block). */
    emit_prologue_unconditional();

    /* An old-style float parameter arrived as LT_DBL (see pabi): narrow it
     * into the float its declaration names, in the low bytes of the same
     * slot, before the body reads it. */
    for (int i = 0; i < n_params; i++) {
        Local *p = &g_locals[pbase + i];
        if (!kr_float[i] || p->type == LT_FLOAT)
            continue;
        emit_load_local(p);
        p->type       = LT_FLOAT;
        p->row_stride = 4;
        emit_store_local(p);
    }

    /* main(int argc, ...) binding: load args_argc (set by args.s before
     * crt0 calls main) into the argc param's stack slot.  Bytes-of-codegen
     * paid only when main actually declared an int param. */
    if (g_main_argc_local != NULL) {
        /* queue 8 (G53b): route through the far/near-gated slot store —
         * a raw `STA n+FRAMESIZE,S` was un-assemblable once main's own
         * frame pushed the displacement past 255. */
        ir_emitf("                LDA     args_argc\n");
        emit_slot_sta16(g_main_argc_local, 0);
    }

    /* main(int argc, char **argv) binding: bind argv = &args_argv[0], a real
     * 4-byte char** in the param's stack slot.  Mirrors emit_addr_of_global
     * (A=offset, bank=PHB/PHK) but stores straight into the slot since
     * args_argv is an asm symbol, not a Global.  argv[i] then resolves via
     * normal B-3 char** indexing; the c_argv_get shim is gone.
     * queue 8 (G53b): the bank rides a 16-BIT word ({0,bank} — pad byte
     * now deterministically 0) so both halves go through the far/near-
     * gated emit_slot_sta16 with no M8 window. */
    if (g_main_argv_local != NULL) {
        ir_emitf("                LDA     #0\n");
        emit_m8();
        ir_emitf("                PHB\n");
        ir_record_raw(IR_POP_A, 0, 0, NULL);
        emit_m16();
        emit_slot_sta16(g_main_argv_local, 2);
        ir_emitf("                LDA     #args_argv\n");
        emit_slot_sta16(g_main_argv_local, 0);
    }

    /* fcc2 P1.3-inc2: mark the entry-seed point — after the prologue + any
     * main(argc/argv) stack-slot bindings, before the body.  ir_promote_locals
     * fills the promoted-param list; ir_emit_param_seeds emits LDA/STA here at
     * replay (no-op if no param was promoted, so transparent otherwise). */
    ir_record_op(IR_SEED_MARK);

    /* Increment 3c: the WHOLE function body is one tree — leading
     * declarations and statements build first (symbol registration and all
     * classification decisions happen here, no emission), then a single walk
     * emits everything.  This is the per-function AST window the Phase-2
     * plan called for; the ast pools reset per function. */
    int fn_local_mark = g_n_locals;
    ast_reset();
    /* A.11.1 AGAIN, FOR THE FUNCTION BODY ITSELF.  build_block_stmt hides the
     * tags a nested block declared, but a function body is not built through
     * it -- it is parsed inline here -- so a tag declared at the head of one
     * function stayed visible to the next and the second declaration read as
     * a redefinition.  2.11BSD's ls(1) is the case: getname() and getgroup()
     * each declare their own `struct ncache'. */
    int fn_tag_mark = g_n_structs;
    g_tag_scope_depth++;
    {
        int body_tmp[2048];
        int body_cnt = 0;
        while (g_cur.kind == TOK_INT_KW || g_cur.kind == TOK_CHAR_KW ||
               g_cur.kind == TOK_VOID_KW || g_cur.kind == TOK_STRUCT_KW ||
               g_cur.kind == TOK_UNION_KW || g_cur.kind == TOK_ENUM_KW ||
               g_cur.kind == TOK_LONG_KW || g_cur.kind == TOK_FLOAT_KW ||
               (g_cur.kind == TOK_IDENT &&
                (typedefs_lookup(g_cur.id_ptr, g_cur.id_len) >= 0 ||
                 is_type_modifier_ident(g_cur.id_ptr, g_cur.id_len)))) {
            if (body_cnt >= 2048)
                die(g_cur.line, g_cur.col, "function too large (max 2048 top-level statements)");
            TypeSpec t = parse_type_spec();
            body_tmp[body_cnt++] = build_decl(t);
        }
        while (g_cur.kind != TOK_RBRACE) {
            if (g_cur.kind == TOK_EOF)
                die(g_cur.line, g_cur.col, "unterminated function body");
            if (body_cnt >= 2048)
                die(g_cur.line, g_cur.col, "function too large (max 2048 top-level statements)");
            body_tmp[body_cnt++] = build_stmt();
        }
        locals_layout(fn_local_mark);
        g_last_stmt_returned = 0;
        for (int bi = 0; bi < body_cnt; bi++)
            walk_stmt(body_tmp[bi]);
    }
    if (!g_last_stmt_returned) {
        if (ret_type != LT_VOID)
            ir_emitf("                LDA     #0\n");
        emit_epilogue_return();
    }
    expect(TOK_RBRACE, "'}'");
    g_tag_scope_depth--;
    for (int i = fn_tag_mark; i < g_n_structs; i++)
        g_structs[i].scope_hidden = 1;

    /* `goto` audit: any label referenced via `goto NAME;` but never
     * defined as `NAME:` would fail at Merlin link time with a less
     * useful error.  Catch here instead. */
    for (int li = 0; li < g_n_user_labels; li++) {
        if (g_user_labels[li].referenced && !g_user_labels[li].defined) {
            char msgbuf[80];
            snprintf(msgbuf, sizeof msgbuf,
                     "goto target '%s' never defined in this function",
                     g_user_labels[li].name);
            die(g_cur.line, g_cur.col, msgbuf);
        }
    }

    /* Always emit FRAMESIZE EQU — prologue is unconditional.  Bank-0 stack
     * campaign 1.3: a recursion-cycle member puts ALL its locals in the data
     * bank, so its HARDWARE frame is empty and SOFTSIZE carries the bytes.
     * All-or-nothing per function is what lets one slot space serve both --
     * the offsets are identical, only the base register changes. */
    ir_emitf("%s_FRAMESIZE   EQU     %d\n",
            g_func_name, g_fn_is_soft ? 0 : 2 * g_total_slots);
    ir_tag_last(IRF_FRAMESIZE, (unsigned)(g_fn_is_soft ? 0 : 2 * g_total_slots));
    /* Emitted ONLY for a cycle member.  Gating in C rather than with a Merlin
     * `DO` keeps the predicate-off output byte-identical: a DO/FIN block costs
     * no bytes in the BINARY but does change the .s TEXT, so emitting it
     * unconditionally would move all 547 goldens for a feature that is off, and
     * a staged rollout whose first stage churns every golden is not reviewable. */
    if (g_fn_is_soft)
        ir_emitf("%s_SOFTSIZE    EQU     %d\n", g_func_name, 2 * g_total_slots);
    /* P3-3 3.2b: gate the prologue overflow guard.  Emit it (STKGUARD=1) only
     * where an overflow is plausible — a >=128 B frame, a direct self-call, or
     * an indirect (fn-ptr) call whose depth the linker can't bound.  Small leaf
     * frames stay guardless -> byte-identical prologue.  The prologue's
     * `DO %s_STKGUARD` forward-references this EQU (fas resolves it like
     * FRAMESIZE). */
    ir_emitf("%s_STKGUARD    EQU     %d\n", g_func_name,
            (ir_has_indirect_call() || ir_self_recursive() ||
             2 * g_total_slots >= 128) ? 1 : 0);
    /* --sections: the function's section closes after its last equate, so
     * the unit fgx_gc keeps or drops is the whole function. */
    if (g_sections)
        ir_emitf("                FGX_ENDS\n");
    /* Track the largest frame in the TU to size the FGX1 stack hint (main.c). */
    if (2 * g_total_slots > g_max_framesize)
        g_max_framesize = 2 * g_total_slots;

    stack_census_emit(2 * g_total_slots, g_funcs[fidx].is_variadic_expl);

    /* Every store in the body has been seen by now, which is the earliest a
     * "used before it is set" verdict can be passed -- see
     * emit_warn_uninit_locals.  Before ir_end_func so the warning cannot be
     * interleaved with replay output on a redirected stderr. */
    emit_warn_uninit_locals();

    ir_end_func();      /* Phase 0: replay this function's recorded ops to g_out */
}

/* One scalar item of an array's brace initializer, stored at init slot n in
 * its element type's own width: a float element's IEEE-754 bits, both words
 * of a long, the low word of anything narrower.  K&R A.8.7 initializes an
 * array's members from the list in order, however the braces nest, so the
 * flat and the nested list store an item the same way. */
static void
put_array_init_item(Global *g, int n, LocalType at)
{
    if (at == LT_FLOAT_ARRAY) {
        unsigned int fb = parse_float_init_bits();
        g->init_values[n]    = fb & 0xFFFFu;
        g->init_values_hi[n] = (fb >> 16) & 0xFFFFu;
        return;
    }
    if (at == LT_DOUBLE_ARRAY) {
        unsigned long db = parse_ldouble_init_bits();
        g->init_values[n]    = (unsigned)(db & 0xFFFFu);
        g->init_values_hi[n] = (unsigned)((db >> 16) & 0xFFFFu);
        init_put_q(g, n, (long)db);
        return;
    }
    long cv = parse_const_bin(0);
    g->init_values[n]    = (unsigned)(cv & 0xFFFFL);
    g->init_values_hi[n] = (at == LT_LONG_ARRAY || at == LT_LLONG_ARRAY)
                           ? (unsigned)((cv >> 16) & 0xFFFFL) : 0;
    if (at == LT_LLONG_ARRAY)
        init_put_q(g, n, cv);
}

/* A char array's row from a string literal: `char x[][N] = { "abc", ... }`
 * (elvis main.c digtable[][4]).  The row's bytes exactly as the equivalent
 * `{ 'a','b','c',0 }` would give them: the characters, then zeros to the row
 * length.  A string exactly N bytes long keeps no NUL: K&R A.8.7, "the number
 * of characters in the string, not counting the terminating null character,
 * must not exceed the size of the array". */
static int
put_string_row(Global *g, int *n_init_values, int rowlen, int max_init)
{
    int slen = g_cur.str_len;
    if (slen > rowlen)
        die(g_cur.line, g_cur.col,
            "string literal too long for char array row");
    for (int k = 0; k < rowlen; k++) {
        if (*n_init_values >= max_init)
            die(g_cur.line, g_cur.col, "too many init values (exceeds MAX_INIT_VALUES)");
        unsigned ch = (k < slen) ? (unsigned char)g_cur.str_ptr[k] : 0;
        g->init_values_hi[*n_init_values] = 0;
        g->init_values[(*n_init_values)++] = ch;
    }
    next_tok();   /* consume the string literal */
    return rowlen;
}

static int parse_elided_init(Global *g, int *n_init_values, int level,
                             int n_dims, int *dims, int max_init,
                             LocalType at);

/* One member of the aggregate whose members dims[level] counts: a scalar at
 * the innermost level, else a subaggregate -- a string row, a braced list,
 * or, when it does not begin with a left brace, an ELIDED one.  Returns the
 * number of init values it stored. */
static int
parse_init_member(Global *g, int *n_init_values, int level, int n_dims,
                  int *dims, int max_init, LocalType at)
{
    if (level + 1 >= n_dims) {
        if (*n_init_values >= max_init)
            die(g_cur.line, g_cur.col,
                "too many init values (exceeds MAX_INIT_VALUES)");
        /* G49: nested-brace scalar is an integer constant EXPRESSION too. */
        put_array_init_item(g, (*n_init_values)++, at);
        return 1;
    }
    if (at == LT_CHAR_ARRAY && level + 2 == n_dims &&
        g_cur.kind == TOK_STR_LIT)
        return put_string_row(g, n_init_values, dims[n_dims - 1], max_init);
    if (g_cur.kind == TOK_LBRACE)
        return parse_nested_brace_init(g, n_init_values, level + 1, n_dims,
                                       dims, max_init, at);
    return parse_elided_init(g, n_init_values, level + 1, n_dims, dims,
                             max_init, at);
}

/* A subaggregate whose initializer does not begin with a left brace.  K&R
 * A.8.7: "If, however, the initializer for a subaggregate does not begin with
 * a left brace, then only enough elements from the list are taken into
 * account for the members of the subaggregate; any remaining members are left
 * to initialize the next member of the aggregate of which the subaggregate is
 * a part."  So `int y[4][3] = { 1, 3, 5, 2, 4, 6 }` fills y[0] and y[1] from
 * the one list.  Its members come from the ENCLOSING list, so the commas
 * between them are that list's; the comma after the last is left for it, as
 * is a trailing one.  A list that ends first leaves the rest of this
 * subaggregate 0, as a short braced list does. */
static int
parse_elided_init(Global *g, int *n_init_values, int level, int n_dims,
                  int *dims, int max_init, LocalType at)
{
    int got = 0;
    int size = 1;
    for (int d = level; d < n_dims; d++) size *= dims[d];

    for (int i = 0; i < dims[level]; i++) {
        if (i > 0) {
            LexPeek pk;
            if (g_cur.kind != TOK_COMMA)
                break;
            lex_peek_save(&pk);
            next_tok();
            if (g_cur.kind == TOK_RBRACE) {     /* trailing comma: the list's */
                lex_peek_restore(&pk);
                break;
            }
        }
        got += parse_init_member(g, n_init_values, level, n_dims, dims,
                                 max_init, at);
    }
    while (got < size) {
        if (*n_init_values >= max_init)
            die(g_cur.line, g_cur.col,
                "too many init values (exceeds MAX_INIT_VALUES)");
        g->init_values_hi[*n_init_values] = 0;
        g->init_values[(*n_init_values)++] = 0;
        got++;
    }
    return got;
}

int
parse_nested_brace_init(Global *g, int *n_init_values,
                        int level, int n_dims, int *dims,
                        int max_init, LocalType at)
{
    expect(TOK_LBRACE, "'{'");
    int subtree_count = 0;
    int items_seen = 0;
    int expected_at_level = dims[level];
    int subtree_size = 1;
    for (int d = level + 1; d < n_dims; d++) subtree_size *= dims[d];

    while (g_cur.kind != TOK_RBRACE) {
        /* dims[level] == 0 means unbounded (implicit-outermost
         * shape) — accept any number of items. */
        if (expected_at_level > 0 && items_seen >= expected_at_level)
            die(g_cur.line, g_cur.col,
                "init list longer than declared dim");
        subtree_count += parse_init_member(g, n_init_values, level, n_dims,
                                           dims, max_init, at);
        items_seen++;
        if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
        if (g_cur.kind != TOK_RBRACE)
            die(g_cur.line, g_cur.col,
                "expected ',' or '}' in nested init list");
    }
    next_tok();   /* consume '}' */
    /* Zero-fill short subtrees up to expected_at_level * subtree_size.
     * For the implicit-outermost shape (dims[level]==0) no zero-fill
     * is done at that level; the caller adjusts dims[0] post-parse. */
    if (expected_at_level > 0) {
        int filled = items_seen * subtree_size;
        int expected_total = expected_at_level * subtree_size;
        while (filled < expected_total && *n_init_values < max_init) {
            g->init_values_hi[*n_init_values] = 0;
            g->init_values[(*n_init_values)++] = 0;
            filled++;
        }
    }
    return subtree_count;
}

/* B-7: parse an optional fn-ptr global initializer — `= func`, `= &func`,
 * or `= 0`.  Records the target function index on the Global so
 * emit_globals_section emits its address (own-bank, PHK-recovered at load);
 * a 0/NULL init leaves init_func_idx at -1 (4-byte zero storage).  Only a
 * bare function name (or NULL) is supported; richer constant fn-ptr
 * expressions are deferred. */
static void
parse_fnptr_global_init(Global *g)
{
    if (g_cur.kind != TOK_EQ) return;
    next_tok();
    if (g_cur.kind == TOK_AMP) next_tok();          /* optional &func */
    if (g_cur.kind == TOK_IDENT) {
        int fi = funcs_lookup(g_cur.id_ptr, g_cur.id_len);
        if (fi < 0)
            die(g_cur.line, g_cur.col,
                "fn-ptr global initializer must name a declared function");
        g->is_initialised = 1;
        g->init_func_idx  = fi;
        next_tok();
        return;
    }
    if (g_cur.kind == TOK_INT_LIT && g_cur.value == 0) {
        g->is_initialised = 1;     /* NULL: init_func_idx stays -1 -> zero-fill */
        next_tok();
        return;
    }
    die(g_cur.line, g_cur.col, "unsupported fn-ptr global initializer");
}

/* B-7: declare a GLOBAL array of fn-ptrs `T (*name[N])(args) [= {f0,f1,...}]`
 * (od's conv_vec dispatch table).  The type is ARY<PTR<FTN>> (is_ptr_array →
 * 4 bytes/element); the optional brace init lists declared function names,
 * stored as func indices in init_values[] for emit_globals_section.  Indexing
 * a fn-ptr array yields LT_FN_PTR (emit_array_index_read_global), so call it
 * via `cb_t f = conv[i]; f(x);` — the direct `conv[i](x)` sugar is deferred. */
static void
parse_fnptr_global_array(const char *name_ptr, int name_len, int fn_sig_id,
                         int arr_len, int is_static, int is_extern)
{
    int funcs[MAX_INIT_VALUES];
    int n_init = 0;
    int has_init = (g_cur.kind == TOK_EQ);
    if (has_init) {
        next_tok();                                 /* '=' */
        expect(TOK_LBRACE, "'{' for fn-ptr array initializer");
        while (g_cur.kind != TOK_RBRACE) {
            if (n_init >= MAX_INIT_VALUES)
                die(g_cur.line, g_cur.col, "too many fn-ptr array initializers");
            /* a `0` entry is a NULL slot (funcs[j] = -1 -> zero-filled),
             * e.g. tcsh ed.defns `PFCmd FuncNames[] = {..., 0}` trailing
             * DUMMY VALUE and any NULL-terminated dispatch table. */
            if (g_cur.kind == TOK_INT_LIT && g_cur.value == 0) {
                funcs[n_init++] = -1;
                next_tok();
            } else {
                if (g_cur.kind == TOK_AMP) next_tok();   /* optional &func */
                if (g_cur.kind != TOK_IDENT)
                    die(g_cur.line, g_cur.col,
                        "fn-ptr array initializer expects function names or 0");
                int fi = funcs_lookup(g_cur.id_ptr, g_cur.id_len);
                if (fi < 0)
                    die(g_cur.line, g_cur.col,
                        "fn-ptr array initializer must name a declared function");
                funcs[n_init++] = fi;
                next_tok();
            }
            if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
            break;
        }
        expect(TOK_RBRACE, "'}' after fn-ptr array initializer");
    }
    int n_elems = (arr_len > 0) ? arr_len : n_init;
    if (n_elems <= 0) {
        /* `extern T (*name[])(args);` is a REFERENCE declaration (K&R
         * A.8.1) -- the definition elsewhere carries the size, so nothing
         * is allocated here.  frotz fastmem.c declares its opcode tables
         * this way.  Placeholder 1, same as the block-scope extern path. */
        if (is_extern && !has_init)
            n_elems = 1;
        else
            die(g_cur.line, g_cur.col,
                "fn-ptr array needs an explicit size or a non-empty initializer");
    }
    if (n_init > n_elems)
        die(g_cur.line, g_cur.col, "too many fn-ptr array initializers");
    Global *g = globals_declare(name_ptr, name_len,
                                INCREF(LT_FN_PTR, DERIV_ARY), n_elems,
                                g_cur.line, g_cur.col, is_extern);
    g->fn_sig_id = fn_sig_id;
    g->is_static = is_static;
    if (has_init) {
        g->is_initialised = 1;
        for (int j = 0; j < n_init; j++) {
            if (funcs[j] < 0) {                 /* NULL slot */
                g->init_values[j]    = 0;
                g->init_values_hi[j] = 1;
            } else {
                g->init_values[j]    = (unsigned)funcs[j];
                g->init_values_hi[j] = 0;
            }
        }
        g->n_init_values = n_init;
    }
}

void
parse_global_decl(TypeSpec t)
{
    /* type-spec already consumed. */
    /* M18: function-pointer global decl: T (*name)(params); */
    {
        const char *fn_name_ptr;
        int         fn_name_len;
        int         fn_sig_id;
        /* The file-scope twin of build_decl's loop (apple/fgx#284): consume
         * fn-ptr init-declarators while they keep coming, and leave anything
         * else to the ordinary declarator loop below, so `int a, (*fp)();' and
         * `int (*fp)(), a;' both parse.  Two fn-ptrs in one list -- `int
         * (*a)(), (*b)();' -- did not work here either; the old code took one
         * declarator and returned.  K&R A.8: the elements of an
         * init-declarator-list are independent declarators sharing only the
         * declaration-specifiers. */
        while (parse_fn_ptr_declarator(t, &fn_name_ptr, &fn_name_len,
                                       &fn_sig_id)) {
            if (g_fnptr_decl_arr != 0) {   /* B-7: array of fn-ptrs (conv_vec) */
                parse_fnptr_global_array(fn_name_ptr, fn_name_len, fn_sig_id,
                                         g_fnptr_decl_arr, t.is_static, t.is_extern);
            } else {
                Global *g = globals_declare(fn_name_ptr, fn_name_len,
                                            LT_FN_PTR, 1, g_cur.line, g_cur.col,
                                            t.is_extern);
                g->fn_sig_id = fn_sig_id;
                g->is_static = t.is_static;
                parse_fnptr_global_init(g);   /* B-7: optional `= &func` / `= 0` */
            }
            if (g_cur.kind != TOK_COMMA) {
                expect(TOK_SEMI, "';' after fn-pointer global decl");
                return;
            }
            next_tok();     /* consume ',' and try the next init-declarator */
        }
    }
    /* M18: fn-pointer typedef-resolved global: cb_t fp; */
    if (t.base == LT_FN_PTR) {
        if (g_cur.kind != TOK_IDENT)
            die(g_cur.line, g_cur.col, "expected name after fn-ptr typedef");
        const char *name_ptr = g_cur.id_ptr;
        int         name_len = g_cur.id_len;
        int         line = g_cur.line, col = g_cur.col;
        next_tok();
        /* Array of an fn-ptr TYPEDEF: `PFCmd tbl[N];` / `extern PFCmd tbl[];` /
         * `PFCmd tbl[] = { f0, f1, ... };`  (tcsh ed.h `extern PFCmd CcFuncTbl[]`
         * + ed.defns.c func-name init).  The fn-ptr-ness is already in the
         * typedef (base LT_FN_PTR, sig in t.struct_id), so this is a typedef +
         * array declarator, NOT the `(*name)()` syntax parse_fn_ptr_declarator
         * handles.  Reuse the B-7 fn-ptr-array machinery; the extern-sizeless
         * incomplete-array form (no init, sized by the defining TU) declares a
         * 1-element placeholder with no storage, like `extern T arr[]`. */
        if (g_cur.kind == TOK_LBRACKET) {
            next_tok();                          /* past '[' */
            int arr_len = 0;                     /* 0 == sizeless `[]` */
            if (g_cur.kind != TOK_RBRACKET) {
                long an = parse_const_bin(0);
                if (an <= 0)
                    die(g_cur.line, g_cur.col,
                        "fn-ptr array size must be a positive integer constant");
                arr_len = (int)an;
            }
            expect(TOK_RBRACKET, "']'");
            if (arr_len == 0 && g_cur.kind != TOK_EQ) {
                if (!t.is_extern)
                    die(g_cur.line, g_cur.col,
                        "'T arr[]' without '=' requires explicit size");
                Global *g = globals_declare(name_ptr, name_len,
                                            INCREF(LT_FN_PTR, DERIV_ARY), 1,
                                            line, col, t.is_extern);
                g->fn_sig_id = t.struct_id;
                g->is_static = t.is_static;
                expect(TOK_SEMI, "';' after fn-ptr array global decl");
                return;
            }
            parse_fnptr_global_array(name_ptr, name_len, t.struct_id, arr_len,
                                     t.is_static, t.is_extern);
            expect(TOK_SEMI, "';' after fn-ptr array global decl");
            return;
        }
        Global *g = globals_declare(name_ptr, name_len,
                                    LT_FN_PTR, 1, line, col, t.is_extern);
        g->fn_sig_id = t.struct_id;
        g->is_static = t.is_static;
        parse_fnptr_global_init(g);   /* B-7: optional `= &func` / `= 0` */
        expect(TOK_SEMI, "';' after fn-ptr global decl");
        return;
    }
    for (;;) {
        /* declarator-refactor Increment 3c: the global's `*name[dims...]`
         * declarator flows through the ONE parse_declarator (same parser as the
         * local path).  d.type == the old type_for_decl(t, stars, is_array).
         * The sizeless outer `[]` maps to size_from_init (globals DEFER sizing
         * to the initializer -- unlike locals which prescan); the placeholder
         * dim-value 1 is reproduced so n_elems/extern sizing is byte-identical. */
        /* A fn-ptr element arriving mid-list at file scope, the mirror of the
         * loop above (apple/fgx#284).  parse_fn_ptr_declarator restores the
         * lexer when the element is not one, so the probe costs a peek. */
        {
            const char *fp_name_ptr;
            int         fp_name_len;
            int         fp_sig_id;
            if (parse_fn_ptr_declarator(t, &fp_name_ptr, &fp_name_len,
                                        &fp_sig_id)) {
                if (g_fnptr_decl_arr != 0) {
                    parse_fnptr_global_array(fp_name_ptr, fp_name_len, fp_sig_id,
                                             g_fnptr_decl_arr, t.is_static,
                                             t.is_extern);
                } else {
                    Global *fg = globals_declare(fp_name_ptr, fp_name_len,
                                                 LT_FN_PTR, 1, g_cur.line,
                                                 g_cur.col, t.is_extern);
                    fg->fn_sig_id = fp_sig_id;
                    fg->is_static = t.is_static;
                    parse_fnptr_global_init(fg);
                }
                if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
                expect(TOK_SEMI, "';' after global decl");
                return;
            }
        }
        Declarator d = parse_declarator(t, /*allow_abstract=*/0);
        const char *name_ptr = d.name;
        int         name_len = d.name_len;
        int         line     = d.name_line, col = d.name_col;
        /* A function declarator among the list: `int timedout, timeout();'
         * (2.11BSD ntpdc).  K&R A.8: "init-declarator-list: init-declarator |
         * init-declarator-list , init-declarator" and "The declarators in the
         * init-declarator list contain the identifiers being declared" -- a
         * function declarator (A.8.6.3) is one of them, sharing only the
         * declaration-specifiers.  Recorded as block scope's G27 arm records
         * one: the return type, unspecified arguments, a prototype only. */
        if (d.is_func_proto) {
            LocalType ret = d.type;
            next_tok();                 /* consume '(' */
            int pdepth = 1;
            while (pdepth > 0 && g_cur.kind != TOK_EOF) {
                if (g_cur.kind == TOK_LPAREN)      pdepth++;
                else if (g_cur.kind == TOK_RPAREN) pdepth--;
                next_tok();
            }
            if (funcs_lookup(name_ptr, name_len) < 0) {
                int fi = funcs_declare(name_ptr, name_len, 0, line, col);
                g_funcs[fi].return_type = ret;
                g_funcs[fi].ret_unsigned = ISPTR(d.type) ? 0 : t.is_unsigned;
                g_funcs[fi].is_variadic = 1;   /* K&R () = unspecified args */
                g_funcs[fi].is_variadic_expl = 1;
                g_funcs[fi].is_extern   = 1;   /* prototype only */
            }
            if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
            expect(TOK_SEMI, "';' after global decl");
            return;
        }
        /* void global must be 'void *p' (the `void *`/`void[]` forms already
         * died inside type_for_decl). */
        if (d.type == LT_VOID)
            die(line, col, "void global must be 'void *p'");
        int is_array = (d.n_dims > 0);
        int n_elems  = 1;
        int size_from_init = 0;   /* 'T arr[] = {...}': size deferred to init */
        if (d.sizeless) {
            size_from_init = 1;
            d.dims[0] = 1;        /* placeholder; fixed after init (was g_loc_dims[0]=1) */
        }
        if (is_array) {
            n_elems = 1;
            for (int di = 0; di < d.n_dims; di++) n_elems *= d.dims[di];
        }
        /* A file-scope sizeless array with no initializer is a TENTATIVE
         * definition (K&R A.10.2, p.187).  Under the UNIX common extension the
         * 2.11BSD shells rely on, if a real definition exists in another TU the
         * tentative ones "become merely declarations" -- so this is an extern
         * reference.  The Bourne /bin/sh declares `MSG name;` (== char name[];)
         * in defs.h for every message string, with the initialized definition
         * in msg.c; tcsh/BSD headers do the same (`extern T x[];` twin).  Bind
         * it as extern: no storage here, the multi-archive linker resolves it
         * to the defining TU.  globals_declare (G45) reconciles the def, in
         * whatever order, into the one symbol. */
        int tentative_extern = 0;
        if (size_from_init && g_cur.kind != TOK_EQ && !t.is_extern)
            tentative_extern = 1;
        /* extern T arr[];  — incomplete array declaration, standard C.
         * The defining TU sizes it; no storage is emitted here (is_extern
         * skips the emit below).  Treat as a 1-element placeholder. */
        LocalType decl_type = d.type;

        /* For struct globals, n_bytes derives from struct.total_size; pass
         * the appropriate n_elems to globals_declare so the switch picks
         * the right size. */
        int gn = n_elems;
        if (decl_type == LT_STRUCT) {
            if (g_structs[t.struct_id].is_forward)
                die(line, col, "by-value struct global requires complete type");
            /* Use a single "element" of n_bytes = total_size — we override
             * n_bytes after globals_declare. */
            gn = 1;
        } else if (decl_type == LT_STRUCT_ARRAY) {
            if (g_structs[t.struct_id].is_forward)
                die(line, col, "array of incomplete struct not allowed");
        }

        Global *g = globals_declare(name_ptr, name_len, decl_type,
                                    gn, line, col,
                                    t.is_extern || tentative_extern);
        g->is_static = t.is_static;
        g->is_unsigned = t.is_unsigned;   /* A-1 */
        if (decl_type == LT_STRUCT) {
            g->struct_id = t.struct_id;
            g->n_bytes   = (g_structs[t.struct_id].total_size + 1) & ~1;
        } else if (decl_type == LT_STRUCT_ARRAY) {
            g->struct_id = t.struct_id;
            int es = (g_structs[t.struct_id].total_size + 1) & ~1;
            g->n_bytes   = es * n_elems;
        } else if (BTYPE(decl_type) == BT_STRUCT) {
            /* G52: struct pointer of ANY depth (struct*, struct**, ...) — record
             * the base struct id so indexed/derefed elements can chain '->'
             * (stevie's `LINE **LinePointers; LinePointers[i]->next`).
             *
             * ANY DERIVATION, not just ISPTR: `struct B *sarr[4]' is an ARRAY
             * of struct pointers, so the id went unrecorded and every consumer
             * that needs the pointee SIZE had nothing to work with -- which is
             * how `sarr[i] += 1' came to move one byte (apple/fgx#154).  The
             * LOCALS path has always used this broader rule; only the global
             * one tested ISPTR.  The struct-VALUE and array-of-values cases
             * are taken by the branches above, so this arm sees the rest. */
            g->struct_id = t.struct_id;
        }
        if (d.n_dims > 1) {
            if (decl_type == LT_STRUCT_ARRAY)
                die(line, col, "multi-dim arrays of struct not supported (M19)");
            g->n_dims = d.n_dims;
            for (int di = 0; di < d.n_dims; di++) g->dims[di] = d.dims[di];
            int es = arr_row_elem_size(decl_type);
            int inner = 1;
            for (int di = 1; di < d.n_dims; di++) inner *= d.dims[di];
            g->row_stride = es * inner;
        }

        int ptr_init_groups = 0;              /* trailing ')' after the operand */
        if (g_cur.kind == TOK_EQ) {
            next_tok();
            /* "The initializer for a pointer or an object of arithmetic type
             * is a single expression, perhaps in braces" (K&R A8.7).  The
             * braces go, and the expression is parsed as if they were not
             * there; a trailing comma is the list nicety A8.7 allows. */
            int scalar_braced = 0;
            if (g_cur.kind == TOK_LBRACE && !is_array &&
                decl_type != LT_STRUCT && decl_type != LT_STRUCT_ARRAY) {
                next_tok();
                scalar_braced = 1;
            }
            /* A leading pointer cast in a pointer-global initializer:
             * `BLKPTR bloktop = (BLKPTR)end;` and the macro form
             * `BLKPTR bloktop = BLK(end);` == `((BLKPTR)(end))` (2.11BSD sh
             * blok.c, end being the loader's end-of-bss array).  K&R A.7.5
             * (cast) + A.7.2 (grouping) + A.7.1 (an array decays to a pointer).
             * Peel the grouping parens and casts so the &global/global-name arm
             * below binds the target; only for a cast wrapping '&' or a known
             * global name (else leave it for the constant path).  Grouping
             * parens leave a trailing ')' run, consumed after the bind. */
            if (ISPTR(decl_type) && g_cur.kind == TOK_LPAREN) {
                LexPeek cpk;
                lex_peek_save(&cpk);
                int groups = peel_ptr_init_prefix();
                if (g_cur.kind == TOK_AMP ||
                    (g_cur.kind == TOK_IDENT &&
                     globals_lookup(g_cur.id_ptr, g_cur.id_len) != NULL))
                    ptr_init_groups = groups;
                else
                    lex_peek_restore(&cpk);   /* not cast-to-global-ptr; rewind */
            }
            /* Brace init list for int/long/char-ptr/struct arrays:
             * '= { N1, N2, ..., Nk }'  for int / long
             * '= { "a", "b", ... }'    for char * (M21)
             * '= { {a,b},{c,d}, ... }' for struct arrays (M22) */
            if (g_cur.kind == TOK_LBRACE) {
                if (decl_type != LT_INT_ARRAY &&
                    decl_type != LT_LONG_ARRAY &&
                    decl_type != LT_LLONG_ARRAY &&
                    decl_type != LT_DOUBLE_ARRAY &&
                    decl_type != LT_FLOAT_ARRAY &&
                    decl_type != LT_CHAR_ARRAY &&
                    !is_ptr_array(decl_type) &&        /* B-5: any T*[N] */
                    decl_type != LT_STRUCT_ARRAY &&
                    decl_type != LT_STRUCT)            /* scalar struct = struct-array of 1 */
                    die(g_cur.line, g_cur.col,
                        "brace-initializer requires int[N], long[N], long long[N], float[N], double[N], char[N], T*[N], struct, or struct[N]");
                int n = 0;
                if (g->n_dims > 1) {
                    /* M19: nested brace init for multi-dim.  For the
                     * implicit-outermost shape, dims[0] is set to 0
                     * to mean "unbounded"; the recursive parser
                     * accepts any count at that level. */
                    if (size_from_init) g->dims[0] = 0;
                    parse_nested_brace_init(g, &n,
                                            0, g->n_dims, g->dims,
                                            MAX_INIT_VALUES, decl_type);
                } else if (decl_type == LT_STRUCT_ARRAY || decl_type == LT_STRUCT) {
                    n = parse_struct_brace_init(g, size_from_init, line, col);
                } else {
                    next_tok();   /* consume '{' for 1D path */
                    /* `char x[] = {"literal"}` — a brace-wrapped string
                     * literal (sed `char rub[] = {"\177"}`).  Same effect as
                     * the unbraced char[] = "literal" form: fill init_values
                     * byte-by-byte (NUL-terminated), leave g_cur at '}' so the
                     * loop is skipped and the post-loop finishes sizing. */
                    if (decl_type == LT_CHAR_ARRAY && g_cur.kind == TOK_STR_LIT) {
                        int slen = g_cur.str_len;
                        if (slen + 1 > MAX_INIT_VALUES)
                            die(g_cur.line, g_cur.col,
                                "char[] string init exceeds MAX_INIT_VALUES");
                        for (int k = 0; k < slen; k++)
                            g->init_values[k] = (unsigned char)g_cur.str_ptr[k];
                        g->init_values[slen] = 0;
                        n = slen + 1;
                        next_tok();   /* consume the string literal */
                    }
                    while (g_cur.kind != TOK_RBRACE) {
                        if (n >= MAX_INIT_VALUES)
                            die(g_cur.line, g_cur.col,
                                "too many init values (exceeds MAX_INIT_VALUES)");
                        /* M21: char*[] takes string-literal items;
                         * init_values[n] holds the _S<idx> pool label.
                         * CU-2: also '&global' items (4.3BSD curses cr_tty.c
                         * `bool *sflags[] = {&AM, &BS, ...}` — bool is char)
                         * and a bare 0 (NULL).  Discriminated per element via
                         * init_values_hi[n] with the SAME tags as char* struct
                         * fields (emit.c): 0 = string-pool label, 1 = NULL,
                         * 3 = &global index. */
                        if (decl_type == LT_CHAR_PTR_ARRAY) {
                            parse_char_ptr_arr_item(g, n);
                            n++;
                            if (g_cur.kind == TOK_COMMA) {
                                next_tok();
                                continue;
                            }
                            if (g_cur.kind != TOK_RBRACE)
                                die(g_cur.line, g_cur.col,
                                    "expected ',' or '}' in init list");
                            continue;
                        }
                        /* B-5: non-char T*[] (int*[], struct*[], ...) takes
                         * '&global' items; init_values[n] holds the target
                         * global's index, emitted as a 4-byte &global later
                         * (data-segment mode: FGX2_LONG_PTR, loader-relocated
                         * bank — the char*-field &global pattern). */
                        if (is_ptr_array(decl_type)) {
                            Global *tg;
                            if (g_cur.kind == TOK_AMP) {
                                next_tok();
                                if (g_cur.kind != TOK_IDENT)
                                    die(g_cur.line, g_cur.col,
                                        "expected global name after '&'");
                                tg = globals_lookup(g_cur.id_ptr, g_cur.id_len);
                                if (tg == NULL)
                                    die(g_cur.line, g_cur.col,
                                        "unknown global in T*[] init (must be a prior global)");
                            } else if (g_cur.kind == TOK_IDENT) {
                                /* A bare ARRAY name decays to its address
                                 * (&name[0]) — a compile-time-constant pointer,
                                 * same reloc treatment as '&global'.  Faithful
                                 * C: `int *m[] = { m1, m2 }` with `int m1[]`
                                 * (tar's pmode() bit-pair tables). */
                                tg = globals_lookup(g_cur.id_ptr, g_cur.id_len);
                                if (tg == NULL)
                                    die(g_cur.line, g_cur.col,
                                        "unknown global in T*[] init (must be a prior global)");
                                if (tg->type != LT_CHAR_ARRAY &&
                                    tg->type != LT_INT_ARRAY &&
                                    tg->type != LT_LONG_ARRAY &&
                                    tg->type != LT_LLONG_ARRAY &&
                                    tg->type != LT_DOUBLE_ARRAY &&
                                    tg->type != LT_FLOAT_ARRAY &&
                                    tg->type != LT_STRUCT_ARRAY &&
                                    !is_ptr_array(tg->type))
                                    die(g_cur.line, g_cur.col,
                                        "T*[] init item must be '&global' or an array name");
                            } else {
                                die(g_cur.line, g_cur.col,
                                    "T*[] init item must be '&global' or an array name");
                            }
                            tg->is_reloc_target = 1;
                            g->init_values[n] = (unsigned)(tg - g_globals);
                            n++;
                            next_tok();
                            if (g_cur.kind == TOK_COMMA) {
                                next_tok();
                                continue;
                            }
                            if (g_cur.kind != TOK_RBRACE)
                                die(g_cur.line, g_cur.col,
                                    "expected ',' or '}' in init list");
                            continue;
                        }
                        /* G49: an init-list scalar is an integer constant
                         * EXPRESSION (opts.c's `char o_columns[3]={80,32,~0}`),
                         * not just a literal — fold via the const-expr
                         * evaluator so ~0 / arithmetic / sizeof / enum work. */
                        put_array_init_item(g, n, decl_type);
                        n++;
                        if (g_cur.kind == TOK_COMMA) {
                            next_tok();
                            continue;
                        }
                        if (g_cur.kind != TOK_RBRACE)
                            die(g_cur.line, g_cur.col,
                                "expected ',' or '}' in init list");
                    }
                    next_tok();   /* consume '}' */
                }
                g->n_init_values  = n;
                g->is_initialised = 1;
                if (decl_type == LT_STRUCT_ARRAY || decl_type == LT_STRUCT) {
                    /* Size/element checks already done inside the struct
                     * branch; n here is the total field-count, not elem-
                     * count, so the generic checks below don't apply.  (A
                     * scalar struct is n_elems == 1 with n == n_fields.) */
                } else if (size_from_init) {
                    if (n == 0)
                        die(line, col,
                            "'T arr[] = {}' empty init not allowed");
                    /* Element size: 1 for char[], 2 for int[], 4 for long[],
                     * float[] and T*[].
                     * (Was missing the char case -> `char x[]={...}` sized at 2*n,
                     * so sizeof over-reported 2x while storage emitted n bytes —
                     * telnet's `nfrontp += sizeof(doopt)-2` over-ran, leaking NULs.) */
                    int _es = (decl_type == LT_LLONG_ARRAY ||
                               decl_type == LT_DOUBLE_ARRAY) ? 8
                            : (decl_type == LT_LONG_ARRAY ||
                               decl_type == LT_FLOAT_ARRAY ||
                               is_ptr_array(decl_type)) ? 4
                            : (decl_type == LT_CHAR_ARRAY) ? 1 : 2;
                    if (g->n_dims == 1) {
                        g->n_elems = n;
                        g->dims[0] = n;
                        g->n_bytes = _es * n;
                    } else {
                        /* Multi-dim implied outermost: dims[0] = n /
                         * product(inner dims). */
                        int inner = 1;
                        for (int d = 1; d < g->n_dims; d++) inner *= g->dims[d];
                        if (inner == 0 || n % inner != 0)
                            die(line, col,
                                "init list size not a multiple of inner-dim product");
                        g->dims[0] = n / inner;
                        g->n_elems = n;
                        g->n_bytes = _es * n;
                    }
                } else if (n > g->n_elems) {
                    die(line, col, "init list longer than array size");
                }
                /* Fall through to comma/semicolon below. */
            } else if (decl_type == LT_CHAR_ARRAY &&
                       g_cur.kind == TOK_STR_LIT) {
                /* `char x[] = "literal"` — copy bytes into init_values[]
                 * (one byte each), NUL-terminated.  Treated as a brace
                 * init by the emit path (DFB per byte); the array's
                 * size is the literal length + 1 if [] was implicit. */
                int slen = g_cur.str_len;
                if (slen + 1 > MAX_INIT_VALUES) {
                    /* Too long to expand per-byte into init_values[]
                     * (frotz dumb_input's 2.1KB runtime-help text).
                     * Intern as a NO-POOL blob; emit_globals_section
                     * streams the bytes into the array's own storage. */
                    g->init_str_label = strlit_intern_blob(g_cur.str_ptr,
                                                           slen);
                    g->is_initialised = 1;
                    if (size_from_init) {
                        g->n_elems = slen + 1;
                        g->n_bytes = slen + 1;
                        if (g->n_dims >= 1) g->dims[0] = slen + 1;
                    } else if (slen + 1 > g->n_elems) {
                        die(g_cur.line, g_cur.col,
                            "string literal too long for declared char[N]");
                    }
                    next_tok();
                    goto strlit_array_done;
                }
                for (int k = 0; k < slen; k++)
                    g->init_values[k] = (unsigned char)g_cur.str_ptr[k];
                g->init_values[slen] = 0;        /* NUL */
                g->n_init_values = slen + 1;
                g->is_initialised = 1;
                if (size_from_init) {
                    g->n_elems = slen + 1;
                    g->n_bytes = slen + 1;
                    if (g->n_dims >= 1) g->dims[0] = slen + 1;
                } else if (slen + 1 > g->n_elems) {
                    die(g_cur.line, g_cur.col,
                        "string literal too long for declared char[N]");
                }
                next_tok();
strlit_array_done: ;
            } else if (is_array || decl_type == LT_STRUCT) {
                die(g_cur.line, g_cur.col,
                    "array/struct initializer requires '{...}'");
            } else if (g_cur.kind == TOK_STR_LIT) {
                if (decl_type != LT_CHAR_PTR)
                    die(g_cur.line, g_cur.col,
                        "string-literal initialiser requires char*");
                int lbl = strlit_intern(g_cur.str_ptr, g_cur.str_len);
                g->is_initialised  = 1;
                g->init_str_label  = lbl;
                next_tok();
            } else if (ISPTR(decl_type) &&
                       (g_cur.kind == TOK_AMP ||
                        (g_cur.kind == TOK_IDENT &&
                         globals_lookup(g_cur.id_ptr, g_cur.id_len) != NULL))) {
                /* `T *p = global;` or `T *p = &global;` — a static pointer
                 * initialised to another global's address (2.11BSD sed's
                 * `struct label *labtab = ltab;`).  Record the target global;
                 * emit_globals_section emits a relocated 4-byte long pointer
                 * (multi-bank: FGX2_LONG_PTR to the target's exported label,
                 * loader-patched bank; single-bank: baked DA/DFB ^own-bank).
                 * Accepts bare array-name decay and the &-of forms. */
                if (g_cur.kind == TOK_AMP) {
                    next_tok();
                    if (g_cur.kind != TOK_IDENT)
                        die(g_cur.line, g_cur.col,
                            "expected global name after '&' in initializer");
                }
                Global *tg = globals_lookup(g_cur.id_ptr, g_cur.id_len);
                if (tg == NULL)
                    die(g_cur.line, g_cur.col,
                        "pointer initializer must name a prior global");
                g->is_initialised  = 1;
                g->init_global_idx = (int)(tg - g_globals);
                tg->is_reloc_target = 1;
                next_tok();
                /* A CONSTANT DISPLACEMENT ON THAT ADDRESS -- `&arr[k]',
                 * `&obj.member', `arr + k' (apple/fgx#282; 2.11BSD fsck
                 * dir.c:19, `char *endpathname = &pathname[MAXPATHLEN - 2]').
                 * Only a bare `&object' or a decayed array name was accepted
                 * before, so all three died "expected ';'".
                 *
                 * K&R A.8.7 sends the question to A.7.19 -- "All the
                 * expressions in the initializer for a static object or array
                 * must be constant expressions as described in Par.A.7.19" --
                 * and A.7.19 grants exactly these: "the unary & operator may
                 * be applied to external or static objects, and to external
                 * and static arrays subscripted with a constant expression",
                 * closing with the general rule "Initializers must evaluate
                 * either to a constant or to the address of a previously
                 * declared external or static object plus or minus a
                 * constant."  A displacement is that constant.
                 *
                 * It costs nothing at run time: the target is already a
                 * relocation, and a relocation carries an addend -- the
                 * emitter writes `label+off' and the assembler folds it.  The
                 * struct-field initialiser path has packed a member offset
                 * into its relocation since telnet's `&nttyb.sg_erase'; this
                 * is the same idea for a scalar pointer, plus subscripts. */
                {
                    int off = 0, cur_sid = tg->struct_id;
                    LocalType cur_ty = tg->type;
                    for (;;) {
                        if (g_cur.kind == TOK_DOT) {
                            next_tok();
                            if (g_cur.kind != TOK_IDENT)
                                die(g_cur.line, g_cur.col,
                                    "pointer initializer: field name after '.'");
                            if (cur_sid < 0)
                                die(g_cur.line, g_cur.col,
                                    "pointer initializer: '.' on a non-struct");
                            Field *mf = field_lookup_dot(cur_sid, g_cur.id_ptr,
                                                         g_cur.id_len);
                            if (mf == NULL)
                                die(g_cur.line, g_cur.col,
                                    "pointer initializer: no such field");
                            off    += mf->byte_offset;
                            cur_ty  = mf->type;
                            cur_sid = mf->struct_id;
                            next_tok();
                            continue;
                        }
                        if (g_cur.kind == TOK_LBRACKET) {
                            int es = elem_size_for(cur_ty, cur_sid);
                            if (es == 0)
                                die(g_cur.line, g_cur.col,
                                    "pointer initializer: subscripted operand "
                                    "is not an array or pointer");
                            next_tok();
                            off += (int)(parse_const_bin(0) * es);
                            expect(TOK_RBRACKET, "']'");
                            cur_ty = DECREF(cur_ty);
                            continue;
                        }
                        if (g_cur.kind == TOK_PLUS || g_cur.kind == TOK_MINUS) {
                            /* `g + k' is POINTER arithmetic (A.7.7): the
                             * constant scales by the pointee, exactly as the
                             * subscript above does -- A.7.3.1 defines E1[E2]
                             * as *(E1+E2), so the two spellings must agree. */
                            int neg = (g_cur.kind == TOK_MINUS);
                            int es  = elem_size_for(cur_ty, cur_sid);
                            if (es == 0)
                                break;          /* not pointer arithmetic */
                            next_tok();
                            long k = parse_const_bin(0);
                            off += (int)((neg ? -k : k) * es);
                            continue;
                        }
                        break;
                    }
                    g->init_global_off = off;
                }
                while (ptr_init_groups-- > 0)   /* close BLK()/grouping wraps */
                    expect(TOK_RPAREN, "')'");
            } else if (decl_type == LT_FLOAT) {
                unsigned int bits = parse_float_init_bits();
                g->is_initialised = 1;
                g->init_value     = bits & 0xFFFFu;
                g->init_value_hi  = (bits >> 16) & 0xFFFFu;
            } else if (decl_type == LT_DOUBLE) {
                unsigned long db = parse_ldouble_init_bits();
                g->is_initialised = 1;
                g->init_value     = (unsigned)(db & 0xFFFFu);
                g->init_value_hi  = (unsigned)((db >> 16) & 0xFFFFu);
                g->init_value_q   = (unsigned)(db >> 32);
            } else {
                /* G15: any integer constant expression (literals, parens,
                 * unary +-~!, binary * / % + - << >> & ^ |).  Covers
                 * `static int x = MBAD;` where MBAD expands to (-1), and the
                 * plain-literal cases (`int x = 5;`) as the trivial fold. */
                long v;
                /* A FLOATING CONSTANT for an integral object is converted as
                 * by assignment: K&R A.8.7, "The expression is assigned to the
                 * object", and A.6.3, "the fractional part is discarded".
                 * `int gi = 2.5;' is 2 (apple/fgx#396).  Only a whole-
                 * initializer constant, optionally negated, is taken.  A.7.19
                 * gives initializers "more latitude ... the operands may be any
                 * type of constant", so `int gi = 2.5 * 2;' is C and is still
                 * refused here; parse_const_bin stays integral because array
                 * bounds and case labels share it, and those require floating
                 * constants to be cast. */
                LexPeek fk;
                int fneg = 0;
                lex_peek_save(&fk);
                if (g_cur.kind == TOK_MINUS) { fneg = 1; next_tok(); }
                if (g_cur.kind == TOK_FLOAT_LIT) {
                    unsigned int fbits = (g_cur.value & 0xFFFFu) |
                        ((unsigned)(g_cur.value_hi & 0xFFFFu) << 16);
                    float f;
                    memcpy(&f, &fbits, 4);
                    v = (long)f;              /* truncates toward zero */
                    if (fneg) v = -v;
                    next_tok();
                } else {
                    lex_peek_restore(&fk);
                    v = parse_const_bin(0);
                }
                g->is_initialised = 1;
                g->init_value     = (unsigned)(v & 0xFFFFL);
                /* A pointer keeps its high word too: `(char *)0xE12000L' is
                 * a constant (K&R A.7.19) whose bank byte is $E1. */
                if (g->type == LT_LONG || g->type == LT_LLONG ||
                    ISPTR(g->type))
                    g->init_value_hi = (unsigned)((v >> 16) & 0xFFFFL);
                if (g->type == LT_LLONG)
                    g->init_value_q = (unsigned)((unsigned long)v >> 32);
            }
            if (scalar_braced) {
                if (g_cur.kind == TOK_COMMA)
                    next_tok();
                expect(TOK_RBRACE, "'}' closing a braced scalar initializer");
            }
        }
        if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
        break;
    }
    expect(TOK_SEMI, "';'");
}

void
parse_typedef_def(void)
{
    TypeSpec t = parse_type_spec();
    /* M18: typedef T (*name)(params); */
    {
        const char *td_name_ptr;
        int         td_name_len;
        int         td_sig_id;
        if (parse_fn_ptr_declarator(t, &td_name_ptr, &td_name_len, &td_sig_id)) {
            expect(TOK_SEMI, "';' after typedef fn-pointer");
            FCC_GROW(g_typedefs, g_n_typedefs, g_typedefs_cap, Typedef);
            Typedef *td = &g_typedefs[g_n_typedefs++];
            int nl = td_name_len < MAX_IDENT - 1 ? td_name_len : MAX_IDENT - 1;
            td->name = lex_intern_ident(td_name_ptr, nl);
            td->base_type = LT_FN_PTR;
            td->struct_id = -1;
            td->fn_sig_id = td_sig_id;
            td->n_elems   = 1;
            td->is_unsigned = 0;   /* a function pointer has no signedness */
            return;
        }
    }
    int is_ptr = 0;
    while (g_cur.kind == TOK_STAR) { is_ptr++; next_tok(); }
    if (g_cur.kind != TOK_IDENT)
        die(g_cur.line, g_cur.col, "expected typedef name");
    FCC_GROW(g_typedefs, g_n_typedefs, g_typedefs_cap, Typedef);
    Typedef *td = &g_typedefs[g_n_typedefs++];
    int nl = g_cur.id_len < MAX_IDENT - 1 ? g_cur.id_len : MAX_IDENT - 1;
    td->name = lex_intern_ident(g_cur.id_ptr, nl);
    td->struct_id = t.struct_id;
    td->fn_sig_id = -1;
    td->n_elems   = 1;
    /* Carried even when the base is a pointer or a struct, where it means
     * nothing: the consumers below ask only about integer bases, and a flag
     * that is set in one arm and left uninitialised in another is the shape
     * this defect had in the first place. */
    td->is_unsigned = t.is_unsigned;
    if (is_ptr) {
        /* One pointer derivation per '*': `typedef void **Handle' is a
         * pointer to a pointer (K&R A.8.9: the typedef name has the type
         * its declarator would give a variable).  Recording only "is a
         * pointer" made *h read one byte through h and rebuild a data-bank
         * pointer from it. */
        if (t.base != LT_INT && t.base != LT_CHAR && t.base != LT_VOID &&
            t.base != LT_STRUCT && t.base != LT_LONG)
            die(g_cur.line, g_cur.col, "bad typedef pointer base");
        td->base_type = t.base;
        while (is_ptr-- > 0)
            td->base_type = INCREF(td->base_type, DERIV_PTR);
    } else {
        if (t.base == LT_VOID)
            die(g_cur.line, g_cur.col,
                "typedef of void requires '*'");
        td->base_type = t.base;
    }
    next_tok();
    /* Array typedef `typedef T name[]` -- name is "array of T" (K&R A.8.9:
     * the declarator is parsed in the usual way, A.8.6.2 array declarator).
     * The 2.11BSD Bourne shell's MSG[] / PIPE[] are SIZELESS: an incomplete
     * type completed at each use by its initializer (A.8.7), exactly like
     * `char msg[] = "..."`.  Record the array tword; parse_declarator's
     * ISARY-base seam re-materializes the sizeless array at the use site. */
    if (g_cur.kind == TOK_LBRACKET) {
        next_tok();                         /* past '[' */
        if (g_cur.kind != TOK_RBRACKET)
            die(g_cur.line, g_cur.col,
                "sized array typedef not yet supported "
                "(only `T name[]`; declarator-refactor follow-up)");
        next_tok();                         /* past ']' */
        if (g_cur.kind == TOK_LBRACKET)
            die(g_cur.line, g_cur.col,
                "multidimensional array typedef not yet supported");
        td->base_type = INCREF(td->base_type, DERIV_ARY);
        td->n_elems   = 0;                  /* sizeless */
    }
    expect(TOK_SEMI, "';'");
}

/* Parse an enum's optional tag + optional `{ enumerators }`, registering the
 * constants (enum's value type is int).  `enum` already consumed.  Leaves
 * g_cur after the '}' (body form) or after the tag (`enum tag` ref, no body).
 * Shared by parse_enum_def (top-level `enum {..};`) and parse_type_spec (enum
 * as a TYPE: `typedef enum {..} T;`, enum params/locals). */
void
parse_enum_body(void)
{
    if (g_cur.kind == TOK_IDENT) next_tok();   /* optional tag (ignored M8) */
    if (g_cur.kind != TOK_LBRACE) return;      /* `enum tag` ref, no body */
    next_tok();                                /* '{' */
    unsigned next_val = 0;
    while (g_cur.kind != TOK_RBRACE) {
        if (g_cur.kind != TOK_IDENT)
            die(g_cur.line, g_cur.col, "expected enumerator name");
        if (g_n_enum_consts >= MAX_ENUM_CONSTS)
            die(g_cur.line, g_cur.col, "too many enum constants");
        EnumConst *e = &g_enum_consts[g_n_enum_consts++];
        int nl = g_cur.id_len < MAX_IDENT - 1 ? g_cur.id_len : MAX_IDENT - 1;
        e->name = lex_intern_ident(g_cur.id_ptr, nl);
        next_tok();
        if (g_cur.kind == TOK_EQ) {
            next_tok();
            /* C89 3.5.2.2: an enumerator's value is an INTEGER CONSTANT
             * EXPRESSION, not merely a literal.  This used to accept only an
             * int or char token, so `enum { A = 1 << 3 }`, `sizeof`, an
             * earlier enumerator, or a conditional were all rejected.  The
             * constant-expression evaluator already handles the whole
             * grammar, so route through it; enumerators earlier in this same
             * list are visible because they are appended as they are parsed.
             * Masked to 16 bits: an enum's value type is int. */
            next_val = (unsigned)(parse_const_bin(0) & 0xFFFFL);
        }
        e->value = next_val;
        next_val = (next_val + 1) & 0xFFFF;
        if (g_cur.kind == TOK_COMMA) { next_tok(); continue; }
        break;
    }
    expect(TOK_RBRACE, "'}'");
}

void
parse_enum_def(void)
{
    parse_enum_body();
    expect(TOK_SEMI, "';'");
}

void
parse_program(void)
{
    emit_file_header();
    while (g_cur.kind != TOK_EOF) {
        g_decl_lint_varargs = g_cur.lint_varargs;   /* VARARGSn precedes the
                                                     * declaration's first token */
        if (g_cur.kind == TOK_TYPEDEF_KW) {
            next_tok();
            parse_typedef_def();
            continue;
        }

        /* Type-prefixed top-level decl: int / char / void / struct /
         * typedef-name / type-modifier / static (M8 + multi-TU). */
        int is_type_start = (g_cur.kind == TOK_INT_KW ||
                             g_cur.kind == TOK_CHAR_KW ||
                             g_cur.kind == TOK_VOID_KW ||
                             g_cur.kind == TOK_STRUCT_KW ||
                             g_cur.kind == TOK_UNION_KW ||
                             g_cur.kind == TOK_ENUM_KW ||
                             g_cur.kind == TOK_STATIC_KW ||
                             g_cur.kind == TOK_LONG_KW ||
                             g_cur.kind == TOK_FLOAT_KW ||
                             (g_cur.kind == TOK_IDENT &&
                              (typedefs_lookup(g_cur.id_ptr, g_cur.id_len) >= 0 ||
                               is_type_modifier_ident(g_cur.id_ptr, g_cur.id_len))));
        if (is_type_start) {
            /* An enum yields LT_INT, indistinguishable afterwards from a plain
             * `int`, so remember how the type was spelled: it decides whether a
             * bare ';' here is a definition or a syntax error. */
            int was_enum = (g_cur.kind == TOK_ENUM_KW);
            TypeSpec t = parse_type_spec();
            /* Definition-only at file scope: 'struct foo { ... };' and
             * 'enum foo { ... };'.  Anything else has a declarator and is a
             * variable or function of that type -- which is how `enum E v;`
             * reaches parse_global_decl at all.  Previously `enum` was
             * intercepted above and always treated as a definition, so a
             * file-scope variable of enum type was rejected. */
            if (g_cur.kind == TOK_SEMI && (t.base == LT_STRUCT || was_enum)) {
                next_tok();
                continue;
            }
            /* Peek: is this a function?  pp-frame-safe so a macro in the
             * declarator (`void g P_((int));`) re-lexes cleanly after rewind. */
            LexPeek pk;
            lex_peek_save(&pk);
            while (g_cur.kind == TOK_STAR) next_tok();
            int is_func = 0;
            if (g_cur.kind == TOK_IDENT) {
                next_tok();
                is_func = (g_cur.kind == TOK_LPAREN);
            }
            lex_peek_restore(&pk);
            if (is_func) {
                parse_func_decl_with_spec(t);
            } else {
                parse_global_decl(t);
            }
            continue;
        }

        /* G14: ORCA-C 'segment "name";' directive (e.g. stevie's
         * fileio.c:13 `segment "s_io";`).  Not standard C — FGX does its own
         * segmentation via the FGX2 linker — so recognize and skip it (up to
         * the ';') rather than choke.  Approved strip-the-ORCA-ism gap. */
        if (g_cur.kind == TOK_IDENT && g_cur.id_len == 7 &&
            memcmp(g_cur.id_ptr, "segment", 7) == 0) {
            next_tok();
            while (g_cur.kind != TOK_SEMI && g_cur.kind != TOK_EOF)
                next_tok();
            if (g_cur.kind == TOK_SEMI) next_tok();
            continue;
        }

        /* K&R implicit-int top-level FUNCTION: `name(params) {...}` or
         * `name();` with no return-type spec — the default-int rule (e.g.
         * 2.11BSD ed's `main(argc,argv)`, `commands()`, `setdot()`).  A plain
         * IDENT followed by '(' (not a typedef/modifier — those took the
         * is_type_start path above) is a function returning int.  Synthesize
         * the int spec; parse_func_decl_with_spec consumes from the name. */
        if (g_cur.kind == TOK_IDENT) {
            LexPeek pk2;
            lex_peek_save(&pk2);
            next_tok();
            int looks_fn = (g_cur.kind == TOK_LPAREN);
            lex_peek_restore(&pk2);
            if (looks_fn) {
                TypeSpec it;
                it.base = LT_INT; it.struct_id = -1;
                it.is_static = 0; it.is_extern = 0; it.is_unsigned = 0;
                parse_func_decl_with_spec(it);
                continue;
            }
        }
        die(g_cur.line, g_cur.col,
            "expected top-level declaration");
    }
    /* M7: emit globals, then string literal pool. */
    emit_globals_section();
    emit_str_pool();
}
