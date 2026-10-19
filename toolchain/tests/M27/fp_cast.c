/* B-7: fn-ptr casts.  The typedef'd form `(cb_t)expr` already worked (bt
 * resolves to LT_FN_PTR); this fixture also covers the inline abstract
 * declarator `(int(*)(int))expr` (the registry's `void (*)(void)` form),
 * which previously failed with "expected ')'".  Returns 42. */
typedef int (*cb_t)(int);

int dbl(int x) { return x * 2; }
int trp(int x) { return x * 3; }

int main(void)
{
    cb_t f;
    int  sum;
    f = (cb_t)dbl;            sum = f(6);          /* typedef'd cast: 12       */
    f = (int (*)(int))trp;    sum = sum + f(10);   /* inline cast: +30 -> 42   */
    return sum;
}
