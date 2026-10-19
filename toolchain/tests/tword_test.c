/* Standalone host unit test for the TWORD type-derivation encoding.
 * Build+run:  cc -O -Wall -o tword_test tword_test.c && ./tword_test
 * Exits 0 on success; prints the first failing assertion and exits 1. */
#include <stdio.h>
#include "../tword.h"

static int fails = 0;
#define CHECK(cond) do { if (!(cond)) { \
    printf("FAIL line %d: %s\n", __LINE__, #cond); fails++; } } while (0)

int main(void)
{
    /* base extraction */
    CHECK(BTYPE(TW_CHAR) == BT_CHAR);
    CHECK(BTYPE(TW_INT)  == BT_INT);
    CHECK(BTYPE(TW_LONG) == BT_LONG);

    /* a bare scalar has no derivation */
    CHECK(!ISPTR(TW_CHAR));
    CHECK(!ISARY(TW_INT));

    /* INCREF pushes an outermost constructor; ISPTR sees it */
    tword cp = INCREF(TW_CHAR, DERIV_PTR);          /* char *  */
    CHECK(ISPTR(cp));
    CHECK(BTYPE(cp) == BT_CHAR);
    CHECK(tw_ptr_depth(cp) == 1);

    tword cpp = INCREF(cp, DERIV_PTR);              /* char ** */
    CHECK(ISPTR(cpp));
    CHECK(tw_ptr_depth(cpp) == 2);
    CHECK(BTYPE(cpp) == BT_CHAR);

    /* DECREF peels exactly one level (deref) */
    CHECK(DECREF(cpp) == cp);                        /* *char** = char* */
    CHECK(DECREF(cp)  == TW_CHAR);                   /* *char*  = char  */

    /* array-of-pointer composition: char *arr[] = ARY<PTR<CHAR>> */
    tword arr_of_cp = INCREF(cp, DERIV_ARY);         /* outer = ARY, inner = PTR */
    CHECK(ISARY(arr_of_cp));
    CHECK(!ISPTR(arr_of_cp));                         /* outermost is ARY, not PTR */
    CHECK(DECREF(arr_of_cp) == cp);                  /* index/decay → char* element */

    /* the LT_* compat constants must equal their constructed encodings,
     * so existing `== LT_*` comparisons keep their exact meaning */
    CHECK(LT_CHAR        == TW_CHAR);
    CHECK(LT_INT         == TW_INT);
    CHECK(LT_CHAR_PTR    == INCREF(TW_CHAR, DERIV_PTR));
    CHECK(LT_INT_PTR     == INCREF(TW_INT,  DERIV_PTR));
    CHECK(LT_VOID_PTR    == INCREF(TW_VOID, DERIV_PTR));
    CHECK(LT_LONG_PTR    == INCREF(TW_LONG, DERIV_PTR));
    CHECK(LT_CHAR_ARRAY  == INCREF(TW_CHAR, DERIV_ARY));
    CHECK(LT_INT_ARRAY   == INCREF(TW_INT,  DERIV_ARY));
    CHECK(LT_LONG_ARRAY  == INCREF(TW_LONG, DERIV_ARY));
    CHECK(LT_CHAR_PTR_ARRAY == INCREF(INCREF(TW_CHAR, DERIV_PTR), DERIV_ARY));

    /* every LT_* constant must be distinct (no encoding collisions —
     * collisions would silently merge switch cases) */
    tword all[] = { LT_INT, LT_INT_PTR, LT_INT_ARRAY, LT_CHAR, LT_CHAR_PTR,
        LT_CHAR_ARRAY, LT_VOID, LT_VOID_PTR, LT_STRUCT, LT_STRUCT_PTR,
        LT_STRUCT_ARRAY, LT_FN_PTR, LT_LONG, LT_LONG_PTR, LT_LONG_ARRAY,
        LT_CHAR_PTR_ARRAY };
    int n = (int)(sizeof all / sizeof all[0]);
    for (int i = 0; i < n; i++)
        for (int j = i + 1; j < n; j++)
            CHECK(all[i] != all[j]);

    if (fails) { printf("%d assertion(s) failed\n", fails); return 1; }
    printf("tword_test: all passed\n");
    return 0;
}
