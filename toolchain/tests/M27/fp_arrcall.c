/* B-7 (deferred item 1): DIRECT call through an indexed fn-ptr array element,
 * `conv[i](args)` -- previously required the idiom `cb_t f = conv[i]; f(x)`.
 * The element's fn-ptr offset is stashed below the args, args are evaluated
 * (the last call passes a LOCAL `x`, exercising the g_s_delta stack accounting
 * across the stash), then reloaded and called same-bank.  Returns 42. */
typedef int (*cb_t)(int);

int dbl(int x)  { return x * 2; }
int trp(int x)  { return x * 3; }
int add4(int x) { return x + 4; }

int (*conv[])(int) = { dbl, trp, add4 };

int main(void)
{
    int sum, i, x;
    x = 20;
    sum = conv[0](3);                /* const index, literal arg: dbl(3)  = 6  */
    i = 1; sum = sum + conv[i](4);   /* var index,   literal arg: trp(4)  = 12 -> 18 */
    i = 2; sum = sum + conv[i](x);   /* var index,   LOCAL arg x: add4(20)= 24 -> 42 */
    return sum;
}
