/* Statement-context sibling of od_probe: a bare-statement indirect call
 * through a fn-ptr declared `int (*)()` (no prototype) with MIXED int +
 * pointer args — exactly od's `put = put_table[id]; put(0, d)` flush path
 * (od.c line 356).  Before the fix, n_params==0 pushed BOTH args as 2 bytes,
 * so the pointer `d` was truncated and the callee read garbage.  The int arg
 * must still push 2 bytes; only the pointer widens to 4. */
struct S { int a; int b; int c; };
struct S gs;
int g_result;

int f2(int x, struct S *d)
{
    g_result = x + d->a + d->b + d->c;   /* 5 + 10 + 20 + 7 = 42 */
    return 0;
}

int (*tbl[])() = { f2 };

int main(void)
{
    int (*fp)();

    gs.a = 10; gs.b = 20; gs.c = 7;
    fp = tbl[0];
    fp(5, &gs);             /* STATEMENT context; return value discarded */
    return g_result;        /* expect 42 */
}
