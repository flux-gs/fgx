/* TWORD — packed type-derivation word for fcc's type system.
 *
 * A type is one unsigned word:
 *   - low BTSHIFT bits: base type (BT_*)
 *   - above, in 2-bit groups: a stack of derivation constructors
 *     (DERIV_PTR / DERIV_ARY / DERIV_FTN; 0 = end). The group just
 *     above the base bits is the OUTERMOST constructor.
 *
 * INCREF(t,d) pushes a new outermost constructor; DECREF(t) peels it.
 * Side tables (struct_id, fn_sig_id, dims[], is_unsigned) live on
 * Local/Global/Field as before — TWORD replaces only the `type` field.
 *
 * Design: docs/superpowers/specs/2026-05-29-fcc-tword-type-model-design.md
 */
#ifndef FCC_TWORD_H
#define FCC_TWORD_H

typedef unsigned tword;

/* base type — low 4 bits */
#define BTSHIFT   4
#define BTMASK    0xFu
#define BT_VOID   0u
#define BT_CHAR   1u
#define BT_INT    2u
#define BT_LONG   3u
#define BT_STRUCT 4u
#define BT_FLOAT  5u    /* B-6: float == double == 32-bit IEEE-754 single */
#define BT_LLONG  6u    /* long long: 64-bit; A:_fcc_long_hi:_fcc_q2:_fcc_q3 */
#define BT_DOUBLE 7u    /* double and long double: 64-bit IEEE-754, on long long's words */

/* derivation groups — 2 bits each, above BTSHIFT */
#define DERIV_PTR 1u
#define DERIV_ARY 2u
#define DERIV_FTN 3u

/* safety: cap derivation depth so a pathological declarator can't
 * silently truncate the stack. 11 groups fit in 22 bits above base. */
#define TW_MAX_DERIV 8

#define BTYPE(t)    ((tword)(t) & BTMASK)
#define DERIV(t)    (((tword)(t) >> BTSHIFT) & 3u)         /* outermost group */
#define ISPTR(t)    (DERIV(t) == DERIV_PTR)
#define ISARY(t)    (DERIV(t) == DERIV_ARY)
#define ISFTN(t)    (DERIV(t) == DERIV_FTN)

/* peel the outermost constructor (deref / array decay / element type) */
#define DECREF(t)   ( BTYPE(t) | ((((tword)(t) >> BTSHIFT) >> 2) << BTSHIFT) )
/* push a new outermost constructor (address-of / declarator build) */
#define INCREF(t,d) ( BTYPE(t) | (((((tword)(t) >> BTSHIFT) << 2) | (d)) << BTSHIFT) )

/* count consecutive PTR groups from the outermost inward.
 * depth >= 2 => the pointee is itself a pointer (stride 4, 4-byte deref). */
static inline int tw_ptr_depth(tword t)
{
    int d = 0;
    while ((((t) >> BTSHIFT) & 3u) == DERIV_PTR) { d++; t = DECREF(t); }
    return d;
}

/* bare base-type words (used by constructors + the LT_* table) */
#define TW_VOID   (BT_VOID)
#define TW_CHAR   (BT_CHAR)
#define TW_INT    (BT_INT)
#define TW_LONG   (BT_LONG)
#define TW_STRUCT (BT_STRUCT)
#define TW_FLOAT  (BT_FLOAT)
#define TW_LLONG  (BT_LLONG)
#define TW_DOUBLE (BT_DOUBLE)

/* ---- LT_* compatibility constants ----------------------------------
 * These keep fcc.c's existing `== LT_*` comparisons and `switch(type)`
 * case labels valid and semantically identical for depth-<=1 types.
 * Each is an integer constant expression (valid as a case label). */
#define LT_INT            (TW_INT)
#define LT_INT_PTR        INCREF(TW_INT,  DERIV_PTR)
#define LT_INT_ARRAY      INCREF(TW_INT,  DERIV_ARY)
#define LT_CHAR           (TW_CHAR)
#define LT_CHAR_PTR       INCREF(TW_CHAR, DERIV_PTR)
#define LT_CHAR_ARRAY     INCREF(TW_CHAR, DERIV_ARY)
#define LT_VOID           (TW_VOID)
#define LT_VOID_PTR       INCREF(TW_VOID, DERIV_PTR)
#define LT_STRUCT         (TW_STRUCT)
#define LT_STRUCT_PTR     INCREF(TW_STRUCT, DERIV_PTR)
#define LT_STRUCT_ARRAY   INCREF(TW_STRUCT, DERIV_ARY)
/* fn-ptr: PTR<FTN<...>>. fn-ptr codegen stays keyed on fn_sig_id; this
 * encoding just has to be a unique constant distinct from the others. */
#define LT_FN_PTR         INCREF(INCREF(TW_VOID, DERIV_FTN), DERIV_PTR)
#define LT_LONG           (TW_LONG)
#define LT_LONG_PTR       INCREF(TW_LONG, DERIV_PTR)
#define LT_LONG_ARRAY     INCREF(TW_LONG, DERIV_ARY)
/* B-6: float family — 4-byte IEEE-754 single, mirrors the LT_LONG tier */
#define LT_FLOAT          (TW_FLOAT)
#define LT_FLOAT_PTR      INCREF(TW_FLOAT, DERIV_PTR)
#define LT_FLOAT_ARRAY    INCREF(TW_FLOAT, DERIV_ARY)
/* long long: 8 bytes, a long with two more words (docs/history/plans/
 * 2026-09-23-fcc-long-long-plan.md) */
#define LT_LLONG          (TW_LLONG)
#define LT_LLONG_PTR      INCREF(TW_LLONG, DERIV_PTR)
#define LT_LLONG_ARRAY    INCREF(TW_LLONG, DERIV_ARY)
/* double and long double: 8 bytes of IEEE-754 double (docs/history/plans/
 * 2026-09-23-fcc-64bit-double-plan.md).  Its bits ride the same four words
 * as a long long, so everything that only MOVES a value -- load, store,
 * push, pop, return -- is shared, and IS_QUAD says so.  Whatever reads the
 * value as a number is not. */
#define LT_DOUBLE         (TW_DOUBLE)
#define LT_DOUBLE_PTR     INCREF(TW_DOUBLE, DERIV_PTR)
#define LT_DOUBLE_ARRAY   INCREF(TW_DOUBLE, DERIV_ARY)
#define IS_QUAD(t)        ((t) == LT_LLONG || (t) == LT_DOUBLE)
#define BT_IS_QUAD(b)     ((b) == BT_LLONG || (b) == BT_DOUBLE)
/* The type `double' denotes, and so the type a float argument is promoted to
 * (K&R A.7.3.2: "each float argument is converted to double"): the 64-bit
 * IEEE double, the same type as long double.  K&R A.4.2: float, double and
 * long double "may be synonymous, but the ones later in the list are at
 * least as precise as those before". */
#define LT_DBL            LT_DOUBLE
/* char *arr[] = ARY<PTR<CHAR>> — now a derived type, not a special tag */
#define LT_CHAR_PTR_ARRAY INCREF(INCREF(TW_CHAR, DERIV_PTR), DERIV_ARY)

#endif /* FCC_TWORD_H */
