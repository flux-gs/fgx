/* M18: fn-ptr as param — callee invokes through it. */
int triple_it(int x) { return x * 3; }
int apply(int (*cb)(int), int v) { return cb(v); }

int main(void)
{
    return apply(triple_it, 14);
}
