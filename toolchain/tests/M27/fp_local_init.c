/* B-7: fn-ptr local initializers — typedef'd `cb_t fp = f;` and the bare
 * declarator form `int (*fp)(int) = f;`.  Both were previously rejected
 * ("fn-ptr local init not supported (assign separately)").  A fn-ptr is
 * ISPTR, so the initializer takes emit_store_local's 4-byte (offset+bank)
 * store path — identical to the separate-statement `fp = f;`.  Returns 42. */
typedef int (*cb_t)(int);

int double_it(int x) { return x * 2; }
int triple_it(int x) { return x * 3; }

int main(void)
{
    cb_t fp = double_it;             /* typedef'd fn-ptr init  */
    int (*fp2)(int) = triple_it;     /* declarator fn-ptr init */
    return fp(6) + fp2(10);          /* 12 + 30 = 42 */
}
