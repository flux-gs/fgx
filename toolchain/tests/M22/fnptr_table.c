/* M22 + M18: struct-array with a fn-ptr field (elvis cmdnames[]/vikeys[]
 * command-table shape): initialize with function NAMES, dispatch via
 * tbl[i].fn().  (elvis's own `(*tbl[i].fn)(...)` deref form is a separate,
 * scoped fcc follow-up — needs g_expr_fn_sig tracking + *-on-fn-ptr no-op.) */
int add5(x) int x; { return x + 5; }
int add37(x) int x; { return x + 37; }
struct centry { char *name; int (*fn)(); };
struct centry tbl[] = {
    { "a", add5 },
    { "b", add37 },
};

int main(void)
{
    return tbl[1].fn(5);   /* 37 + 5 = 42 */
}
