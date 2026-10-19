/* The ACTUAL od bug (od_probe..4 all missed it): a MULTI-element fn-ptr table
 * initialised BEFORE its target functions are defined, with other definitions
 * in between.  funcs_declare promotes each prototype to a definition by
 * shifting g_funcs, which renumbered the indices the table stored at parse
 * time — so put_table[k] named whatever function slid into the slot
 * (put_table[3] became init_formats instead of us_put).  Single-element
 * tables never exposed it.  Reference: host clang (C semantics) exits 42. */
int f0(int x);
int f1(int x);
int f2(int x);
int f3(int x);

int (*tbl[])(int) = { f0, f1, f2, f3 };   /* built against the prototypes */

/* unrelated definitions in between → force g_funcs renumbering shifts */
int helper_a(void) { return 1; }
int helper_b(void) { return 2; }

int f0(int x) { return x + 0;  }
int f1(int x) { return x + 10; }
int f2(int x) { return x + 20; }
int f3(int x) { return x + 30; }

int main(void)
{
    int (*fp)(int);
    int sum = 0;
    int k;

    for (k = 0; k < 4; k++) {
        fp = tbl[k];
        sum += fp(k);          /* f0(0)+f1(1)+f2(2)+f3(3) = 0+11+22+33 = 66 */
    }
    return sum - 24;           /* 66 - 24 = 42 */
}
