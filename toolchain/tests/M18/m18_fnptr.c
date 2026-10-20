/* M18 acceptance: combines local + param + struct-field + typedef.
 * Returns 42 if all four shapes work. */
typedef int (*cb_t)(int);

int double_it(int x) { return x * 2; }
int triple_it(int x) { return x * 3; }
int identity(int x) { return x; }

int apply(cb_t cb, int x) { return cb(x); }

struct ops {
    int (*compute)(int);
    int (*ident)(int);
};

int main(void)
{
    cb_t fp;
    struct ops o;
    int sum;
    fp = double_it;
    sum = fp(3);                              /* 6 */
    sum = sum + apply(triple_it, 4);          /* +12 = 18 */
    o.compute = double_it;
    o.ident = identity;
    sum = sum + o.compute(7);                 /* +14 = 32 */
    sum = sum + o.ident(10);                  /* +10 = 42 */
    return sum;
}
