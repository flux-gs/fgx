/* B-7: array of fn-ptrs — od's conv_vec dispatch table.  Declared
 * `int (*conv[])(int) = { f0, f1, f2 };` (ARY<PTR<FTN>>, 4 bytes/elem).
 * Indexing yields LT_FN_PTR, so dispatch via the idiom
 * `cb_t f = conv[i]; f(x)` (the direct `conv[i](x)` call sugar is deferred).
 * Returns 42. */
typedef int (*cb_t)(int);

int double_it(int x) { return x * 2; }
int triple_it(int x) { return x * 3; }
int add_ten(int x)   { return x + 10; }

int (*conv[])(int) = { double_it, triple_it, add_ten };

int main(void)
{
    cb_t f;
    int sum;
    f = conv[0]; sum = f(3);            /* double_it(3) = 6        */
    f = conv[1]; sum = sum + f(4);      /* + triple_it(4) = 12 -> 18 */
    f = conv[2]; sum = sum + f(14);     /* + add_ten(14)  = 24 -> 42 */
    return sum;
}
